
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

#ifdef VERLTR
#include "obj_dir/Vbackplane.h"
#endif
#ifdef ZTURN
#include <sys/file.h>
#include <sys/mman.h>
#endif

#include "assemble.h"
#include "disassemble.h"
#include "readprompt.h"

#define ABORT() do { fprintf (stderr, "ABORT %s %d\n", __FILE__, __LINE__); abort (); } while (0)

struct Pin {
    int bits;
#ifdef VERLTR
    int size;
    void *addr;
#endif
#ifdef ZTURN
    uint32_t mask;
    int indx;
#endif
    bool writ;
    char const *name;
};

static bool volatile ctrlcflag;
static int clkratio = 10;
static int cyclenum;

#ifdef VERLTR
static Vbackplane *vbkpl;
#endif
#ifdef ZTURN
static uint32_t volatile *zpage;
#endif

static Tcl_ObjCmdProc cmd_asmop;
static Tcl_ObjCmdProc cmd_bus;
static Tcl_ObjCmdProc cmd_clk;
static Tcl_ObjCmdProc cmd_ctrlcflag;
static Tcl_ObjCmdProc cmd_disop;
static Tcl_ObjCmdProc cmd_gpio;
static Tcl_ObjCmdProc cmd_mem;
static Tcl_ObjCmdProc cmd_randbits;
static Tcl_ObjCmdProc cmd_tty;

static void kerchunk ();
static int cmdpintable (int pincount, Pin const *pintable, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[]);
static void Tcl_SetResultF (Tcl_Interp *interp, char const *fmt, ...);
static void siginthand (int signum);

int main (int argc, char **argv)
{
    setlinebuf (stdout);

    int scriptargc = argc - 1;
    char **scriptargv = argv + 1;

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
    if (Tcl_CreateObjCommand (interp, "randbits",  cmd_randbits,  NULL, NULL) == NULL) ABORT ();
    if (Tcl_CreateObjCommand (interp, "tty",  cmd_tty,  NULL, NULL) == NULL) ABORT ();

    signal (SIGINT, siginthand);

#ifdef VERLTR
    Vbackplane vbackplane;
    vbkpl = &vbackplane;
#endif
#ifdef ZTURN
    int zfd = open ("/proc/zynqpdp8i", O_RDWR);
    if (zfd < 0) {
        fprintf (stderr, "error opening /proc/zynqpdp8i: %m\n");
        ABORT ();
    }
    if (flock (zfd, LOCK_EX | LOCK_NB) < 0) {
        fprintf (stderr, "error locking /proc/zynqpdp8i: %m\n");
        ABORT ();
    }
    void *zp = mmap (NULL, 4096, PROT_READ | PROT_WRITE, MAP_SHARED, zfd, 0);
    if (zp == MAP_FAILED) {
        fprintf (stderr, "error mapping /proc/zynqpdp8i: %m\n");
        ABORT ();
    }
    zpage = (uint32_t volatile *)zp;
    if ((zpage[0] & 0xFFFF0000) != 0x38480000) {
        fprintf (stderr, "bad magic number %08X\n", zpage[0]);
        ABORT ();
    }
    fprintf (stderr, "magic number %08X\n", zpage[0]);
#endif

    rc = Tcl_EvalFile (interp, "verimain.tcl");
    if (rc != TCL_OK) {
        Tcl_EvalEx (interp, "puts $::errorInfo", -1, TCL_EVAL_GLOBAL);
        return 1;
    }

    // if given a filename, process that file as a whole
    if (scriptargc > 0) {

        // get tcl filename from first argument
        char const *scriptfn = scriptargv[0];

        // pass remaining arguments as list 'argv'
        Tcl_Obj *scriptargobjs[scriptargc-1];
        for (int i = 0; ++ i < scriptargc;) {
            scriptargobjs[i-1] = Tcl_NewStringObj (scriptargv[i], -1);
        }
        if (Tcl_ObjSetVar2 (interp, Tcl_NewStringObj ("argv", 4), NULL, Tcl_NewListObj (scriptargc - 1, scriptargobjs), TCL_GLOBAL_ONLY) == NULL) {
            ABORT ();
        }

        // evaluate the script file as a whole
        rc = Tcl_EvalFile (interp, scriptfn);
        if (rc != TCL_OK) {
            char const *res = Tcl_GetStringResult (interp);
            if ((res == NULL) || (res[0] == 0)) fprintf (stderr, "error %d evaluating script %s\n", rc, scriptfn);
                                  else fprintf (stderr, "error %d evaluating script %s: %s\n", rc, scriptfn, res);
            Tcl_EvalEx (interp, "puts $::errorInfo", -1, TCL_EVAL_GLOBAL);
            return 1;
        }
    }

    // no filename, prompt from stdin
    else while (true) {
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
            if (rer[0] == 0) fprintf (stderr, "\nerror %d evaluating command\n", rc);
               else fprintf (stderr, "\nerror %d evaluating command: %s\n", rc, rer);
            if (err[0] != 0) fprintf (stderr, "%s\n", err);
        }
        else if (rer[0] != 0) puts (rer);
    }

    return 0;
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

#ifdef VERLTR
#define OFFS(x) sizeof (vbkpl->x), &vbkpl->x
#endif
#ifdef ZTURN
#include "zdefs.h"
#define OFFS(x) x##_M, x##_I
#endif

static int sortpin (void const *a, void const *b)
{
    Pin const *p = (Pin const *)a;
    Pin const *q = (Pin const *)b;
    return strcasecmp (p->name, q->name);
}

static int findpin (void const *k, void const *e)
{
    char const *c = (char const *) k;
    Pin const *p = (Pin const *) e;
    return strcasecmp (c, p->name);
}

// bus [get] pin pin ... set pin val pin val ...
static int cmd_bus (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
    static int pincount;
    static Pin const *pintable;

    if (pintable == NULL) {
        Pin pt[] = {
            {  1, OFFS (i3CYCLE),  true,  "i3CYCLE"  },   // do 3-cycle break
            {  1, OFFS (iACCLEAR), true,  "iACCLEAR" },   // io pulse clears AC
            {  1, OFFS (iBRKRQST), true,  "iBRKRQST" },   // requesting break
            {  1, OFFS (iBRKWRM),  true,  "iBRKWRM"  },   // break cycle writes memory
            {  1, OFFS (iCAINC),   true,  "iCAINC"   },   // curad cycle increments address word
            {  1, OFFS (iINTRQST), true,  "iINTRQST" },   // request interrupt
            {  1, OFFS (iIOSKIP),  true,  "iIOSKIP"  },   // increment PC at end of IO pulse
            {  1, OFFS (iLNKTOG),  true,  "iLNKTOG"  },   // toggle link register
            { 15, OFFS (iDMAADDR), true,  "iDMAADDR" },   // device sending address for DMA
            { 12, OFFS (iINBUS),   true,  "iINBUS"   },   // device sending data for PIO or DMA
            {  1, OFFS (iPAUSE),   true,  "iPAUSE"   },   // pause processor clocking (stretch cycle)

            {  4, OFFS (majst),    false, "majst"    },
            {  1, OFFS (memdisab), true,  "memdisab" },
            {  3, OFFS (memfield), false, "memfield" },
            { 12, OFFS (mquo),     false, "mquo"     },
            { 12, OFFS (pctr),     false, "pctr"     },
            {  1, OFFS (reset),    true,  "reset"    },
            {  5, OFFS (sctr),     false, "sctr"     },

            {  1, OFFS (swcont),   false, "swcont"   },
            {  3, OFFS (swdfld),   false, "swdfld"   },
            {  3, OFFS (swifld),   false, "swifld"   },
            {  1, OFFS (swstop),   false, "swstop"   },
            {  1, OFFS (swstart),  false, "swstart"  },
            {  1, OFFS (swsstep),  false, "swsstep"  },
            {  1, OFFS (swsinst),  false, "swsinst"  },
            {  1, OFFS (swldad),   false, "swldad"   },
            {  1, OFFS (swexam),   false, "swexam"   },
            {  1, OFFS (swdepos),  false, "swdepos"  },

#ifdef VERLTR
            { 10, OFFS (armraddr), true,  "armraddr" },
            { 32, OFFS (armrdata), false, "armrdata" },
            { 10, OFFS (armwaddr), true,  "armwaddr" },
            { 32, OFFS (armwdata), true,  "armwdata" },
            {  1, OFFS (armwrite), true,  "armwrite" },
#endif

#ifdef ZTURN
            { 12, OFFS (businbus), false, "businbus" },
            {  1, OFFS (busacclr), false, "busacclr" },
            {  1, OFFS (busintrq), false, "busintrq" },
            {  1, OFFS (busioskp), false, "busioskp" },
#endif

            { 12, OFFS (oACUM),    false, "oACUM"    },
            {  1, OFFS (oBREAK),   false, "oBREAK"   },   // currently doing BREAK (DMA) cycle
            {  1, OFFS (oBWCOV),   false, "oBWCOV"   },   // 3-cycle DMA wordcount overflowed
            {  1, OFFS (oION),     false, "oION"     },   // interrupts enabled
            {  1, OFFS (oIOP),     false, "oIOP"     },   // io instruction pulse
            {  1, OFFS (oLINK),    false, "oLINK"    },
            { 12, OFFS (oMADR),    false, "oMADR"    },
            { 12, OFFS (oMBUF),    false, "oMBUF"    },
            {  1, OFFS (oRUN),     false, "oRUN"     },
            {  1, OFFS (oTP1),     false, "oTP1"     },
            {  1, OFFS (oTP2),     false, "oTP2"     },
            {  1, OFFS (oTP3),     false, "oTP3"     },
            {  1, OFFS (oTP4),     false, "oTP4"     },
            {  1, OFFS (oTS1),     false, "oTS1"     },
            {  1, OFFS (oTS2),     false, "oTS2"     },
            {  1, OFFS (oTS3),     false, "oTS3"     },
            {  1, OFFS (oTS4),     false, "oTS4"     }
        };
        pincount = sizeof pt / sizeof pt[0];
        qsort (pt, pincount, sizeof pt[0], sortpin);
        pintable = (Pin const *) malloc (sizeof pt);
        if (pintable == NULL) ABORT ();
        memcpy ((void *) pintable, (void *) pt, sizeof pt);
    }

    return cmdpintable (pincount, pintable, interp, objc, objv);
}

// clk [n]
//  returns total number of clock cycles
// clk ratio [r]
//  sets or returns clock ratio
static int cmd_clk (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
    if ((objc > 1) && (strcasecmp (Tcl_GetString (objv[1]), "ratio") == 0)) {
        if (objc > 2) {
            int num;
            int rc = Tcl_GetIntFromObj (interp, objv[2], &num);
            if (rc != TCL_OK) return rc;
            if (num <= 1) {
                Tcl_SetResultF (interp, "bad ratio %d", num);
                return TCL_ERROR;
            }
            clkratio = num;
        } else {
            Tcl_SetObjResult (interp, Tcl_NewIntObj (clkratio));
        }
        return TCL_OK;
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
        int num = 0;
        int rc = Tcl_GetIntFromObj (interp, objv[1], &num);
        if (rc != TCL_OK) return rc;
#ifdef VERLTR
        vbkpl->gpin = num;
#endif
#ifdef ZTURN
        zpage[Z_RH] = num;
#endif
    } else {
#ifdef VERLTR
        int num = vbkpl->gpout;
#endif
#ifdef ZTURN
        int num = zpage[Z_RI];
#endif
        Tcl_SetObjResult (interp, Tcl_NewIntObj (num));
    }
    return TCL_OK;
}

// direct internal memory access
static int cmd_mem (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
#ifdef VERLTR
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
            int datalo = vbkpl->backplane__DOT__meminst__DOT__U175__DOT__array[addr] & 077;
            int datahi = vbkpl->backplane__DOT__meminst__DOT__U177__DOT__array[addr] & 077;
            Tcl_SetObjResult (interp, Tcl_NewIntObj ((datahi << 6) | datalo));
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
            vbkpl->backplane__DOT__meminst__DOT__U175__DOT__array[addr] = data & 077;
            vbkpl->backplane__DOT__meminst__DOT__U177__DOT__array[addr] = (data >> 6) & 077;
            return TCL_OK;
        }

        default: {
            Tcl_SetResultF (interp, "missing/extra arguments");
            return TCL_ERROR;
        }
    }
#endif
#ifdef ZTURN
    Tcl_SetResultF (interp, "not supported for zturn");
    return TCL_ERROR;
#endif
}

// randbits nbits
// returns random value
static int cmd_randbits (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
    if (objc != 2) {
        Tcl_SetResultF (interp, "missing/extra arguments");
        return TCL_ERROR;
    }

    int nbits;
    int rc = Tcl_GetIntFromObj (interp, objv[1], &nbits);
    if (rc != TCL_OK) return rc;
    if ((nbits < 0) || (nbits > 31)) {
        Tcl_SetResultF (interp, "nbits %d must be in range 0..31", nbits);
        return TCL_ERROR;
    }

    static uint64_t seed = 0x123456789ABCDEF0ULL;

    int randval = 0;

    while (-- nbits >= 0) {

        // https://www.xilinx.com/support/documentation/application_notes/xapp052.pdf
        uint64_t xnor = ~ ((seed >> 63) ^ (seed >> 62) ^ (seed >> 60) ^ (seed >> 59));
        seed = (seed << 1) | (xnor & 1);

        randval += randval + (seed & 1);
    }

    Tcl_SetObjResult (interp, Tcl_NewIntObj (randval));
    return TCL_OK;
}

// tty [get] pin pin ... set pin val pin val ...
static int cmd_tty (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
#ifdef VERLTR
    Tcl_SetResultF (interp, "tty command not supported");
    return TCL_ERROR;
#endif
#ifdef ZTURN
    static int pincount;
    static Pin const *pintable;

    if (pintable == NULL) {
        if ((zpage[32] & 0xFFFF0000) != 0x54540000) {
            Tcl_SetResultF (interp, "bad tty magic number %08X", zpage[32]);
            return TCL_ERROR;
        }
        Pin pt[] = {
            { 32, 0xFFFFFFFFU, 32+0, false, "magic"   },
            { 12, 0x00000FFFU, 32+1, true,  "kbchar"  },
            {  1, 0x40000000U, 32+1, true,  "enable"  },
            {  1, 0x80000000U, 32+1, true,  "kbflag"  },
            { 12, 0x00000FFFU, 32+2, false, "prchar"  },
            {  1, 0x40000000U, 32+2, true,  "prfull"  },
            {  1, 0x80000000U, 32+2, true,  "prflag"  },
            {  1, 0x00000100U, 32+3, false, "intenab" }
        };
        pincount = sizeof pt / sizeof pt[0];
        qsort (pt, pincount, sizeof pt[0], sortpin);
        pintable = (Pin const *) malloc (sizeof pt);
        if (pintable == NULL) ABORT ();
        memcpy ((void *) pintable, (void *) pt, sizeof pt);
    }

    return cmdpintable (pincount, pintable, interp, objc, objv);
#endif
}

// call with 10MHz clock still low and input signals just changed
// returns with output signals updated and 10MHz clock just set low
static void kerchunk ()
{
    // 10 100MHz cycles step the 10MHz osc through a cycle
    // each 100MHz step progresses signals through gates and flipflops
#ifdef ZTURN
    uint32_t ctla = zpage[zclock_I];
#endif
    for (int i = 0; i < 10; i ++) {
#ifdef VERLTR
        vbkpl->eval ();     // let input signals soak in
        vbkpl->zclock = 1;  // clock progress through gates and flipflops
        vbkpl->eval ();     // let new state settle in
        vbkpl->zclock = 0;
        vbkpl->armwrite = 0;
#endif
#ifdef ZTURN
        zpage[zclock_I] = ctla | zclock_M;
        zpage[zclock_I] = ctla;
#endif
    }
    ++ cyclenum;            // one more clock cycle done
}

// process a pintable-type command
//   command [get] pin pin ... set pin val pin val ...
// returns 'get' pin values in a list
static int cmdpintable (int pincount, Pin const *pintable, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
    bool setmode = false;
    int ngetobjs = 0;
    Tcl_Obj *getobjs[objc];

#ifdef VERLTR
    bool needeval = false;
#endif

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
        Pin const *pin = (Pin const *) bsearch (arg, pintable, pincount, sizeof *pintable, findpin);
        if (pin == NULL) {
            Tcl_SetResultF (interp, "bad pin %s", arg);
            return TCL_ERROR;
        }
        if (setmode) {
            if (! pin->writ) {
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
            if ((uint32_t)val > (uint32_t)((1ULL << pin->bits) - 1)) {
                Tcl_SetResultF (interp, "value %u out of range for pin %s", val, arg);
                return TCL_ERROR;
            }
#ifdef VERLTR
            memcpy (pin->addr, &val, pin->size);
            needeval = true;
#endif
#ifdef ZTURN
            zpage[pin->indx] = (zpage[pin->indx] & ~ pin->mask) | (val * (pin->mask & - pin->mask));
#endif
        } else {
#ifdef VERLTR
            if (needeval) {
                needeval = false;
                vbkpl->eval ();
            }
            int val = 0;
            if (pin->size > (int) sizeof val) abort ();
            memcpy (&val, pin->addr, pin->size);
#endif
#ifdef ZTURN
            int val = (zpage[pin->indx] & pin->mask) / (pin->mask & - pin->mask);
#endif
            getobjs[ngetobjs++] = Tcl_NewIntObj (val);
        }
    }
#ifdef VERLTR
    if (needeval) vbkpl->eval ();
#endif
    if (ngetobjs == 1) {
        Tcl_SetObjResult (interp, getobjs[0]);
    }
    if (ngetobjs > 1) {
        Tcl_SetObjResult (interp, Tcl_NewListObj (ngetobjs, getobjs));
    }
    return TCL_OK;
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
