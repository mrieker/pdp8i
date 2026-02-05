
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string>
#include <string.h>
#include <tcl8.6/tcl.h>
#include <unistd.h>

#define ABORT() do { fprintf (stderr, "ABORT %s %d\n", __FILE__, __LINE__); abort (); } while (0)

#include "obj_dir/Vbackplane.h"

#include "assemble.h"
#include "disassemble.h"
#include "readprompt.h"

static bool volatile ctrlcflag;
static int cyclenum;
static Vbackplane *vbkpl;

static Tcl_ObjCmdProc cmd_asmop;
static Tcl_ObjCmdProc cmd_bus;
static Tcl_ObjCmdProc cmd_clk;
static Tcl_ObjCmdProc cmd_ctrlcflag;
static Tcl_ObjCmdProc cmd_disop;
static Tcl_ObjCmdProc cmd_gpio;
static Tcl_ObjCmdProc cmd_mem;
static Tcl_ObjCmdProc cmd_res;

static void kerchunk ();
static void Tcl_SetResultF (Tcl_Interp *interp, char const *fmt, ...);
static void siginthand (int signum);

int main (int argc, char **argv)
{
    setlinebuf (stdout);

    Tcl_FindExecutable (argv[0]);
    Tcl_Interp *interp = Tcl_CreateInterp ();
    if (interp == NULL) ABORT ();
    int rc = Tcl_Init (interp);
    if (rc != TCL_OK) {
        char const *err = Tcl_GetStringResult (interp);
        if ((err != NULL) && (err[0] != 0)) {
            fprintf (stderr, "error %d initialing tcl: %s\n", rc, err);
        } else {
            fprintf (stderr, "error %d initialing tcl\n", rc);
        }
        ABORT ();
    }

    if (Tcl_CreateObjCommand (interp, "asmop", cmd_asmop, NULL, NULL) == NULL) ABORT ();
    if (Tcl_CreateObjCommand (interp, "bus",  cmd_bus,  NULL, NULL) == NULL) ABORT ();
    if (Tcl_CreateObjCommand (interp, "clk",  cmd_clk,  NULL, NULL) == NULL) ABORT ();
    if (Tcl_CreateObjCommand (interp, "ctrlcflag", cmd_ctrlcflag, NULL, NULL) == NULL) ABORT ();
    if (Tcl_CreateObjCommand (interp, "disop", cmd_disop, NULL, NULL) == NULL) ABORT ();
    if (Tcl_CreateObjCommand (interp, "gpio", cmd_gpio, NULL, NULL) == NULL) ABORT ();
    if (Tcl_CreateObjCommand (interp, "mem",  cmd_mem,  NULL, NULL) == NULL) ABORT ();
    if (Tcl_CreateObjCommand (interp, "res",  cmd_res,  NULL, NULL) == NULL) ABORT ();

    signal (SIGINT, siginthand);

    Vbackplane vbackplane;
    vbkpl = &vbackplane;

    rc = Tcl_EvalFile (interp, "verimain.tcl");
    if (rc != TCL_OK) {
        Tcl_EvalEx (interp, "puts $::errorInfo", -1, TCL_EVAL_GLOBAL);
        return 1;
    }

    while (true) {
        ctrlcflag = false;
        char const *line = readprompt ("> ");
        ctrlcflag = false;
        if (line == NULL) break;

        int rc = Tcl_EvalEx (interp, line, -1, TCL_EVAL_GLOBAL);

        char const *res = Tcl_GetStringResult (interp);
        int rel = (res == NULL) ? 0 : strlen (res);
        char rer[rel+1];
        memcpy (rer, res, rel);
        rer[rel] = 0;

        char const *eri = Tcl_GetVar (interp, "::errorInfo", TCL_GLOBAL_ONLY);
        int erl = (eri == NULL) ? 0 : strlen (eri);
        char err[erl+1];
        memcpy (err, eri, erl);
        err[erl] = 0;

        Tcl_EvalEx (interp, "flush stdout", -1, TCL_EVAL_GLOBAL);
        Tcl_EvalEx (interp, "flush stderr", -1, TCL_EVAL_GLOBAL);

        if (rc != TCL_OK) {
            if (rer[0] == 0) fprintf (stderr, "error %d evaluating command\n", rc);
               else fprintf (stderr, "error %d evaluating command: %s\n", rc, rer);
            if (err[0] != 0) fprintf (stderr, "%s\n", err);
        }
        else if (rer[0] != 0) puts (rer);
    }
}

// asmop address mnemonic operands...
static int cmd_asmop (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
    if (objc < 3) {
        Tcl_SetResultF (interp, "missing arguments");
        return TCL_ERROR;
    }
    int pctr;
    int rc = Tcl_GetIntFromObj (interp, objv[1], &pctr);
    if (rc != TCL_OK) return rc;
    std::string opstr;
    for (int i = 2; i < objc; i ++) {
        if (i > 2) opstr.push_back (' ');
        opstr.append (Tcl_GetString (objv[i]));
    }
    uint16_t opcode;
    char *error = assemble (opstr.c_str (), pctr, &opcode);
    if (error != NULL) {
        Tcl_SetResult (interp, error, (void (*) (char *)) free);
        return TCL_ERROR;
    }
    Tcl_SetObjResult (interp, Tcl_NewIntObj (opcode));
    return TCL_OK;
}

struct Pin {
    int bits;
    int size;
    void *offs;
    char const *name;
};
#define OFFS(x) sizeof (vbkpl->x), &vbkpl->x

// bus get pin pin ... set pin val pin val ...
static int cmd_bus (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
    Pin const pintable[] = {
        {  1, OFFS (i3CYCLE),  "i3CYCLE"  },   // do 3-cycle break
        {  1, OFFS (iACCLEAR), "iACCLEAR" },   // io pulse clears AC
        {  1, OFFS (iBRKRQST), "iBRKRQST" },   // requesting break
        {  1, OFFS (iBRKWRM),  "iBRKWRM"  },   // break cycle writes memory
        {  1, OFFS (iCAINC),   "iCAINC"   },   // curad cycle increments address word
        {  1, OFFS (iHOLD),    "iHOLD"    },   // hold internal clocking (stretch cycle)
        {  1, OFFS (iINTRQST), "iINTRQST" },   // request interrupt
        {  1, OFFS (iIOSKIP),  "iIOSKIP"  },   // increment PC at end of IO pulse
        { 15, OFFS (iDMAADDR), "iDMAADDR" },   // device sending address for DMA
        { 12, OFFS (iDMADATA), "iDMADATA" },   // device sending write data for DMA
        { 12, OFFS (iINBUS),   "iINBUS"   },   // device sending data for PIO

        {  1, OFFS (link),     "link"     },
        {  4, OFFS (majst),    "majst"    },
        {  3, OFFS (memfield), "memfield" },
        { 12, OFFS (pctr),     "pctr"     },

        { 12, OFFS (oACUM),    "oACUM"    },
        {  1, OFFS (oBREAK),   "oBREAK"   },   // currently doing BREAK (DMA) cycle
        {  1, OFFS (oBWCOV),   "oBWCOV"   },   // 3-cycle DMA wordcount overflowed
        {  1, OFFS (oIOP1),    "oIOP1"    },   // io instruction pulses
        {  1, OFFS (oIOP2),    "oIOP2"    },
        {  1, OFFS (oIOP4),    "oIOP4"    },
        { 12, OFFS (oMADR),    "oMADR"    },
        { 12, OFFS (oMBUF),    "oMBUF"    },
        {  1, OFFS (oTP1),     "oTP1"     },
        {  1, OFFS (oTP2),     "oTP2"     },
        {  1, OFFS (oTP3),     "oTP3"     },
        {  1, OFFS (oTP4),     "oTP4"     },
        {  1, OFFS (oTS1),     "oTS1"     },
        {  1, OFFS (oTS2),     "oTS2"     },
        {  1, OFFS (oTS3),     "oTS3"     },
        {  1, OFFS (oTS4),     "oTS4"     },
        {  0, 0, 0, NULL }
    };

    bool setmode = false;
    int ngetobjs = 0;
    Tcl_Obj *getobjs[objc];

    for (int i = 0; ++ i < objc;) {
        char const *arg = Tcl_GetString (objv[i]);
        if (strcasecmp (arg, "get") == 0) {
            setmode = false;
            continue;
        }
        if (strcasecmp (arg, "set") == 0) {
            setmode = true;
            continue;
        }
        for (int j = 0;; j ++) {
            Pin const *pin = &pintable[j];
            if (pin->name == NULL) {
                Tcl_SetResultF (interp, "bad pin %s", arg);
                return TCL_ERROR;
            }
            if (strcasecmp (arg, pin->name) == 0) {
                if (setmode) {
                    if (pin->name[0] != 'i') {
                        Tcl_SetResultF (interp, "pin not settable %s", arg);
                        return TCL_ERROR;
                    }
                    if (++ i >= objc) {
                        Tcl_SetResultF (interp, "missing value for pin %s", arg);
                        return TCL_ERROR;
                    }
                    int val;
                    int rc = Tcl_GetIntFromObj (interp, objv[i], &val);
                    if (rc != TCL_OK) return rc;
                    if ((val < 0) || (val >= 1 << pin->bits)) {
                        Tcl_SetResultF (interp, "value %d out of range for pin %s", val, arg);
                        return TCL_ERROR;
                    }
                    memcpy (pin->offs, &val, pin->size);
                } else {
                    int val = 0;
                    if (pin->size > (int) sizeof val) abort ();
                    memcpy (&val, pin->offs, pin->size);
                    getobjs[ngetobjs++] = Tcl_NewIntObj (val);
                }
                break;
            }
        }
    }
    if (ngetobjs == 1) {
        Tcl_SetObjResult (interp, getobjs[0]);
    }
    if (ngetobjs > 1) {
        Tcl_SetObjResult (interp, Tcl_NewListObj (ngetobjs, getobjs));
    }
    return TCL_OK;
}

// clk [n]
// returns total number of clock cycles
static int cmd_clk (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
    if (objc > 2) {
        Tcl_SetResultF (interp, "extra arguments");
        return TCL_ERROR;
    }
    int num = 1;
    if (objc > 1) {
        int rc = Tcl_GetIntFromObj (interp, objv[1], &num);
        if (rc != TCL_OK) return rc;
    }
    while (-- num >= 0) {
        kerchunk ();
    }
    Tcl_SetObjResult (interp, Tcl_NewIntObj (cyclenum));
    return TCL_OK;
}

// ctrlcflag [n]
// returns 0 (no control-C) or 1 (got control-C)
static int cmd_ctrlcflag (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
    bool oldctrlcflag = ctrlcflag;
    switch (objc) {
        case 2: {
            int temp;
            int rc = Tcl_GetBooleanFromObj (interp, objv[1], &temp);
            if (rc != TCL_OK) return rc;
            sigset_t sigintmask;
            if (sigprocmask (SIG_BLOCK, &sigintmask, NULL) != 0) ABORT ();
            oldctrlcflag = ctrlcflag;
            ctrlcflag = temp != 0;
            if (sigprocmask (SIG_UNBLOCK, &sigintmask, NULL) != 0) ABORT ();
            // fallthrough
        }
        case 1: {
            Tcl_SetObjResult (interp, Tcl_NewIntObj (oldctrlcflag));
            return TCL_OK;
        }
    }
    Tcl_SetResult (interp, (char *) "bad number of arguments", TCL_STATIC);
    return TCL_ERROR;
}

// disop address opcode
static int cmd_disop (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
    if (objc != 3) {
        Tcl_SetResultF (interp, "missing/extra arguments");
        return TCL_ERROR;
    }
    int opcd, pctr, rc;
    rc = Tcl_GetIntFromObj (interp, objv[1], &pctr);
    if (rc != TCL_OK) return rc;
    rc = Tcl_GetIntFromObj (interp, objv[2], &opcd);
    if (rc != TCL_OK) return rc;
    std::string str = disassemble (opcd, pctr);
    char *dup = strdup (str.c_str ());
    if (dup == NULL) ABORT ();
    Tcl_SetResult (interp, dup, (void (*) (char *)) free);
    return TCL_OK;
}

// gpio [n]
// returns gpio value
static int cmd_gpio (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
    if (objc > 2) {
        Tcl_SetResultF (interp, "extra arguments");
        return TCL_ERROR;
    }
    if (objc > 1) {
        int num = 1;
        int rc = Tcl_GetIntFromObj (interp, objv[1], &num);
        if (rc != TCL_OK) return rc;
        vbkpl->gpin = num;
    } else {
        Tcl_SetObjResult (interp, Tcl_NewIntObj (vbkpl->gpout));
    }
    return TCL_OK;
}

// direct internal memory access
static int cmd_mem (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
    switch (objc) {

        // mem addr - read memory
        case 2: {
            int addr;
            int rc = Tcl_GetIntFromObj (interp, objv[1], &addr);
            if (rc != TCL_OK) return rc;
            if ((addr < 0) || (addr > 077777)) {
                Tcl_SetResultF (interp, "bad address %d", addr);
                return TCL_ERROR;
            }
            int data = vbkpl->backplane__DOT__meminst__DOT__memarray[addr];
            Tcl_SetObjResult (interp, Tcl_NewIntObj (data));
            return TCL_OK;
        }

        // mem addr data - write memory
        case 3: {
            int addr;
            int rc = Tcl_GetIntFromObj (interp, objv[1], &addr);
            if (rc != TCL_OK) return rc;
            if ((addr < 0) || (addr > 077777)) {
                Tcl_SetResultF (interp, "bad address %d", addr);
                return TCL_ERROR;
            }
            int data;
            rc = Tcl_GetIntFromObj (interp, objv[2], &data);
            if (rc != TCL_OK) return rc;
            if ((data < 0) || (data > 07777)) {
                Tcl_SetResultF (interp, "bad data %d", data);
                return TCL_ERROR;
            }
            vbkpl->backplane__DOT__meminst__DOT__memarray[addr] = data;
            return TCL_OK;
        }

        default: {
            Tcl_SetResultF (interp, "missing/extra arguments");
            return TCL_ERROR;
        }
    }
}

// res 0 or 1
// no return value
static int cmd_res (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
    if (objc != 2) {
        Tcl_SetResultF (interp, "missing/extra arguments");
        return TCL_ERROR;
    }
    int num = 1;
    int rc = Tcl_GetIntFromObj (interp, objv[1], &num);
    if (rc != TCL_OK) return rc;
    vbkpl->zreset = num;
    return TCL_OK;
}

// call with clock still low and input signals just changed
// returns with output signals updated and clock just set low
static void kerchunk ()
{
    vbkpl->eval ();     // let input signals soak in
    vbkpl->zclock = 1;  // clock the state
    vbkpl->eval ();     // let new state settle in
    vbkpl->zclock = 0;  // get ready for more input changes
    ++ cyclenum;        // one more clock cycle done
}

// set result to formatted string
static void Tcl_SetResultF (Tcl_Interp *interp, char const *fmt, ...)
{
    char *buf = NULL;
    va_list ap;
    va_start (ap, fmt);
    if (vasprintf (&buf, fmt, ap) < 0) ABORT ();
    va_end (ap);
    Tcl_SetResult (interp, buf, (void (*) (char *)) free);
}

// got a control-C, set flag, abort if 2 in a row 
static void siginthand (int signum)
{
    if ((isatty (STDIN_FILENO) > 0) && (write (STDIN_FILENO, "\n", 1) > 0)) { }
    if (ctrlcflag) exit (1);
    ctrlcflag = true;
}
