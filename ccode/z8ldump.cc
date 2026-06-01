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

// Runs PIPan8L on a Zynq board programmed with 8/L emulation code
// It does not write to the zynq memory pages so does not alter zynq state

//  ./z8ldump.armv7l [-once | -step] [-xmem <lo>..<hi>]...

#include <alloca.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "i2czlib.h"
#include "z8ldefs.h"
#include "z8lutil.h"

#define FLD(idx,msk) EXT(z8ls[idx],msk)

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

static char const *const majstatenames[] = { MS_NAMES };

static bool volatile exitflag;
static char stdoutbuf[8000];

static void siginthand (int signum)
{
    exitflag = true;
}

int main (int argc, char **argv)
{
    setvbuf (stdout, stdoutbuf, _IOFBF, sizeof stdoutbuf);

    bool oncemode = false;
    bool pagemode = false;
    bool stepmode = false;
    char const *eol = EOL;
    int fps = 20;
    for (int i = 0; ++ i < argc;) {
        if (strcmp (argv[i], "-?") == 0) {
            puts ("");
            puts ("     Dump ZTurn FPGA state");
            puts ("     Does not alter the state");
            puts ("");
            puts ("  ./z8ldump.armv7l [-fps <num> | -once | -page | -step]");
            puts ("      -fps : this many frames per second 1..1000 (default 20)");
            puts ("     -once : just print the state once, else update continually");
            puts ("     -page : just dump the raw page then exit");
            puts ("     -step : prompt between updates");
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
        if (strcasecmp (argv[i], "-step") == 0) {
            stepmode = true;
            continue;
        }
        fprintf (stderr, "unknown argument %s\n", argv[i]);
        return 1;
    }

    Z8LPage z8p;
    uint32_t volatile *pdpat = z8p.findev ("8I", NULL, NULL, false);

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

    if (stepmode) {
        pdpat[Z_RE] &= ~ (e_nanocontin | e_nanotrigger);
    } else {
        signal (SIGINT, siginthand);
    }

    I2CZLib i2czlib;

    int pagelen = 1024;
    while (! exitflag) {
        usleep (1000000 / fps);

        uint32_t z8ls[1024];
        for (int i = 0; i < pagelen; i ++) {
            z8ls[i] = pdpat[i];
        }

        Z8LPanel pads;
        i2czlib.readpads (&pads);

        if (! oncemode) printf (ESC_HOMEC);

        char const *mode = FLD(Z_RE,e_simit) ? "SIM " : "REAL";
        uint32_t timepulse = (FLD(Z_RF,f_oTP1) << 9) | (FLD(Z_RF,f_oTP2) << 6) | (FLD(Z_RF,f_oTP3) << 3) | FLD(Z_RF,f_oTP4);
        uint32_t timestate = (FLD(Z_RF,f_oTS1) << 9) | (FLD(Z_RF,f_oTS2) << 6) | (FLD(Z_RF,f_oTS3) << 3) | FLD(Z_RF,f_oTS4);

        // zynq.v register dump
        printf ("VERSION=%08X %c%c%s", z8ls[0], (char)(z8ls[0] >> 24), (char)(z8ls[0] >> 16), eol);

        printf ("  oACUM=%04o    iACCLEAR=%o     lbAC=%04o    swCONT=%o  %s", FLD(Z_RF,f_oACUM),    FLD(Z_RC,c_dev_iACCLEAR), pads.light.ac,   pads.button.cont,  eol);
        printf ("  oBRKCYC=%o     iBRKGNTO=%o     lbMA=%04o    swDEPOS=%o %s", FLD(Z_RF,f_oBRKCYC),  FLD(Z_RC,c_dev_iBRKGNTO), pads.light.ma,   pads.button.dep,   eol);
        printf ("  oBRKGNTI=%o    iBRKRQST=%o     lbSC=%02o      swDFLD=%o  %s", FLD(Z_RF,f_oBRKGNTI), FLD(Z_RC,c_dev_iBRKRQST), pads.light.sc,   pads.togval.dfld,  eol);
        printf ("  oBRKRQST=%o    iBRKWRM=%o      lbION=%o      swEXAM=%o  %s", FLD(Z_RF,f_oBRKRQST), FLD(Z_RC,c_dev_iBRKWRM),  pads.light.ion,  pads.button.exam,  eol);
        printf ("  oBUSINI=%o     iCAINC=%o       lbLINK=%o     swIFLD=%o  %s", FLD(Z_RF,f_oBUSINI),  FLD(Z_RC,c_dev_iCAINC),   pads.light.link, pads.togval.ifld,  eol);
        printf ("  oBWCOV=%o      iCYCLE3=%o      lbPAU=%o      swLDAD=%o  %s", FLD(Z_RF,f_oBWCOV),   FLD(Z_RC,c_dev_iCYCLE3),  pads.light.pau,  pads.button.ldad,  eol);
        printf ("  oCLOCK=%o      iDMAFLD=%o      lbMB=%04o    swSINST=%o %s", FLD(Z_RF,f_oCLOCK),   FLD(Z_RC,c_dev_iDMAFLD),  pads.light.mb,   pads.togval.sinst, eol);
        printf ("  oIOP=%o        iINBUS=%04o    lbMQ=%04o    swSSTEP=%o %s", FLD(Z_RF,f_oIOP),     FLD(Z_RC,c_dev_iINBUS),   pads.light.mq,   pads.togval.sstep, eol);
        printf ("  oMBUF=%04o    iINTRQST=%o     lbMS=%X       swSTART=%o %s", FLD(Z_RE,e_oMBUF),    FLD(Z_RC,c_dev_iINTRQST), pads.light.ms,   pads.button.start, eol);
        printf ("  oRESET=%o      iIOSKIP=%o      lbIR=%o       swSR=%04o  %s", FLD(Z_RF,f_oRESET),   FLD(Z_RC,c_dev_iIOSKIP),  pads.light.ir,   pads.togval.sr,    eol);
        printf ("  oTP=%04o      iPAUSE=%o       lbRUN=%o                %s", timepulse,            FLD(Z_RC,c_dev_iPAUSE),   pads.light.run,                     eol);
        printf ("  oTS=%04o                     lbPC=%04o               %s", timestate,                                      pads.light.pc,                      eol);
        printf ("                               lbDF=%o                 %s",                                                 pads.light.dfld,                    eol);
        printf ("  %s                         lbEA=%o                 %s", mode,                                           pads.light.ema,                     eol);
        printf ("                               lbIF=%o                 %s",                                                 pads.light.ifld,                    eol);

        for (int i = 0; i < 1024;) {
            uint32_t idver = z8ls[i];
            if (((idver >> 24) == 'X') && (((idver >> 16) & 255) == 'M')) {
                printf ("%sVERSION=%08X XM  enlo4k=%o  enable=%o  ifld=%o  dfld=%o  field=%o  _mwdone=%o  _mrdone=%o  os8zap=%o,step=%o%s",
                    eol,
                    idver, EXT (i+1,XM_ENLO4K), EXT (i+1,XM_ENABLE), EXT (i+2,XM2_IFLD), EXT (i+2,XM2_DFLD), EXT (i+2,XM2_FIELD),
                    EXT (i+2,XM2__MWDONE), EXT (i+2,XM2__MRDONE), EXT (i+1,XM_OS8ZAP), EXT (i+3,XM3_OS8STEP), eol);
                printf ("        mrhold,step=%o,%o  mwhold,step=%o,%o  xmstate=%2u  xmmemenab=%o  memcycctr=%08X.%08X%s",
                    FLD(i+1,XM_MRHOLD), FLD(i+1,XM_MRSTEP), FLD(i+1,XM_MWHOLD), FLD(i+1,XM_MWSTEP), FLD(i+2,XM2_XMSTATE),
                    FLD(i+2,XM2_XMMEMENAB), FLD(i+7,0xFFFFFFFFU), FLD(i+6,0xFFFFFFFFU), eol);
                printf ("        addrlatchwid=%u  readstrobedel=%u  readstrobewid=%u  writeenabdel=%u  writeenabwid=%u  writedonewid=%u%s",
                    FLD(i+4,XM4_ADDRLATCHWID), FLD(i+4,XM4_READSTROBEDEL), FLD(i+4,XM4_READSTROBEWID), FLD(i+4,XM4_WRITEENABDEL),
                    FLD(i+5,XM5_WRITEENABWID), FLD(i+5,XM5_WRITEDONEWID), eol);
            } else if (((idver >> 24) == 'S') && (((idver >> 16) & 255) == 'H')) {
                char *shst = formatshadow (&z8ls[i]);
                printf ("%sVERSION=%08X SH %s%s", eol, idver, shst, eol);
                free (shst);
            } else {
                if ((idver & 0xF000U) == 0x0000U) {
                    printf ("%sVERSION=%08X %c%c %08X%s", eol, idver, idver >> 24, idver >> 16, z8ls[i+1], eol);
                }
                if ((idver & 0xF000U) == 0x1000U) {
                    printf ("%sVERSION=%08X %c%c %08X %08X %08X%s", eol, idver, idver >> 24, idver >> 16, z8ls[i+1], z8ls[i+2], z8ls[i+3], eol);
                }
                if ((idver & 0xF000U) == 0x2000U) {
                    printf ("%sVERSION=%08X %c%c %08X %08X %08X %08X %08X %08X %08X%s", eol, idver, idver >> 24, idver >> 16,
                        z8ls[i+1], z8ls[i+2], z8ls[i+3], z8ls[i+4], z8ls[i+5], z8ls[i+6], z8ls[i+7], eol);
                }
                if ((idver & 0xF000U) == 0x3000U) {
                    printf ("%sVERSION=%08X %c%c %08X %08X %08X %08X %08X %08X %08X%s", eol, idver, idver >> 24, idver >> 16,
                        z8ls[i+1], z8ls[i+2], z8ls[i+3], z8ls[i+4], z8ls[i+5], z8ls[i+6], z8ls[i+7], eol);
                    printf ("           %08X %08X %08X %08X %08X %08X %08X %08X%s",
                        z8ls[i+8], z8ls[i+9], z8ls[i+10], z8ls[i+11], z8ls[i+12], z8ls[i+13], z8ls[i+14], z8ls[i+15], eol);
                }
            }
            i += 2 << ((idver >> 12) & 15);
        }

        if (oncemode) break;

        printf (EOP);
        fflush (stdout);

        if (stepmode) {
            char temp[8];
            printf ("\n > ");
            fflush (stdout);
            if (fgets (temp, sizeof temp, stdin) == NULL) break;
            pdpat[Z_RE] |= e_nanotrigger;
        }
    }
    printf ("\n");
    return 0;
}
