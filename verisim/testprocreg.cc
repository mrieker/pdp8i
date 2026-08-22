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

// test physical procreg board
// runs on raspi plugged into tester board with physical procreg board plugged in
// use various ./testprocreg-*.sh scripts to test registers on procreg board

#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#include "../ccode/randbits.h"
#include "../ccode/tclmain.h"

#include "testlib.h"

#define mp_memacsw mp__SCTR_4   // J2 P19

static int const procreg_impins[] = {
    mp__BRKWRM, mp__BUSINI, mp__CAINC, mp__INBUS_9, mp__INBUS_10, mp__INBUS_11, mp__IOP, mp__IOSKIP, mp__LNKTOG,
    mp__MAJST_0, mp__MAJST_1, mp__MAJST_2, mp__MAJST_3, mp__RUN, mp__SWCONT, mp__SWDEPOS, mp__SWEXAM, mp__SWLDAD,
    mp__TP1, mp__TP2, mp__TP3, mp__TP4, mp__TS1, mp__TS2, mp__TS3, mp__TS4, mp_aluq_0, mp_aluq_1, mp_aluq_2, mp_aluq_3,
    mp_aluq_4, mp_aluq_5, mp_aluq_6, mp_aluq_7, mp_aluq_8, mp_aluq_9, mp_aluq_10, mp_aluq_11, mp_cout, mp_memacsw, 0 };

static int const procreg_ompins[] = {
    mp__ACUM_0, mp__ACUM_1, mp__ACUM_2, mp__ACUM_3, mp__ACUM_4, mp__ACUM_5, mp__ACUM_6, mp__ACUM_7, mp__ACUM_8, mp__ACUM_9, mp__ACUM_10, mp__ACUM_11,
    mp__MADR_0, mp__MADR_1, mp__MADR_2, mp__MADR_3, mp__MADR_4, mp__MADR_5, mp__MADR_6, mp__MADR_7, mp__MADR_8, mp__MADR_9, mp__MADR_10, mp__MADR_11,
    mp__MBUF_0, mp__MBUF_1, mp__MBUF_2, mp__MBUF_3, mp__MBUF_4, mp__MBUF_5, mp__MBUF_6, mp__MBUF_7, mp__MBUF_8, mp__MBUF_9, mp__MBUF_10, mp__MBUF_11,
    mp__PCTR_0, mp__PCTR_1, mp__PCTR_2, mp__PCTR_3, mp__PCTR_4, mp__PCTR_5, mp__PCTR_6, mp__PCTR_7, mp__PCTR_8, mp__PCTR_9, mp__PCTR_10, mp__PCTR_11,
    mp__BRKCYC, mp__BWCOV, mp__IREG_9, mp__IREG_10, mp__IREG_11, mp__LINK, 0 };

static int const mps_aluq[] = {
    mp_aluq_11, mp_aluq_10, mp_aluq_9, mp_aluq_8,
    mp_aluq_7,  mp_aluq_6,  mp_aluq_5, mp_aluq_4,
    mp_aluq_3,  mp_aluq_2,  mp_aluq_1, mp_aluq_0,
    0 };

static Tcl_ObjCmdProc cmd_pin;
static TclFunDef const tclfundefs[] = { { cmd_pin, "pin", "access edge connector pins" }, { NULL, NULL, NULL } };

int main (int argc, char **argv)
{
    setlinebuf (stdout);

    // make masks of input and output pins so we know what words to send/receive on i2c busses
    setmpinmask (boardipinmask, procreg_impins);
    setmpinmask (boardopinmask, procreg_ompins);
    mcpsetdir ();

    return tclmain (
        tclfundefs,
        argv[0],
        "testprocreg",
        NULL,
        "testprocreg.tcl",
        0,
        NULL);
}

// tcl command to give direct access to tester pins

// pin definitions
struct PinDef {
    char name[16];
    int mpin;
    bool writ;
};

struct PinsDef {
    char name[16];
    int const *mpins;
    bool writ;
};

static PinDef const pindefs[] = {
    { "_BRKWRM",  mp__BRKWRM,  true  },
    { "_BUSINI",  mp__BUSINI,  true  },
    { "_CAINC",   mp__CAINC,   true  },
    { "_IOP",     mp__IOP,     true  },
    { "_IOSKIP",  mp__IOSKIP,  true  },
    { "_LNKTOG",  mp__LNKTOG,  true  },
    { "_RUN",     mp__RUN,     true  },
    { "_SWCONT",  mp__SWCONT,  true  },
    { "_SWDEPOS", mp__SWDEPOS, true  },
    { "_SWEXAM",  mp__SWEXAM,  true  },
    { "_SWLDAD",  mp__SWLDAD,  true  },
    { "_TP1",     mp__TP1,     true  },
    { "_TP2",     mp__TP2,     true  },
    { "_TP3",     mp__TP3,     true  },
    { "_TP4",     mp__TP4,     true  },
    { "_TS1",     mp__TS1,     true  },
    { "_TS2",     mp__TS2,     true  },
    { "_TS3",     mp__TS3,     true  },
    { "_TS4",     mp__TS4,     true  },
    { "cout",     mp_cout,     true  },
    { "memacsw",  mp_memacsw,  true  },

    { "_BRKCYC",  mp__BRKCYC,  false  },
    { "_BWCOV",   mp__BWCOV,   false  },
    { "_LINK",    mp__LINK,    false  },

    { "", 0, 0 }
};

static PinsDef const pinsdefs[] = {
    { "_INBUS",   mps__INBUS,  true  },
    { "_MAJST",   mps__MAJST,  true  },
    { "aluq",     mps_aluq,    true  },

    { "_ACUM",    mps__ACUM,   false  },
    { "_IREG",    mps__IREG,   false  },
    { "_MADR",    mps__MADR,   false  },
    { "_MBUF",    mps__MBUF,   false  },
    { "_PCTR",    mps__PCTR,   false  },

    { "", NULL, 0 }
};

static int cmd_pin (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
    if ((objc == 2) && (strcasecmp (Tcl_GetString (objv[1]), "help") == 0)) {
        puts ("");
        puts ("  pin {get pin ...} | {set pin val ...} ...");
        puts ("    defaults to get");
        puts ("    get returns integer value");
        puts ("");
        return TCL_OK;
    }

    bool needtorecv = true;
    bool needtosend = false;
    bool setmode = false;
    int ngotvals = 0;
    Tcl_Obj *gotvals[objc];

    for (int i = 0; ++ i < objc;) {
        char const *name = Tcl_GetString (objv[i]);

        if (strcasecmp (name, "get") == 0) {
            setmode = false;
            continue;
        }
        if (strcasecmp (name, "set") == 0) {
            setmode = true;
            continue;
        }

        bool writeable;
        int const *pinsptr;
        int singlepin[2];

        int complement = (*name == '_');
        name += complement;

        // signalname
        {
            PinDef const *pte = NULL;
            PinsDef const *pste = NULL;
            for (pte = pindefs; pte->name[0] != 0; pte ++) {
                char const *pn = pte->name;
                int com = (*pn == '_');
                pn += com;
                if (strcasecmp (pn, name) == 0) {
                    complement ^= com;
                    writeable = pte->writ;
                    singlepin[0] = pte->mpin;
                    singlepin[1] = 0;
                    pinsptr = singlepin;
                    goto gotit;
                }
            }
            pte = NULL;
            for (pste = pinsdefs; pste->name[0] != 0; pste ++) {
                char const *pn = pste->name;
                int com = (*pn == '_');
                pn += com;
                if (strcasecmp (pn, name) == 0) {
                    complement ^= com;
                    writeable = pste->writ;
                    pinsptr = pste->mpins;
                    goto gotit;
                }
            }
            Tcl_SetResultF (interp, "bad pin name %s", name);
            return TCL_ERROR;
        gotit:;
        }

        if (setmode) {
            if (! writeable) {
                Tcl_SetResultF (interp, "pin %s not settable", name);
                return TCL_ERROR;
            }
            if (++ i >= objc) {
                Tcl_SetResultF (interp, "missing pin value for set %s", name);
                return TCL_ERROR;
            }
            int val;
            int rc  = Tcl_GetIntFromObj (interp, objv[i], &val);
            if (rc != TCL_OK) return rc;
            if (complement) {
                for (int j = 0; pinsptr[j] != 0; j ++) val ^= 1 << j;
            }
            setmpins (pinsptr, val);
            needtosend = true;
        } else {
            if (needtosend) {
                mcpsend ();
                needtosend = false;
                needtorecv = true;
            }
            if (needtorecv) {
                mcprecv ();
                needtorecv = false;
            }
            int val = getmpins (pinsptr);
            if (complement) {
                for (int j = 0; pinsptr[j] != 0; j ++) val ^= 1 << j;
            }
            gotvals[ngotvals++] = Tcl_NewIntObj (val);
        }
    }

    if (needtosend) {
        mcpsend ();
    }

    if (ngotvals > 0) {
        if (ngotvals < 2) {
            Tcl_SetObjResult (interp, gotvals[0]);
        } else {
            Tcl_SetObjResult (interp, Tcl_NewListObj (ngotvals, gotvals));
        }
    }
    return TCL_OK;
}
