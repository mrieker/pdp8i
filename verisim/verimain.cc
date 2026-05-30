
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
#include "obj_dir/Vbackplane_extmemory.h"
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
static double simulationtime;
static int clkratio;
static int cyclenum;

#ifdef VERLTR
static Vbackplane *vbkpl;
#endif
#ifdef ZTURN
static uint32_t volatile *zpage;
#endif

static Tcl_ObjCmdProc cmd_arm;
static Tcl_ObjCmdProc cmd_asmop;
static Tcl_ObjCmdProc cmd_bus;
static Tcl_ObjCmdProc cmd_clk;
static Tcl_ObjCmdProc cmd_ctrlcflag;
static Tcl_ObjCmdProc cmd_disop;
static Tcl_ObjCmdProc cmd_gpio;
static Tcl_ObjCmdProc cmd_help;
static Tcl_ObjCmdProc cmd_iic;
static Tcl_ObjCmdProc cmd_mem;
static Tcl_ObjCmdProc cmd_randbits;

static uint32_t scramgpio (uint32_t x);
static void kerchunk ();
static int cmdpintable (int pincount, Pin const *pintable, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[]);
static int findev (char const *ident);
static uint32_t armread (uint32_t armaddr);
static void armwrite (uint32_t armaddr, uint32_t armdata);
static void armclock ();
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

    if (Tcl_CreateObjCommand (interp, "arm",  cmd_arm,  NULL, NULL) == NULL) ABORT ();
    if (Tcl_CreateObjCommand (interp, "asmop", cmd_asmop, NULL, NULL) == NULL) ABORT ();
    if (Tcl_CreateObjCommand (interp, "bus",  cmd_bus,  NULL, NULL) == NULL) ABORT ();
    if (Tcl_CreateObjCommand (interp, "clk",  cmd_clk,  NULL, NULL) == NULL) ABORT ();
    if (Tcl_CreateObjCommand (interp, "ctrlcflag", cmd_ctrlcflag, NULL, NULL) == NULL) ABORT ();
    if (Tcl_CreateObjCommand (interp, "disop", cmd_disop, NULL, NULL) == NULL) ABORT ();
    if (Tcl_CreateObjCommand (interp, "gpio", cmd_gpio, NULL, NULL) == NULL) ABORT ();
    if (Tcl_CreateObjCommand (interp, "help", cmd_help, NULL, NULL) == NULL) ABORT ();
    if (Tcl_CreateObjCommand (interp, "iic", cmd_iic, NULL, NULL) == NULL) ABORT ();
    if (Tcl_CreateObjCommand (interp, "mem",  cmd_mem,  NULL, NULL) == NULL) ABORT ();
    if (Tcl_CreateObjCommand (interp, "randbits",  cmd_randbits,  NULL, NULL) == NULL) ABORT ();

    signal (SIGINT, siginthand);

    clkratio = 20;
    char const *env = getenv ("clkratio");
    if (env != NULL) clkratio = atoi (env);

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

    vbkpl->zreset = 1;
    for (int i = 0; i < 100; i ++) {
        armclock ();
    }
    vbkpl->zreset = 0;

    rc = Tcl_EvalFile (interp, "verimain.tcl");
    if (rc != TCL_OK) {
        Tcl_EvalEx (interp, "puts stderr $::errorInfo", -1, TCL_EVAL_GLOBAL);
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
            Tcl_EvalEx (interp, "puts stderr $::errorInfo", -1, TCL_EVAL_GLOBAL);
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

        Tcl_EvalEx (interp, "flush stdout", -1, TCL_EVAL_GLOBAL);
        Tcl_EvalEx (interp, "flush stderr", -1, TCL_EVAL_GLOBAL);

        if (rc != TCL_OK) {
            int i, j;
            for (i = 0; (rer[i] != 0) && (rer[i] != '\n'); i ++) { }
            for (j = 0; j < i; j ++) if (rer[j] != rer[j+i/2+1]) break;
            if (rer[j] == ' ') j ++;
            if (rer[j] == 0) fprintf (stderr, "\nerror %d evaluating command\n", rc);
            else fprintf (stderr, "\nerror %d evaluating command: %s\n", rc, rer + j);
        }
        else if (rer[0] != 0) puts (rer);
    }

    return 0;
}

// arm [get] addr addr ... set addr data addr data ... [find xx]
static int cmd_arm (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
    bool setmode = false;
    int ngetobjs = 0;
    Tcl_Obj *getobjs[objc];

    for (int i = 0; ++ i < objc;) {
        char const *arg = Tcl_GetString (objv[i]);
        if (strcasecmp (arg, "find") == 0) {
            if (++ i >= objc) {
                Tcl_SetResultF (interp, "missing 2-char device code for find");
                return TCL_ERROR;
            }
            char const *ident = Tcl_GetString (objv[i]);
            int x = findev (ident);
            if (x < 0) {
                Tcl_SetResultF (interp, "unknown 2-char device code %s", ident);
                return TCL_ERROR;
            }
            getobjs[ngetobjs++] = Tcl_NewIntObj (x);
            continue;
        }
        if (strcasecmp (arg, "get") == 0) {
            setmode = false;
            continue;
        }
        if (strcasecmp (arg, "set") == 0) {
            setmode = true;
            continue;
        }
        char *p;
        uint32_t addr = strtoul (arg, &p, 0);
        if ((*p != 0) || (addr > 1023)) {
            Tcl_SetResultF (interp, "address %s not integer in range 0..1023", arg);
            return TCL_ERROR;
        }
        if (setmode) {
            if (++ i >= objc) {
                Tcl_SetResultF (interp, "missing value for address 0x%X", addr);
                return TCL_ERROR;
            }
            int data;
            int rc = Tcl_GetIntFromObj (interp, objv[i], &data);
            if (rc != TCL_OK) return rc;
            armwrite (addr, data);
        } else {
            uint32_t data = armread (addr);
            getobjs[ngetobjs++] = Tcl_NewIntObj (data);
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
            {  1, OFFS (iACCLEAR), true,  "iACCLEAR" },   // io pulse clears AC
            {  1, OFFS (iBRKGNTI), true,  "iBRKGNTI" },   // break grant chain
            {  1, OFFS (iBRKRQST), true,  "iBRKRQST" },   // requesting break
            {  1, OFFS (iBRKWRM),  true,  "iBRKWRM"  },   // break cycle writes memory
            {  1, OFFS (iCAINC),   true,  "iCAINC"   },   // curad cycle increments address word
            {  1, OFFS (iCYCLE3),  true,  "iCYCLE3"  },   // do 3-cycle break
            {  1, OFFS (iINTRQST), true,  "iINTRQST" },   // request interrupt
            {  1, OFFS (iIOSKIP),  true,  "iIOSKIP"  },   // increment PC at end of IO pulse
            {  3, OFFS (iDMAFLD),  true,  "iDMAFLD"  },   // device sending address for DMA
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
            {  1, OFFS (swstart),  false, "swstart"  },
            {  1, OFFS (swsstep),  false, "swsstep"  },
            {  1, OFFS (swsinst),  false, "swsinst"  },
            {  1, OFFS (swldad),   false, "swldad"   },
            {  1, OFFS (swexam),   false, "swexam"   },
            {  1, OFFS (swdepos),  false, "swdepos"  },
#ifdef ZTURN
            { 12, OFFS (businbus), false, "businbus" },
            {  1, OFFS (busacclr), false, "busacclr" },
            {  1, OFFS (busintrq), false, "busintrq" },
            {  1, OFFS (busioskp), false, "busioskp" },
#endif

            { 12, OFFS (oACUM),    false, "oACUM"    },
            {  1, OFFS (oBRKGNTO), false, "oBRKGNTO" },   // break grant chain
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
static int cmd_clk (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
    if ((objc > 1) && (strcasecmp (Tcl_GetString (objv[1]), "ratio") == 0)) {
        Tcl_SetObjResult (interp, Tcl_NewIntObj (clkratio));
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
        vbkpl->gpin = scramgpio (num);
#endif
#ifdef ZTURN
        zpage[Z_RH] = scramgpio (num);
#endif
    } else {
#ifdef VERLTR
        int num = scramgpio (vbkpl->gpout);
#endif
#ifdef ZTURN
        int num = scramgpio (zpage[Z_RI]);
#endif
        Tcl_SetObjResult (interp, Tcl_NewIntObj (num));
    }
    return TCL_OK;
}

static int cmd_help (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
    puts ("");
    puts ("  asmop <addr> <instr...> - assemble instruction");
    puts ("  bus <busops...>         - access bus signals");
    puts ("  clk [<n>]               - step 100nS clock");
    puts ("  ctrlcflag [0|1]         - check control-C, clear/set flag");
    puts ("  disop <addr> <opcode>   - disassemble opcode");
    puts ("  gpio [<in>]             - write input value, read output value");
    puts ("  iic [wr <n> rs rd...]   - access iic bus to console mcp23017");
    puts ("  mem <addr> [<data>]     - backdoor access to memory chip");
    puts ("  randbits <n>            - get random memory bits");
    puts ("");
    return TCL_OK;
}

// iic
//  check for reply
//   "" - no reply yet
//   else: value
// iic wr <byte> st rd
//  queue command
//   wr - send following byte
//   st - send restart
//   rd - read a byte
#define IICWR 3ULL
#define IICRD 2ULL
#define IICRS 1ULL
static int cmd_iic (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
    static int fpat = -1;

    if (fpat < 0) {
        fpat = findev ("FP");
        if (fpat < 0) ABORT ();
    }

    uint32_t statushi = armread (fpat + 4);
    if (objc < 2) {
        if ((statushi & 0xC0000000U) != 0) {
            uint32_t statuslo = armread (fpat + 3);
            Tcl_SetResultF (interp, "%llu", ((uint64_t) statushi << 32) | statuslo);
        }
        return TCL_OK;
    }
    if ((statushi & 0xC0000000U) == 0) {
        Tcl_SetResultF (interp, "busy with previous command");
        return TCL_ERROR;
    }

    uint64_t comand = 0;
    int nn = 64;
    for (int i = 0; ++ i < objc;) {
        char const *arg = Tcl_GetString (objv[i]);
        if (strcasecmp (arg, "wr") == 0) {
            if (++ i >= objc) {
                Tcl_SetResultF (interp, "missing value for wr");
                return TCL_ERROR;
            }
            int val;
            int rc = Tcl_GetIntFromObj (interp, objv[i], &val);
            if (rc != TCL_OK) return rc;
            if ((val < 0) || (val > 255)) {
                Tcl_SetResultF (interp, "wr value %d out of range 0..255", val);
                return TCL_ERROR;
            }
            if (nn < 10) {
                Tcl_SetResultF (interp, "command too long");
                return TCL_ERROR;
            }
            nn -= 2;
            comand |= IICWR << nn;
            nn -= 8;
            comand |= ((uint64_t) val) << nn;
            continue;
        }
        if (strcasecmp (arg, "rd") == 0) {
            if (nn < 2) {
                Tcl_SetResultF (interp, "command too long");
                return TCL_ERROR;
            }
            nn -= 2;
            comand |= IICRD << nn;
            continue;
        }
        if (strcasecmp (arg, "rs") == 0) {
            if (nn < 2) {
                Tcl_SetResultF (interp, "command too long");
                return TCL_ERROR;
            }
            nn -= 2;
            comand |= IICRS << nn;
            continue;
        }
        Tcl_SetResultF (interp, "unknown subcommand %s", arg);
        return TCL_ERROR;
    }
    armwrite (fpat + 1, comand);
    armwrite (fpat + 2, comand >> 32);
    return TCL_OK;
}

// direct internal memory access - accesses 32KW 12-bit chip on extmemory.v board
static int mungememaddr (int addr)
{
    int munged = addr & 070037;
    if (addr & 00040) munged |= 04000;
    if (addr & 00100) munged |= 02000;
    if (addr & 00200) munged |= 01000;
    if (addr & 00400) munged |= 00400;
    if (addr & 01000) munged |= 00200;
    if (addr & 02000) munged |= 00100;
    if (addr & 04000) munged |= 00040;
    return munged;
}
static int mungemembyte (int data)
{
    data &= 0077;
    if (data & 0010) data ^= 0210;
    if (data & 0020) data ^= 0120;
    return data;
}
static int demngmembyte (int data)
{
    data &= 0347;
    if (data & 0200) data ^= 0210;
    if (data & 0100) data ^= 0120;
    return data;
}

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
            addr = mungememaddr (addr);
            int datalo = demngmembyte (vbkpl->__PVT__backplane__DOT__meminst->__PVT__U175__DOT__array[addr]);
            int datahi = demngmembyte (vbkpl->__PVT__backplane__DOT__meminst->__PVT__U177__DOT__array[addr]);
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
            addr = mungememaddr (addr);
            vbkpl->__PVT__backplane__DOT__meminst->__PVT__U175__DOT__array[addr] = mungemembyte (data);
            vbkpl->__PVT__backplane__DOT__meminst->__PVT__U177__DOT__array[addr] = mungemembyte (data >> 6);
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

// scramble/unscramble gpio data bits
static uint32_t scramgpio (uint32_t x)
{
    uint32_t y = x & ~ 0xFFF;
    if (x & 0x400) y |= 0x800;
    if (x & 0x800) y |= 0x400;
    if (x & 0x001) y |= 0x200;
    if (x & 0x002) y |= 0x100;
    if (x & 0x004) y |= 0x080;
    if (x & 0x008) y |= 0x040;
    if (x & 0x010) y |= 0x020;
    if (x & 0x020) y |= 0x010;
    if (x & 0x040) y |= 0x008;
    if (x & 0x080) y |= 0x004;
    if (x & 0x100) y |= 0x002;
    if (x & 0x200) y |= 0x001;
    return y;
}

// call with 10MHz clock still low and input signals just changed
// returns with output signals updated and 10MHz clock just set low
static void kerchunk ()
{
    // 20 200MHz cycles step the 10MHz osc through a cycle
    // each 200MHz step progresses signals through gates and flipflops

#ifdef ZTURN
    uint32_t ctla = zpage[zclock_I];
#endif
    for (int i = 0; i < clkratio; i ++) {
#ifdef VERLTR
        vbkpl->eval ();     // let input signals soak in
        vbkpl->yclock = (i * 2 >= clkratio);
        vbkpl->zclock = 1;  // clock progress through gates and flipflops
        vbkpl->eval ();     // let new state settle in
        vbkpl->zclock = 0;
#endif
#ifdef ZTURN
        zpage[zclock_I] = ctla | zclock_M;
        zpage[zclock_I] = ctla;
#endif
        simulationtime += 5;
    }
#ifdef VERLTR
    vbkpl->yclock = 0;
#endif
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
            vbkpl->eval ();
#endif
#ifdef ZTURN
            zpage[pin->indx] = (zpage[pin->indx] & ~ pin->mask) | (val * (pin->mask & - pin->mask));
#endif
        } else {
#ifdef VERLTR
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
    if (ngetobjs == 1) {
        Tcl_SetObjResult (interp, getobjs[0]);
    }
    if (ngetobjs > 1) {
        Tcl_SetObjResult (interp, Tcl_NewListObj (ngetobjs, getobjs));
    }
    return TCL_OK;
}

////////////////////////////////
//  simulated ARM bus access  //
////////////////////////////////

// find device on the ARM bus (within zynq.v)
static int findev (char const *ident)
{
    if (strlen (ident) != 2) return -1;
    for (uint32_t i = 0; i < 1024;) {
        uint32_t id = armread (i);
        uint32_t nwords = 2 << ((i >> 12) & 15);
        if (i + nwords > 1024) break;
        if (((char)(id >> 24) == ident[0]) && ((char)(id >> 16) == ident[1])) return i;
        i += nwords;
    }
    return -1;
}

// read word from the ARM bus
static uint32_t armread (uint32_t armaddr)
{
    vbkpl->saxi_ARADDR  = armaddr << 2;
    vbkpl->saxi_ARVALID = 1;
    vbkpl->saxi_RREADY  = 1;
    uint32_t armdata = 0;
    for (int i = 0; vbkpl->saxi_ARVALID | vbkpl->saxi_RREADY; i ++) {
        if (i > 100) ABORT ();
        bool arready = vbkpl->saxi_ARREADY;
        armclock ();
        if (arready) vbkpl->saxi_ARVALID = 0;
        if (vbkpl->saxi_RVALID & vbkpl->saxi_RREADY) {
            armdata = vbkpl->saxi_RDATA;
            vbkpl->saxi_RREADY = 0;
        }
    }
    return armdata;
}

// write word to the ARM bus
static void armwrite (uint32_t armaddr, uint32_t armdata)
{
    vbkpl->saxi_AWADDR  = armaddr << 2;
    vbkpl->saxi_AWVALID = 1;
    vbkpl->saxi_WDATA   = armdata;
    vbkpl->saxi_WVALID  = 1;
    vbkpl->saxi_BREADY  = 1;
    for (int i = 0; vbkpl->saxi_AWVALID | vbkpl->saxi_WVALID | vbkpl->saxi_RREADY; i ++) {
        if (i > 100) ABORT ();
        bool awready = vbkpl->saxi_AWREADY;
        bool wready  = vbkpl->saxi_WREADY;
        armclock ();
        if (awready) vbkpl->saxi_AWVALID = 0;
        if (wready)  vbkpl->saxi_WVALID  = 0;
        if (vbkpl->saxi_BVALID) vbkpl->saxi_BREADY = 0;
    }
}

static void armclock ()
{
    vbkpl->eval ();     // let pre-clock signals soak into fpga
    vbkpl->zclock = 1;  // drive clock high
    vbkpl->eval ();     // let fpga generate post-clock signals
    vbkpl->zclock = 0;  // get ready for 2nd half of cycle
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

double sc_time_stamp()
{
    return simulationtime;
}
