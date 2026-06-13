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

// tcl command to give direct access to z8i fpga signals

#include <string.h>

#include "cmd_pin.h"
#include "tclmain.h"
#include "z8idefs.h"
#include "z8iutil.h"

// pin definitions
struct PinDef {
    char name[16];
    int dev;
    int reg;
    uint32_t mask;
    bool writ;
};

#define DEV_8I 0
#define DEV_CM 1
#define DEV_TT 2
#define DEV_FP 3

static Z8IU32 *devs[4];

static PinDef const pindefs[] = {

    { "arm_iACCLEAR",    DEV_8I, Z_RA, a_arm_iACCLEAR, true  },
    { "arm_iBRKGNTO",    DEV_8I, Z_RA, a_arm_iBRKGNTO, true  },
    { "arm_iBRKRQST",    DEV_8I, Z_RA, a_arm_iBRKRQST, true  },
    { "arm_iBRKWRM",     DEV_8I, Z_RA, a_arm_iBRKWRM,  true  },
    { "arm_iCAINC",      DEV_8I, Z_RA, a_arm_iCAINC,   true  },
    { "arm_iCYCLE3",     DEV_8I, Z_RA, a_arm_iCYCLE3,  true  },
    { "arm_iDMAFLD",     DEV_8I, Z_RA, a_arm_iDMAFLD,  true  },
    { "arm_iINBUS",      DEV_8I, Z_RA, a_arm_iINBUS,   true  },
    { "arm_iINTRQST",    DEV_8I, Z_RA, a_arm_iINTRQST, true  },
    { "arm_iIOSKIP",     DEV_8I, Z_RA, a_arm_iIOSKIP,  true  },
    { "arm_iPAUSE",      DEV_8I, Z_RA, a_arm_iPAUSE,   true  },

#if 000
    { "arm_swCONT",      DEV_8I, Z_RB, b_arm_swCONT,   true  },
    { "arm_swDEPOS",     DEV_8I, Z_RB, b_arm_swDEPOS,  true  },
    { "arm_swDFLD",      DEV_8I, Z_RB, b_arm_swDFLD,   true  },
    { "arm_swEXAM",      DEV_8I, Z_RB, b_arm_swEXAM,   true  },
    { "arm_swIFLD",      DEV_8I, Z_RB, b_arm_swIFLD,   true  },
    { "arm_swLDAD",      DEV_8I, Z_RB, b_arm_swLDAD,   true  },
    { "arm_swSINST",     DEV_8I, Z_RB, b_arm_swSINST,  true  },
    { "arm_swSSTEP",     DEV_8I, Z_RB, b_arm_swSSTEP,  true  },
    { "arm_swSTART",     DEV_8I, Z_RB, b_arm_swSTART,  true  },
    { "arm_swSR",        DEV_8I, Z_RB, b_arm_swSR,     true  },
#endif

    { "dev_iACCLEAR",    DEV_8I, Z_RC, c_dev_iACCLEAR, false },
    { "dev_iBRKGNTO",    DEV_8I, Z_RC, c_dev_iBRKGNTO, false },
    { "dev_iBRKRQST",    DEV_8I, Z_RC, c_dev_iBRKRQST, false },
    { "dev_iBRKWRM",     DEV_8I, Z_RC, c_dev_iBRKWRM,  false },
    { "dev_iCAINC",      DEV_8I, Z_RC, c_dev_iCAINC,   false },
    { "dev_iCYCLE3",     DEV_8I, Z_RC, c_dev_iCYCLE3,  false },
    { "dev_iDMAFLD",     DEV_8I, Z_RC, c_dev_iDMAFLD,  false },
    { "dev_iINBUS",      DEV_8I, Z_RC, c_dev_iINBUS,   false },
    { "dev_iINTRQST",    DEV_8I, Z_RC, c_dev_iINTRQST, false },
    { "dev_iIOSKIP",     DEV_8I, Z_RC, c_dev_iIOSKIP,  false },
    { "dev_iPAUSE",      DEV_8I, Z_RC, c_dev_iPAUSE,   false },

    { "simit",           DEV_8I, Z_RE, e_simit,        true  },
    { "fpgareset",       DEV_8I, Z_RE, e_fpgareset,    true  },
    { "nanocontin",      DEV_8I, Z_RE, e_nanocontin,   true  },
    { "nanotrigger",     DEV_8I, Z_RE, e_nanotrigger,  true  },
    { "nanocstep",       DEV_8I, Z_RE, e_nanocstep,    true  },
    { "oMADR",           DEV_8I, Z_RE, e_oMADR,        false },
    { "oMEAD",           DEV_8I, Z_RE, e_oMEAD,        false },
    { "oMBUF",           DEV_8I, Z_RE, e_oMBUF,        false },
    { "oMADX",           DEV_8I, Z_RE, e_oMADX,        false },

    { "oACUM",           DEV_8I, Z_RF, f_oACUM,        false },
    { "oBRKCYC",         DEV_8I, Z_RF, f_oBRKCYC,      false },
    { "oBRKGNTI",        DEV_8I, Z_RF, f_oBRKGNTI,     false },
    { "oBRKRQST",        DEV_8I, Z_RF, f_oBRKRQST,     false },
    { "oBUSINI",         DEV_8I, Z_RF, f_oBUSINI,      false },
    { "oBWCOV",          DEV_8I, Z_RF, f_oBWCOV,       false },
    { "oCLOCK",          DEV_8I, Z_RF, f_oCLOCK,       false },
    { "oIOP",            DEV_8I, Z_RF, f_oIOP,         false },
    { "oRESET",          DEV_8I, Z_RF, f_oRESET,       false },
    { "oTP1",            DEV_8I, Z_RF, f_oTP1,         false },
    { "oTP2",            DEV_8I, Z_RF, f_oTP2,         false },
    { "oTP3",            DEV_8I, Z_RF, f_oTP3,         false },
    { "oTP4",            DEV_8I, Z_RF, f_oTP4,         false },
    { "oTS1",            DEV_8I, Z_RF, f_oTS1,         false },
    { "oTS2",            DEV_8I, Z_RF, f_oTS2,         false },
    { "oTS3",            DEV_8I, Z_RF, f_oTS3,         false },
    { "oTS4",            DEV_8I, Z_RF, f_oTS4,         false },
    { "oMAJST",          DEV_8I, Z_RF, f_oMAJST,       false },

#if 000
    { "lbAC",            DEV_8I, Z_RG, g_lbAC,         false },
    { "lbMA",            DEV_8I, Z_RG, g_lbMA,         false },
    { "lbSC",            DEV_8I, Z_RG, g_lbSC,         false },
    { "lbION",           DEV_8I, Z_RG, g_lbION,        false },
    { "lbLINK",          DEV_8I, Z_RG, g_lbLINK,       false },
    { "lbPAU",           DEV_8I, Z_RG, g_lbPAU,        false },

    { "lbMB",            DEV_8I, Z_RH, h_lbMB,         false },
    { "lbMQ",            DEV_8I, Z_RH, h_lbMQ,         false },
    { "lbMS",            DEV_8I, Z_RH, h_lbMS,         false },
    { "lbIR",            DEV_8I, Z_RH, h_lbIR,         false },
    { "lbRUN",           DEV_8I, Z_RH, h_lbRUN,        false },

    { "lbPC",            DEV_8I, Z_RI, i_lbPC,         false },
    { "lbDF",            DEV_8I, Z_RI, i_lbDF,         false },
    { "lbEA",            DEV_8I, Z_RI, i_lbEA,         false },
    { "lbIF",            DEV_8I, Z_RI, i_lbIF,         false },
#endif

    { "memcycctr",       DEV_8I, Z_RN, 0xFFFFFFFFU,    false },

    { "CM_ADDR",         DEV_CM, 1, CM_ADDR,               true  },
    { "CM_WRITE",        DEV_CM, 1, CM_WRITE,              true  },
    { "CM_DATA",         DEV_CM, 1, CM_DATA,               true  },
    { "CM_CAINC",        DEV_CM, 1, CM_CAINC,              true  },
    { "CM_3CYCL",        DEV_CM, 1, CM_3CYCL,              true  },
    { "CM_WCOVF",        DEV_CM, 1, CM_WCOVF,              false },
    { "CM_BUSY",         DEV_CM, 1, CM_BUSY,               false },
    { "CM_BGNT",         DEV_CM, 2, CM2_BGNT,              false },
    { "CM_LOCK",         DEV_CM, 3, CM3_LOCK,              true  },

    { "KB_FLAG",         DEV_TT, Z_TTYKB, KB_FLAG,         true  },
    { "KB_ENAB",         DEV_TT, Z_TTYKB, KB_ENAB,         true  },
    { "KB_CHAR",         DEV_TT, Z_TTYKB, 07777,           true  },
    { "PR_FLAG",         DEV_TT, Z_TTYPR, PR_FLAG,         true  },
    { "PR_FULL",         DEV_TT, Z_TTYPR, PR_FULL,         true  },
    { "PR_CHAR",         DEV_TT, Z_TTYPR, 07777,           true  },

    { "FP_CMDLO",        DEV_FP,  1, FP1_CMDLO,            true  },
    { "FP_CMDHI",        DEV_FP,  2, FP2_CMDHI,            true  },
    { "FP_STSLO",        DEV_FP,  3, FP3_STSLO,            false },
    { "FP_STSHI",        DEV_FP,  4, FP4_STSHI,            false },
    { "FP_INMODE",       DEV_FP,  5, FP5_INMODE,           false },
    { "FP_MANUAL",       DEV_FP,  5, FP5_MANUAL,           true  },
    { "FP_I2CCOUNT",     DEV_FP,  5, FP5_I2CCOUNT,         false },
    { "FP_I2CSTATE",     DEV_FP,  5, FP5_I2CSTATE,         false },
    { "FP_I2CCLI",       DEV_FP,  5, FP5_I2CCLI,           false },
    { "FP_I2CDAI",       DEV_FP,  5, FP5_I2CDAI,           false },
    { "FP_I2CDAO",       DEV_FP,  5, FP5_I2CDAO,           true  },
    { "FP_I2CCLO",       DEV_FP,  5, FP5_I2CCLO,           true  },
    { "FP_LOCK",         DEV_FP,  6, FP6_LOCK,             true  },
    { "FP_SETSSTEP",     DEV_FP, 11, fp11_swSSTEP,         true  },
    { "FP_SETSTART",     DEV_FP, 11, fp11_swSTART,         true  },
    { "FP_DBNCOUNT",     DEV_FP, 12, fp12_dbncount,        false },
    { "FP_OVRSSTEP",     DEV_FP, 12, fp11_swSSTEP,         true  },
    { "FP_OVRSTART",     DEV_FP, 12, fp11_swSTART,         true  },
    { "FP_MCPASSNO",     DEV_FP,  7, fp7_mcpassno,         true  },
    { "FP_DBNLIMIT",     DEV_FP, 13, fp13_dbnlimit,        true  },
    { "FP_I2CSPEED",     DEV_FP, 13, fp13_i2cspeed,        true  },
    { "FP_LTSPEED",      DEV_FP, 13, fp13_ltspeed,         true  },

    { "", 0, 0, 0, false }
};

int cmd_pin (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
    if ((objc == 2) && (strcasecmp (Tcl_GetString (objv[1]), "help") == 0)) {
        puts ("");
        puts ("  pin list - list all the pins");
        puts ("");
        puts ("  pin {get pin ...} | {set pin val ...} | {test pin ...} ...");
        puts ("    defaults to get");
        puts ("    get returns integer value");
        puts ("    test returns -1: undefined; 0: read-only; 1: read/write");
        puts ("");
        puts ("  'o' pins : simit=0 : read PDP-8/I output pins");
        puts ("             simit=1 : read simulator output pins");
        puts ("");
        puts ("  'i' pins : simit=0 : drives PDP-8/I inputs from device & arm register");
        puts ("             simit=1 : drives simulator inputs from device & arm register");
        puts ("            bareit=0 : logical OR of device and arm register");
        puts ("            bareit=1 : just value of arm register");
        puts ("");
        return TCL_OK;
    }

    if ((objc == 2) && (strcasecmp (Tcl_GetString (objv[1]), "list") == 0)) {
        for (PinDef const *pte = pindefs; pte->name[0] != 0; pte ++) {
            Z8IU32 *ptr = devs[pte->dev];
            printf ("  %-16s  %c%c[%2u]  %08X\n",
                pte->name, (ptr[0] >> 24) & 0xFFU, (ptr[0] >> 16) & 0xFFU, pte->reg, pte->mask);
        }
        return TCL_OK;
    }

    if (devs[0] == NULL) {

        // access the zynq io page and find devices thereon
        devs[DEV_8I] = z8ipage.findev ("8I", NULL, NULL, false);
        devs[DEV_CM] = z8ipage.findev ("CM", NULL, NULL, false);
        devs[DEV_TT] = z8ipage.findev ("TT", NULL, NULL, false);
        devs[DEV_FP] = z8ipage.findev ("FP", NULL, NULL, false);
    }

    bool setmode = false;
    bool testmode = false;
    int ngotvals = 0;
    Tcl_Obj *gotvals[objc];

    for (int i = 0; ++ i < objc;) {
        char const *name = Tcl_GetString (objv[i]);

        if (strcasecmp (name, "get") == 0) {
            setmode = false;
            testmode = false;
            continue;
        }
        if (strcasecmp (name, "set") == 0) {
            setmode = true;
            testmode = false;
            continue;
        }
        if (strcasecmp (name, "test") == 0) {
            setmode = false;
            testmode = true;
            continue;
        }

        bool writeable;
        int width;
        uint32_t mask;
        Z8IU32 *ptr;

        // signalname
        {
            PinDef const *pte;
            for (pte = pindefs; pte->name[0] != 0; pte ++) {
                if (strcasecmp (pte->name, name) == 0) goto gotit;
            }
            if (! testmode) {
                Tcl_SetResultF (interp, "bad pin name %s", name);
                return TCL_ERROR;
            }
            gotvals[ngotvals++] = Tcl_NewIntObj (-1);
            continue;
        gotit:;
            mask = pte->mask;
            width = 32;
            if (mask != 0xFFFFFFFFU) {
                width = 0;
                while (1U << ++ width <= mask / (mask & - mask)) { }
            }
            ptr = devs[pte->dev] + pte->reg;
            writeable = pte->writ;
        }
        if (testmode) {
            gotvals[ngotvals++] = Tcl_NewIntObj (writeable);
            continue;
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
            if ((width < 32) && ((val < 0) || ((uint32_t) val >= 1ULL << width))) {
                Tcl_SetResultF (interp, "value 0%o too big for %s", val, name);
                return TCL_ERROR;
            }
            *ptr = (*ptr & ~ mask) | val * (mask & - mask);
        } else {
            uint32_t val = (*ptr & mask) / (mask & - mask);
            gotvals[ngotvals++] = Tcl_NewIntObj (val);
        }
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
