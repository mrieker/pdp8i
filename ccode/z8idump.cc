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
#include "shaderr.h"
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

static void dump_fp (uint32_t const *fpat);
static void dump_pb (uint32_t const *pbat);
static void dump_sh (uint32_t const *shat);

static void siginthand (int signum)
{
    exitflag = true;
}

int main (int argc, char **argv)
{
    setvbuf (stdout, stdoutbuf, _IOFBF, sizeof stdoutbuf);

    bool oncemode = false;
    bool pagemode = false;
    int fps = 20;
    for (int i = 0; ++ i < argc;) {
        if (strcmp (argv[i], "-?") == 0) {
            puts ("");
            puts ("     Dump ZTurn FPGA state");
            puts ("     Does not alter the state");
            puts ("");
            puts ("  ./z8idump.armv7l [-fps <num> | -once | -page]");
            puts ("      -fps : this many frames per second 1..1000 (default 20)");
            puts ("     -once : just print the state once, else update continually");
            puts ("     -page : just dump the raw page then exit");
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
        i2czlib.readpads (&pads, false);

        if (! oncemode) printf (ESC_HOMEC);

        char const *mode = FLD(Z_RE,e_simit) ? "SIM" : "REAL";
        uint32_t timepulse = FLD(Z_RF,f_oTP1) * 01000 | FLD(Z_RF,f_oTP2) * 00200 | FLD(Z_RF,f_oTP3) * 00030 | FLD(Z_RF,f_oTP4) * 00004;
        uint32_t timestate = FLD(Z_RF,f_oTS1) * 01000 | FLD(Z_RF,f_oTS2) * 00200 | FLD(Z_RF,f_oTS3) * 00030 | FLD(Z_RF,f_oTS4) * 00004;

        uint32_t msbin = pads.light.ms;
        ASSERT (msbin < sizeof msstrs / sizeof msstrs[0]);
        char const *msstr = msstrs[msbin];
        uint32_t irbin = pads.light.ir;
        ASSERT (irbin < sizeof irstrs / sizeof irstrs[0]);
        char const *irstr = irstrs[irbin];
        uint32_t clkratm1 = FLD(Z_RD,d_clkratm1);
        char clkratstr[10];
        if (clkratm1 == 0) strcpy (clkratstr, "manual");
        else snprintf (clkratstr, sizeof clkratstr, "%u0 nS", clkratm1 + 1);

        char ioenabd = FLD(Z_RC,c_dev_ioenabd) ? ' ' : '?';
        char dmagntd = FLD(Z_RC,c_dev_dmagntd) ? ' ' : '?';
        char poweron = FLD(Z_RC,c_dev_poweron) ? ' ' : '?';

        // zynq.v register dump
        printf ("VERSION=%08X %c%c  %s%s", z8is[0], (char)(z8is[0] >> 24), (char)(z8is[0] >> 16), mode, eol);
        printf ("  oACUM=%04o    iACCLEAR=%o%c     lbAC=%04o    swCONT=%o     armintena=%08X%s",   FLD(Z_RF,f_oACUM),    FLD(Z_RC,c_dev_iACCLEAR), ioenabd, pads.light.ac,   pads.button.cont,      z8is[ZG_INTENABS],     eol);
        printf ("  oBRKCYC=%o     iBRKGNTO=%o%c     lbMA=%04o    swDEPOS=%o    armintreq=%08X%s",  FLD(Z_RF,f_oBRKCYC),  FLD(Z_RC,c_dev_iBRKGNTO), poweron, pads.light.ma,   pads.button.depos,     z8is[ZG_INTFLAGS],     eol);
        printf ("  oBRKGNTI=%o    iBRKRQST=%o%c     lbSC=%02o      swDFLD=%o%s",                   FLD(Z_RF,f_oBRKGNTI), FLD(Z_RC,c_dev_iBRKRQST), poweron, pads.light.sc,   pads.togval.dfld,      eol);
        printf ("  oBRKRQST=%o    iBRKWRM=%o%c      lbION=%o      swEXAM=%o     memcycctr=%08X%s", FLD(Z_RF,f_oBRKRQST), FLD(Z_RC,c_dev_iBRKWRM),  dmagntd, pads.light.ion,  pads.button.exam,      FLD(Z_RN,n_memcycctr), eol);
        printf ("  oBUSINI=%o     iCAINC=%o%c       lbLINK=%o     swIFLD=%o      10MHzctr=%08X%s", FLD(Z_RF,f_oBUSINI),  FLD(Z_RC,c_dev_iCAINC),   dmagntd, pads.light.link, pads.togval.ifld,      FLD(Z_RK,k_10MHz),     eol);
        printf ("  oBWCOV=%o      iCYCLE3=%o%c      lbPAU=%o      swLDAD=%o     100MHzctr=%08X%s", FLD(Z_RF,f_oBWCOV),   FLD(Z_RC,c_dev_iCYCLE3),  dmagntd, pads.light.pau,  pads.button.ldad,      FLD(Z_RH,h_100MHz),    eol);
        printf ("  oIOP=%o        iDMAFLD=%o%c      lbMB=%04o    swSINST=%o %s",                   FLD(Z_RF,f_oIOP),     FLD(Z_RC,c_dev_iDMAFLD),  dmagntd, pads.light.mb,   pads.togval.sinst,     eol);
        printf ("  oLINK=%o       iINBUS=%04o%c    lbMQ=%04o    swSSTEP=%o     ilaarmed=%o%s",     FLD(Z_RF,f_oLINK),    FLD(Z_RC,c_dev_iINBUS),   ioenabd, pads.light.mq,   pads.togval.sstep,     FLD(Z_RQ,q_ilaarmed),  eol);
        printf ("  oMADR=%05o   iINTRQST=%o%c     lbMS=%-5s   swSTART=%o     ilaafter=%04o%s",     FLD(Z_RE,e_oMADX),    FLD(Z_RC,c_dev_iINTRQST), poweron, msstr,           pads.button.start,     FLD(Z_RQ,q_ilaafter),  eol);
        printf ("  oMBUF=%04o    iIOSKIP=%o%c      lbIR=%s     swREG=%04o    ilaindex=%04o%s",     FLD(Z_RE,e_oMBUF),    FLD(Z_RC,c_dev_iIOSKIP),  ioenabd, irstr,           pads.togval.reg,       FLD(Z_RQ,q_ilaindex),  eol);
        printf ("  oRUN=%o        iPAUSE=%o%c       lbRUN=%o%s",                                   FLD(Z_RF,f_oRUN),     FLD(Z_RC,c_dev_iPAUSE),   poweron, pads.light.run,  eol);
        printf ("  oTP=%04o      iCLOCK=%o%c       lbPC=%04o    clkratm1=%-2u(%s)%s",              timepulse,            FLD(Z_RC,c_dev_iCLOCK),   poweron, pads.light.pc,   clkratm1, clkratstr,   eol);
        printf ("  oTS=%04o      iRESET=%o%c       lbDF=%o       fpgamemen=%o%s",                  timestate,            FLD(Z_RC,c_dev_iRESET),   poweron, pads.light.dfld, FLD(Z_RE,e_fpgamemen), eol);
        printf ("  oMAJST=%X      iMEMDIS=%o%c      lbIF=%o%s",                                    FLD(Z_RF,f_oMAJST),   FLD(Z_RC,c_dev_iMEMDIS),  poweron, pads.light.ifld, eol);

        for (int i = 0; i < pagelen;) {
            uint32_t idver = z8is[i];
            if (idver == 0xDEADBEEF) {
                pagelen = i;
                if (oncemode) printf ("\npagelen=%d\n", pagelen);
                break;
            }
            if (((idver >> 24) == 'F') && (((idver >> 16) & 255) == 'P')) {
                dump_fp (&z8is[i]);
            } else if (((idver >> 24) == 'P') && (((idver >> 16) & 255) == 'B')) {
                dump_pb (&z8is[i]);
            } else if (((idver >> 24) == 'S') && (((idver >> 16) & 255) == 'H')) {
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

// pdp8ifpi2c.v - front panel via i2c
static void dump_fp (uint32_t const *fpat)
{
    uint32_t fp1  = fpat[1];
    uint32_t fp2  = fpat[2];
    uint32_t fp3  = fpat[3];
    uint32_t fp4  = fpat[4];
    uint32_t fp5  = fpat[5];
    uint32_t fp6  = fpat[6];
    uint32_t fp7  = fpat[7];
//  uint32_t fp8  = fpat[8];
//  uint32_t fp9  = fpat[9];
//  uint32_t fp10 = fpat[10];
    uint32_t fp11 = fpat[11];
    uint32_t fp12 = fpat[12];
    uint32_t fp13 = fpat[13];

    printf ("%sVERSION=%08X FP i2ccmd=%08X%08X i2csts=%08X%08X i2cstate=%o i2ccount=%05u i2cspeed=%04u%s",
        eol, fpat[0], EXT(fp2,FP2_CMDHI), EXT(fp1,FP1_CMDLO), EXT(fp4,FP4_STSHI), EXT(fp3,FP3_STSLO), EXT(fp5,FP5_I2CSTATE), EXT(fp5,FP5_I2CCOUNT), EXT(fp13,fp13_i2cspeed), eol);

    printf ("                    mcppassno=%06X mcpltrow=%o mcpswrow=%o mcpstate=%02u  dbncount=%02u dbnlimit=%02u  lock=%08X%s",
        EXT(fp7,fp7_mcpassno), EXT(fp7,fp7_mcpltrow), EXT(fp7,fp7_mcpswrow), EXT(fp7,fp7_mcpstate), EXT(fp12,fp12_dbncount), EXT(fp13,fp13_dbnlimit), EXT(fp6,FP6_LOCK), eol);

    printf ("                    position start=%o ldad=%o depos=%o exam=%o cont=%o stop=%o sstep=%o sinst=%o dfld=%o ifld=%o reg=%04o%s",
        EXT(fp11,fp11_swSTART), EXT(fp11,fp11_swLDAD), EXT(fp11,fp11_swDEPOS), EXT(fp11,fp11_swEXAM), EXT(fp11,fp11_swCONT), EXT(fp11,fp11_swSTOP), EXT(fp11,fp11_swSSTEP), EXT(fp11,fp11_swSINST), EXT(fp11,fp11_swDFLD), EXT(fp11,fp11_swIFLD), EXT(fp11,fp11_swREG), eol);

    printf ("                    override start=%o ldad=%o depos=%o exam=%o cont=%o stop=%o sstep=%o sinst=%o dfld=%o ifld=%o reg=%04o%s",
        EXT(fp12,fp11_swSTART), EXT(fp12,fp11_swLDAD), EXT(fp12,fp11_swDEPOS), EXT(fp12,fp11_swEXAM), EXT(fp12,fp11_swCONT), EXT(fp12,fp11_swSTOP), EXT(fp12,fp11_swSSTEP), EXT(fp12,fp11_swSINST), EXT(fp12,fp11_swDFLD), EXT(fp12,fp11_swIFLD), EXT(fp12,fp11_swREG), eol);
}

// pdp8ipbit.v - pulse-bit audio
static void dump_pb (uint32_t const *pbat)
{
    uint32_t idver = pbat[0];
    printf ("%sVERSION=%08X %c%c %08X %08X %08X %08X %08X %08X %08X %5uHz%s", eol, idver, idver >> 24, idver >> 16,
            pbat[1], pbat[2], pbat[3], pbat[4], pbat[5], pbat[6], pbat[7], pbat[5] >> 16, eol);
}

// pdp8ishad.v - processor shadowing
static void dump_sh (uint32_t const *shat)
{
    static char const *const msstr[] = { "---", "FET", "DEF", "EXE", "WCT", "CAD", "BRK", "IAK",
                                         "DEP", "EXM", "10 ", "11 ", "12 ", "13 ", "14 ", "15 " };

    uint32_t sh1 = shat[1];
    uint32_t sh2 = shat[2];
    uint32_t sh3 = shat[3];
    uint32_t sh4 = shat[4];
    uint32_t sh5 = shat[5];
    uint32_t sh6 = shat[6];

    char mastr[8], pcstr[8], tp1datstr[8];
    sprintf (mastr, "%04o", EXT (sh3, sh3_madr));
    sprintf (pcstr, "%04o", EXT (sh2, sh2_pctr));
    sprintf (tp1datstr, "%04o", EXT (sh6, sh6_tp1dat));

    printf ("%sVERSION=%08X SH "
        "foe=%o "
        "clr=%o "
        "err=%08X.%02X "
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
        EXT (sh1, sh1_err1), EXT (sh6, sh6_err2),
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
        "mbrd=%04o "
        "mbwr=%04o "
        "tp1dat=%s"
        "%s",
        EXT (sh3, sh3_mbrd),
        EXT (sh4, sh4_mbwr),
        EXT (sh3, sh3_tp1datval) ? tp1datstr : "????",
        eol);

    char sep[8];
    snprintf (sep, sizeof sep, "%s  ", eol);
    std::string err;
    shaderr (&err, sep);
    if (err.length () > 0) {
        printf ("  %s%s", err.c_str (), eol);
    }
}
