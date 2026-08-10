//    Copyright (C) Mike Rieker, Beverly, MA USA
//    www.outerworldapps.com
//
//    This program is free software; you can redistribute it and/or modify
//    it under the terms of the GNU General Public License as published by
//    the Free Software Foundation; version 2 of the License.
//
//    This program is distributed in the hope that it will be useful,
//    but WITHOUT ANY WARRANTY; without even the implied warranty of
//    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//    GNU General Public License for more details.
//
//    EXPECT it to FAIL when someone's HeALTh or PROpeRTy is at RISk.
//
//    You should have received a copy of the GNU General Public License
//    along with this program; if not, write to the Free Software
//    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//
//    http://www.gnu.org/licenses/gpl-2.0.html

// test circuit board design
// provides TCL access to backplane.v module which has the circuit boards plugged into it including the zynq
// used primarily by simtest.sh to test logic and timing of circuit boards

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

#include "Vbackplane.h"
#include "Vbackplane_console.h"
#include "Vbackplane_extmemory.h"

#include "assemble.h"
#include "disassemble.h"
#include "readprompt.h"

#define ABORT() do { fprintf (stderr, "ABORT %s %d\n", __FILE__, __LINE__); abort (); } while (0)

struct Pin {
    int bits;
    int size;
    void *addr;
    bool writ;
    char const *name;
};

static bool volatile ctrlcflag;
static int cyclenum;
static uint64_t simulationns;

static Vbackplane *vbkpl;

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
static int cmdpintable (int pincount, Pin const *pintable, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[]);
static int findev (char const *ident);
static uint32_t armread (uint32_t armaddr);
static void armwrite (uint32_t armaddr, uint32_t armdata);
static void zynqclock ();
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

    Vbackplane vbackplane;
    vbkpl = &vbackplane;

    vbkpl->zreset = 1;
    for (int i = 0; i < 100; i ++) {
        zynqclock ();
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
            getobjs[ngetobjs++] = Tcl_NewLongObj (data);
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

#define OFFS(x) sizeof (vbkpl->x), &vbkpl->x

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

            {  1, OFFS (brkrqst),  false, "brkrqst"  },
            {  1, OFFS (intrqst),  false, "intrqst"  },
            {  4, OFFS (majst),    false, "majst"    },
            {  3, OFFS (memfield), false, "memfield" },
            {  1, OFFS (pause),    false, "pause"    },
            { 12, OFFS (mquo),     false, "mquo"     },
            { 12, OFFS (pctr),     false, "pctr"     },
            {  5, OFFS (sctr),     false, "sctr"     },

            {  1, OFFS (swcont),   false, "swcont"   },
            {  1, OFFS (swstart),  false, "swstart"  },
            {  1, OFFS (swsstep),  false, "swsstep"  },
            {  1, OFFS (swsinst),  false, "swsinst"  },
            {  1, OFFS (swldad),   false, "swldad"   },
            {  1, OFFS (swexam),   false, "swexam"   },
            {  1, OFFS (swdepos),  false, "swdepos"  },
            { 12,   -1, NULL,      false, "swreg"    },
            {  3,   -2, NULL,      false, "swdfld"   },
            {  3,   -3, NULL,      false, "swifld"   },

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
//  clock given number of PDP clock cycles
//  returns halfway through cycle with clock still high
//  returns total number of PDP clock cycles
// clk simns
//  returns number of simulation nanoseconds
static int cmd_clk (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
    if ((objc > 1) && (strcasecmp (Tcl_GetString (objv[1]), "simns") == 0)) {
        Tcl_SetObjResult (interp, Tcl_NewLongObj (simulationns));
        return TCL_OK;
    }
    int num = 1;
    if (objc > 1) {
        int rc = Tcl_GetIntFromObj (interp, objv[1], &num);
        if (rc != TCL_OK) return rc;
    }
    while (-- num >= 0) {

        // 20 200MHz cycles step the 10MHz osc through a cycle
        // each 200MHz step progresses signals through gates and flipflops

        bool lastoclock = vbkpl->oCLOCK;
        for (int i = 0; i < 256; i ++) {

            // error if shadow has frozen the clock
            if (vbkpl->shad_freeze) {
                int shat = findev ("SH");
                if (shat < 0) {
                    Tcl_SetResult (interp, (char *) "shadow error", TCL_STATIC);
                } else {
                    uint32_t shad1 = armread (shat + 1);
                    uint32_t shad2 = armread (shat + 2);
                    uint32_t shad3 = armread (shat + 3);
                    uint32_t shad4 = armread (shat + 4);
                    uint32_t shad5 = armread (shat + 5);
                    Tcl_SetResultF (interp, "shadow error %08X %08X %08X %08X %08X", shad1, shad2, shad3, shad4, shad5);
                }
                return TCL_ERROR;
            }

            // pulse zclock (200MHz) and yclock (100MHz)
            zynqclock ();

            // stop looping on high-to-low 10MHz clock
            if (lastoclock && ! vbkpl->oCLOCK) break;
            lastoclock = vbkpl->oCLOCK;
        }
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
        vbkpl->gpin = scramgpio (num);
    } else {
        uint32_t num = scramgpio (vbkpl->gpout);
        Tcl_SetObjResult (interp, Tcl_NewLongObj (num));
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

// direct internal memory access - accesses 32KW 12-bit chip on extmemory.kicad_sch board
// - take 15-bit address in MEAD,MADR registers and come up with chip addresses
static int mungememaddr_U175 (int madx)
{
    int a1400 = 0;
    if (madx & 000001) a1400 |= 000001;
    if (madx & 000002) a1400 |= 000002;
    if (madx & 000004) a1400 |= 000004;
    if (madx & 000010) a1400 |= 000010;
    if (madx & 000020) a1400 |= 000020;
    if (madx & 040000) a1400 |= 000040;
    if (madx & 020000) a1400 |= 000100;
    if (madx & 010000) a1400 |= 000200;
    if (madx & 000400) a1400 |= 000400;
    if (madx & 000200) a1400 |= 001000;
    if (madx & 000100) a1400 |= 002000;
    if (madx & 000040) a1400 |= 004000;
    if (madx & 001000) a1400 |= 010000;
    if (madx & 002000) a1400 |= 020000;
    if (madx & 004000) a1400 |= 040000;
    return a1400;
}
static int mungememaddr_U177 (int madx)
{
    int a1400 = 0;
    if (madx & 000020) a1400 |= 000001;
    if (madx & 000010) a1400 |= 000002;
    if (madx & 000004) a1400 |= 000004;
    if (madx & 000002) a1400 |= 000010;
    if (madx & 000001) a1400 |= 000020;
    if (madx & 004000) a1400 |= 000040;
    if (madx & 002000) a1400 |= 000100;
    if (madx & 001000) a1400 |= 000200;
    if (madx & 000040) a1400 |= 000400;
    if (madx & 000100) a1400 |= 001000;
    if (madx & 000200) a1400 |= 002000;
    if (madx & 000400) a1400 |= 004000;
    if (madx & 010000) a1400 |= 010000;
    if (madx & 020000) a1400 |= 020000;
    if (madx & 040000) a1400 |= 040000;
    return a1400;
}
// - likewise scramble MBUF data lines to chip data lines
static int mungemembyte_U175 (int mbuf0500)
{
    int d0700 = 0;
    if (mbuf0500 & 001) d0700 |= 0001;
    if (mbuf0500 & 002) d0700 |= 0002;
    if (mbuf0500 & 004) d0700 |= 0004;
    if (mbuf0500 & 040) d0700 |= 0040;
    if (mbuf0500 & 020) d0700 |= 0100;
    if (mbuf0500 & 010) d0700 |= 0200;
    return d0700;
}
static int mungemembyte_U177 (int mbuf1106)
{
    int d0700 = 0;
    if (mbuf1106 & 001) d0700 |= 0001;
    if (mbuf1106 & 002) d0700 |= 0002;
    if (mbuf1106 & 004) d0700 |= 0004;
    if (mbuf1106 & 040) d0700 |= 0040;
    if (mbuf1106 & 020) d0700 |= 0100;
    if (mbuf1106 & 010) d0700 |= 0200;
    return d0700;
}
// - unscramble chip data lines for INBUS lines
static int demunmembyte_U175 (int d0700)
{
    int inbus0500 = 0;
    if (d0700 & 0001) inbus0500 |= 001;
    if (d0700 & 0002) inbus0500 |= 002;
    if (d0700 & 0004) inbus0500 |= 004;
    if (d0700 & 0040) inbus0500 |= 040;
    if (d0700 & 0100) inbus0500 |= 020;
    if (d0700 & 0200) inbus0500 |= 010;
    return inbus0500;
}
static int demunmembyte_U177 (int d0700)
{
    int inbus1106 = 0;
    if (d0700 & 0001) inbus1106 |= 001;
    if (d0700 & 0002) inbus1106 |= 002;
    if (d0700 & 0004) inbus1106 |= 004;
    if (d0700 & 0040) inbus1106 |= 040;
    if (d0700 & 0100) inbus1106 |= 020;
    if (d0700 & 0200) inbus1106 |= 010;
    return inbus1106;
}

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
            int addr_U175 = mungememaddr_U175 (addr);
            int addr_U177 = mungememaddr_U177 (addr);
            int datalo = demunmembyte_U175 (vbkpl->__PVT__backplane__DOT__meminst->__PVT__U175__DOT__array[addr_U175]);
            int datahi = demunmembyte_U177 (vbkpl->__PVT__backplane__DOT__meminst->__PVT__U177__DOT__array[addr_U177]);
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
            int addr_U175 = mungememaddr_U175 (addr);
            int addr_U177 = mungememaddr_U177 (addr);
            int data_U175 = mungemembyte_U175 (data);
            int data_U177 = mungemembyte_U177 (data >> 6);
            vbkpl->__PVT__backplane__DOT__meminst->__PVT__U175__DOT__array[addr_U175] = data_U175;
            vbkpl->__PVT__backplane__DOT__meminst->__PVT__U177__DOT__array[addr_U177] = data_U177;
            return TCL_OK;
        }

        default: {
            Tcl_SetResultF (interp, "missing/extra arguments");
            return TCL_ERROR;
        }
    }
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
            if ((pin->size <= 0) || (pin->size > (int) sizeof val) || (pin->addr == NULL)) ABORT ();
            memcpy (pin->addr, &val, pin->size);
            vbkpl->eval ();
        } else {
            uint32_t val = 0;
            if (pin->addr != NULL) {
                if ((pin->size <= 0) || (pin->size > (int) sizeof val)) ABORT ();
                memcpy (&val, pin->addr, pin->size);
            } else {
                switch (pin->size) {
                    case -1: {  // "swreg"
                        Vbackplane_console *vcon = vbkpl->__PVT__backplane__DOT__conboard;
                        val =
                            (((vcon->__PVT___swreg_11 & 1) << 11) |
                             ((vcon->__PVT___swreg_10 & 1) << 10) |
                             ((vcon->__PVT___swreg_9  & 1) <<  9) |
                             ((vcon->__PVT___swreg_8  & 1) <<  8) |
                             ((vcon->__PVT___swreg_7  & 1) <<  7) |
                             ((vcon->__PVT___swreg_6  & 1) <<  6) |
                             ((vcon->__PVT___swreg_5  & 1) <<  5) |
                             ((vcon->__PVT___swreg_4  & 1) <<  4) |
                             ((vcon->__PVT___swreg_3  & 1) <<  3) |
                             ((vcon->__PVT___swreg_2  & 1) <<  2) |
                             ((vcon->__PVT___swreg_1  & 1) <<  1) |
                             ((vcon->__PVT___swreg_0  & 1) <<  0)) ^ 07777;
                        break;
                    }
                    case -2: {  // "swdfld"
                        Vbackplane_console *vcon = vbkpl->__PVT__backplane__DOT__conboard;
                        val =
                            (((vcon->__PVT___swdfld_2 & 1) << 2) |
                             ((vcon->__PVT___swdfld_1 & 1) << 1) |
                             ((vcon->__PVT___swdfld_0 & 1) << 0)) ^ 7;
                        break;
                    }
                    case -3: {  // "swifld"
                        Vbackplane_console *vcon = vbkpl->__PVT__backplane__DOT__conboard;
                        val =
                            (((vcon->__PVT___swifld_2 & 1) << 2) |
                             ((vcon->__PVT___swifld_1 & 1) << 1) |
                             ((vcon->__PVT___swifld_0 & 1) << 0)) ^ 7;
                        break;
                    }
                    default: ABORT ();
                }
            }
            getobjs[ngetobjs++] = Tcl_NewLongObj (val);
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
#if 000
    vbkpl->saxi_ARADDR  = armaddr << 2;
    vbkpl->saxi_ARVALID = 1;
    vbkpl->saxi_RREADY  = 1;
    uint32_t armdata = 0;
    for (int i = 0; vbkpl->saxi_ARVALID | vbkpl->saxi_RREADY; i ++) {
        if (i > 100) ABORT ();
        bool arready = vbkpl->saxi_ARREADY;
        zynqclock ();
        if (arready) vbkpl->saxi_ARVALID = 0;
        if (vbkpl->saxi_RVALID & vbkpl->saxi_RREADY) {
            armdata = vbkpl->saxi_RDATA;
            vbkpl->saxi_RREADY = 0;
        }
    }
    return armdata;
#else
    vbkpl->saxi_ARADDR = armaddr << 2;
    vbkpl->directread  = 1;
    vbkpl->eval ();
    vbkpl->directread  = 0;
    return vbkpl->saxi_RDATA;
#endif
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
        zynqclock ();
        if (awready) vbkpl->saxi_AWVALID = 0;
        if (wready)  vbkpl->saxi_WVALID  = 0;
        if (vbkpl->saxi_BVALID) vbkpl->saxi_BREADY = 0;
    }
}

// advance clock 10nS
// zclock = 200MHz, clocks gates and flipflops in chips-varns.v
// yclock = 100MHz, clocks zynq fpga
//  input:
//   yclock just went low after being high for 5nS
//   zclock just went low after being high for 2.5nS
//  output:
//   yclock just went low after being high for 5nS
//   zclock just went low after being high for 2.5nS
static void zynqclock ()
{
    if (vbkpl->yclock | vbkpl->zclock) ABORT();

    bool lastoclock = vbkpl->oCLOCK;

    vbkpl->eval ();     // run for 2.5nS with yclock=0, zclock=0
    vbkpl->zclock = 1;
    vbkpl->eval ();     // run for 2.5nS with yclock=0, zclock=1
    vbkpl->zclock = 0;
    vbkpl->yclock = 1;
    simulationns += 5;

    vbkpl->eval ();     // run for 2.5nS with yclock=1, zclock=0
    vbkpl->zclock = 1;
    vbkpl->eval ();     // run for 2.5nS with yclock=1, zclock=1
    vbkpl->zclock = 0;
    vbkpl->yclock = 0;
    simulationns += 5;

    // maybe 10MHz PDP clock just went low
    // count the cycle if so
    // actual freq is determined by zynq.v regctld clkratm1 (normally 9 for 10MHz)
    if (lastoclock && ! vbkpl->oCLOCK) ++ cyclenum;
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
    return (double) simulationns;
}
