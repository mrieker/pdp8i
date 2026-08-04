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

// Dumps 4K zynq register page
// Reads do not have any side-effects, so this program can run at any time

#include <alloca.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "i2czlib.h"
#include "z8idefs.h"
#include "z8iutil.h"

#define FLD(idx,msk) EXT(z8is[idx],msk)

#define ESC_NORMV "\033[m"          // go back to normal video
#define ESC_REVER "\033[7m"         // turn reverse video on
#define ESC_UNDER "\033[4m"         // turn underlining on
#define ESC_BLINK "\033[5m"         // turn blink on
#define ESC_BOLDV "\033[1m"         // turn bold on
#define ESC_REDBG "\033[41m"        // red background
#define ESC_YELBG "\033[44m"        // yellow background
#define ESC_EREOL "\033[K"          // erase to end of line
#define ESC_EREOP "\033[J"          // erase to end of page
#define ESC_HOMEC "\033[H"          // home cursor

#define EOL ESC_EREOL "\n"
#define EOP ESC_EREOP

static char const *const irstrs[] = { "AND", "TAD", "ISZ", "DCA", "JMS", "JMP", "IOT", "OPR" };
static char const *const msstrs[] = { MS_NAMES };

static bool volatile exitflag;
static char const *eol = EOL;
static char stdoutbuf[8000];

static void dump_sh (uint32_t const *shat);

static void siginthand (int signum)
{
    exitflag = true;
}

int main (int argc, char **argv)
{
    setvbuf (stdout, stdoutbuf, _IOFBF, sizeof stdoutbuf);

    bool enabpads = true;
    bool oncemode = false;
    bool pagemode = false;
    int fps = 20;
    for (int i = 0; ++ i < argc;) {
        if (strcmp (argv[i], "-?") == 0) {
            puts ("");
            puts ("     Dump ZTurn FPGA state");
            puts ("     Does not alter the state");
            puts ("");
            puts ("  ./z8idump.armv7l [-fps <num> | -once | -page] [-nopads]");
            puts ("      -fps : this many frames per second 1..1000 (default 20)");
            puts ("     -once : just print the state once, else update continually");
            puts ("     -page : just dump the raw page then exit");
            puts ("   -nopads : disable using i2c bus for lights/switches");
            puts ("");
            return 0;
        }
        if (strcasecmp (argv[i], "-fps") == 0) {
            if ((++ i >= argc) || (argv[i][0] == '-')) {
                fprintf (stderr, "missing <num> for -fps option\n");
                return 1;
            }
            char *p;
            fps = strtol (argv[i], &p, 0);
            if ((*p != 0) || (fps <= 0) || (fps > 1000)) {
                fprintf (stderr, "number frames per second %s must be integer 1..1000\n", argv[i]);
                return 1;
            }
            continue;
        }
        if (strcasecmp (argv[i], "-once") == 0) {
            eol = "\n";
            oncemode = true;
            continue;
        }
        if (strcasecmp (argv[i], "-nopads") == 0) {
            enabpads = false;
            continue;
        }
        if (strcasecmp (argv[i], "-page") == 0) {
            pagemode = true;
            continue;
        }
        fprintf (stderr, "unknown argument %s\n", argv[i]);
        return 1;
    }

    Z8IU32 *pdpat = z8ipage.findev ("8I", NULL, NULL, false);

    // maybe just dump the page and exit
    if (pagemode) {
        uint32_t words[1024];
        for (int i = 0; i < 1024; i ++) words[i] = pdpat[i];
        int k;
        for (k = 1024; words[--k] == 0xDEADBEEF;) { }
        for (int i = 0; i <= k; i += 8) {
            printf ("%03X:", i);
            for (int j = 0; j < 8; j ++) {
                printf (" %08X", words[i+j]);
            }
            printf ("\n");
        }
        return 0;
    }

    signal (SIGINT, siginthand);

    I2CZLib i2czlib;

    int pagelen = 1024;
    while (! exitflag) {
        usleep (1000000 / fps);

        uint32_t z8is[1024];
        for (int i = 0; i < pagelen; i ++) {
            z8is[i] = pdpat[i];
        }

        Z8IPanel pads;
        if (enabpads) {
            i2czlib.readpads (&pads);
        } else {
            memset (&pads, 0, sizeof pads);
        }

        if (! oncemode) printf (ESC_HOMEC);

        char const *mode = FLD(Z_RE,e_simit) ? "SIM" : "REAL";
        uint32_t timepulse = FLD(Z_RF,f_oTP1) * 01000 | FLD(Z_RF,f_oTP2) * 00200 | FLD(Z_RF,f_oTP3) * 00030 | FLD(Z_RF,f_oTP4) * 00004;
        uint32_t timestate = FLD(Z_RF,f_oTS1) * 01000 | FLD(Z_RF,f_oTS2) * 00200 | FLD(Z_RF,f_oTS3) * 00030 | FLD(Z_RF,f_oTS4) * 00004;

        uint32_t msbin = pads.light.ms;
        ASSERT (msbin < sizeof msstrs / sizeof msstrs[0]);
        char const *msstr = enabpads ? msstrs[msbin] : "-----";
        uint32_t irbin = pads.light.ir;
        ASSERT (irbin < sizeof irstrs / sizeof irstrs[0]);
        char const *irstr = enabpads ? irstrs[irbin] : "---";
        uint32_t clkratm1 = FLD(Z_RD,d_clkratm1);
        char clkratstr[10];
        if (clkratm1 == 0) strcpy (clkratstr, "manual");
        else snprintf (clkratstr, sizeof clkratstr, "%u0 nS", clkratm1 + 1);

        char ioenabd = FLD(Z_RC,c_dev_ioenabd) ? ' ' : '?';
        char dmagntd = FLD(Z_RC,c_dev_dmagntd) ? ' ' : '?';
        char poweron = FLD(Z_RC,c_dev_poweron) ? ' ' : '?';

        // zynq.v register dump
        printf ("VERSION=%08X %c%c  %s%s", z8is[0], (char)(z8is[0] >> 24), (char)(z8is[0] >> 16), mode, eol);
        printf ("  oACUM=%04o    iACCLEAR=%o%c     lbAC=%04o    swCONT=%o     armintena=%08X%s",       FLD(Z_RF,f_oACUM),    FLD(Z_RC,c_dev_iACCLEAR), ioenabd, pads.light.ac,   pads.button.cont,  z8is[ZG_INTENABS], eol);
        printf ("  oBRKCYC=%o     iBRKGNTO=%o%c     lbMA=%04o    swDEPOS=%o    armintreq=%08X%s",     FLD(Z_RF,f_oBRKCYC),  FLD(Z_RC,c_dev_iBRKGNTO), poweron, pads.light.ma,   pads.button.depos, z8is[ZG_INTFLAGS], eol);
        printf ("  oBRKGNTI=%o    iBRKRQST=%o%c     lbSC=%02o      swDFLD=%o  %s",   FLD(Z_RF,f_oBRKGNTI), FLD(Z_RC,c_dev_iBRKRQST), poweron, pads.light.sc,   pads.togval.dfld,      eol);
        printf ("  oBRKRQST=%o    iBRKWRM=%o%c      lbION=%o      swEXAM=%o  %s",    FLD(Z_RF,f_oBRKRQST), FLD(Z_RC,c_dev_iBRKWRM),  dmagntd, pads.light.ion,  pads.button.exam,      eol);
        printf ("  oBUSINI=%o     iCAINC=%o%c       lbLINK=%o     swIFLD=%o  %s",    FLD(Z_RF,f_oBUSINI),  FLD(Z_RC,c_dev_iCAINC),   dmagntd, pads.light.link, pads.togval.ifld,      eol);
        printf ("  oBWCOV=%o      iCYCLE3=%o%c      lbPAU=%o      swLDAD=%o  %s",    FLD(Z_RF,f_oBWCOV),   FLD(Z_RC,c_dev_iCYCLE3),  dmagntd, pads.light.pau,  pads.button.ldad,      eol);
        printf ("  oIOP=%o        iDMAFLD=%o%c      lbMB=%04o    swSINST=%o %s",     FLD(Z_RF,f_oIOP),     FLD(Z_RC,c_dev_iDMAFLD),  dmagntd, pads.light.mb,   pads.togval.sinst,     eol);
        printf ("  oLINK=%o       iINBUS=%04o%c    lbMQ=%04o    swSSTEP=%o %s",      FLD(Z_RF,f_oLINK),    FLD(Z_RC,c_dev_iINBUS),   ioenabd, pads.light.mq,   pads.togval.sstep,     eol);
        printf ("  oMADR=%05o   iINTRQST=%o%c     lbMS=%-5s   swSTART=%o %s",        FLD(Z_RE,e_oMADX),    FLD(Z_RC,c_dev_iINTRQST), poweron, msstr,           pads.button.start,     eol);
        printf ("  oMBUF=%04o    iIOSKIP=%o%c      lbIR=%s     swREG=%04o %s",       FLD(Z_RE,e_oMBUF),    FLD(Z_RC,c_dev_iIOSKIP),  ioenabd, irstr,           pads.togval.reg,       eol);
        printf ("  oRUN=%o        iPAUSE=%o%c       lbRUN=%o                %s",     FLD(Z_RF,f_oRUN),     FLD(Z_RC,c_dev_iPAUSE),   poweron, pads.light.run,                         eol);
        printf ("  oTP=%04o      iCLOCK=%o%c       lbPC=%04o    fpgamemen=%o%s",     timepulse,            FLD(Z_RC,c_dev_iCLOCK),   poweron, pads.light.pc,   FLD(Z_RE,e_fpgamemen), eol);
        printf ("  oTS=%04o      iRESET=%o%c       lbDF=%o       clkratm1=%-2u(%s)%s", timestate,          FLD(Z_RC,c_dev_iRESET),   poweron, pads.light.dfld, clkratm1, clkratstr,   eol);
        printf ("  oMAJST=%X      iMEMDIS=%o%c      lbEA=%o       memcycctr=%08X%s", FLD(Z_RF,f_oMAJST),   FLD(Z_RC,c_dev_iMEMDIS),  poweron, pads.light.ema,  FLD(Z_RN,n_memcycctr), eol);
        printf ("                                lbIF=%o       100MHzctr=%08X%s",                                                    pads.light.ifld,          FLD(Z_RH,h_100MHz),    eol);

        for (int i = 0; i < pagelen;) {
            uint32_t idver = z8is[i];
            if (idver == 0xDEADBEEF) {
                pagelen = i;
                if (oncemode) printf ("\npagelen=%d\n", pagelen);
                break;
            }
            if (((idver >> 24) == 'S') && (((idver >> 16) & 255) == 'H')) {
                dump_sh (&z8is[i]);
            } else {
                if ((idver & 0xF000U) == 0x0000U) {
                    printf ("%sVERSION=%08X %c%c %08X%s", eol, idver, idver >> 24, idver >> 16, z8is[i+1], eol);
                }
                if ((idver & 0xF000U) == 0x1000U) {
                    printf ("%sVERSION=%08X %c%c %08X %08X %08X%s", eol, idver, idver >> 24, idver >> 16, z8is[i+1], z8is[i+2], z8is[i+3], eol);
                }
                if ((idver & 0xF000U) == 0x2000U) {
                    printf ("%sVERSION=%08X %c%c %08X %08X %08X %08X %08X %08X %08X%s", eol, idver, idver >> 24, idver >> 16,
                        z8is[i+1], z8is[i+2], z8is[i+3], z8is[i+4], z8is[i+5], z8is[i+6], z8is[i+7], eol);
                }
                if ((idver & 0xF000U) == 0x3000U) {
                    printf ("%sVERSION=%08X %c%c %08X %08X %08X %08X %08X %08X %08X%s", eol, idver, idver >> 24, idver >> 16,
                        z8is[i+1], z8is[i+2], z8is[i+3], z8is[i+4], z8is[i+5], z8is[i+6], z8is[i+7], eol);
                    printf ("           %08X %08X %08X %08X %08X %08X %08X %08X%s",
                        z8is[i+8], z8is[i+9], z8is[i+10], z8is[i+11], z8is[i+12], z8is[i+13], z8is[i+14], z8is[i+15], eol);
                }
            }
            i += 2 << ((idver >> 12) & 15);
        }

        if (oncemode) break;

        printf (EOP);
        fflush (stdout);
    }
    printf ("\n");
    return 0;
}

static void dump_sh (uint32_t const *shat)
{
    static char const *const msstr[] = { "---", "FET", "DEF", "EXE", "WCT", "CAD", "BRK", "IAK",
                                         "DEP", "EXM", "10 ", "11 ", "12 ", "13 ", "14 ", "15 " };

    uint32_t sh1 = shat[1];
    uint32_t sh2 = shat[2];
    uint32_t sh3 = shat[3];
    uint32_t sh4 = shat[4];
    uint32_t sh5 = shat[5];

    char mastr[8], pcstr[8];
    sprintf (mastr, "%04o", EXT (sh3, sh3_madr));
    sprintf (pcstr, "%04o", EXT (sh2, sh2_pctr));

    printf ("%sVERSION=%08X SH "
        "foe=%o "
        "clr=%o "
        "err=%08X "
        "ms=%s "
        "ts=%u "
        "ir=%04o "
        "pc=%s "
        "ma=%s "
        "%s",
        eol,
        shat[0],
        EXT (sh1, sh1_frzonerr),
        EXT (sh1, sh1_clearit),
        EXT (sh1, sh1_err),
        msstr[EXT(sh2,sh2_majst)],
        EXT (sh2, sh2_timestate),
        EXT (sh2, sh2_ireg),
        EXT (sh5, sh5_pctrkn) ? pcstr : "????",
        EXT (sh5, sh5_madrkn) ? mastr : "????",
        eol);

    printf ("                    "
        "l.ac=%o.%04o "
        "sc=%02o "
        "mq=%04o "
        "if=%c/aj=%c svif=%c "
        "df=%c svdf=%c "
        "%s",
        EXT (sh5, sh5_link),
        EXT (sh4, sh4_acum),
        EXT (sh5, sh5_sctr),
        EXT (sh5, sh5_mquo),
        EXT (sh5, sh5_ifldkn)   ? '0' + EXT (sh5, sh5_ifld)   : '?',
        EXT (sh4, sh4_ifajkn)   ? '0' + EXT (sh4, sh4_ifaj)   : '?',
        EXT (sh5, sh5_svifldkn) ? '0' + EXT (sh5, sh5_svifld) : '?',
        EXT (sh4, sh4_dfldkn)   ? '0' + EXT (sh4, sh4_dfld)   : '?',
        EXT (sh5, sh5_svdfldkn) ? '0' + EXT (sh5, sh5_svdfld) : '?',
        eol);

    printf ("                    "
        "mred=%04o "
        "mwbk=%04o "
        "%s",
        EXT (sh3, sh3_mred),
        EXT (sh4, sh4_mwbk),
        eol);
}
