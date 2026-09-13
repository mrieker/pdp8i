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

// Print instruction trace

#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "disassemble.h"
#include "z8idefs.h"
#include "z8iutil.h"

static char const *const msnames[16] = { MS_NAMES };

static bool volatile ctrlcflag;

static void siginthand (int signum);

int main (int argc, char **argv)
{
    setlinebuf (stdout);

    if (signal (SIGINT,  siginthand) == SIG_ERR) ABORT ();
    if (signal (SIGQUIT, siginthand) == SIG_ERR) ABORT ();
    if (signal (SIGTERM, siginthand) == SIG_ERR) ABORT ();

    // access 4K register page
    Z8IU32 *pdpat = z8ipage.findev ("8I", NULL, NULL, false);
    Z8IU32 *shat  = z8ipage.findev ("SH", NULL, NULL, false);

    // switch to manual clocking
    uint32_t saveclkratm1 = EXT (pdpat[Z_RD], d_clkratm1);
    if (saveclkratm1 == 0) {
        fprintf (stderr, "clkratm1 is 0 (manual), set to 9 or so then restart\n");
        return 1;
    }
    printf ("clock rate %u0nS\n", saveclkratm1 + 1);
    pdpat[Z_RD] &= ~ d_clkratm1;                // turn off 10MHz clock

    // loop until ctrl-C
    uint32_t ts1step = 9;
    uint32_t ts2step = 9;
    bool errorprintd = false;
    bool haltprinted = false;
    while (! ctrlcflag) {

        // check for shadow freeze
        // if set, don't clock and wait for user to reset
        uint32_t sh1 = shat[1];
        if ((sh1 & sh1_err) && (sh1 & sh1_frzonerr)) {
            if (! errorprintd) {
                printf ("<<shadow freeze %08X>>\n", EXT (sh1, sh1_err));
                errorprintd = true;
                haltprinted = false;
            }
            usleep (12345);
            continue;
        }
        errorprintd = false;

        // clock processor through a 100nS cycle
        // assume clock has been low for at least 50nS
        uint32_t rd = pdpat[Z_RD];
        pdpat[Z_RD] = rd |   d_arm_iCLOCK;      // drive clock high
        ASSERT (h_100MHz == 0xFFFFFFFFU);
        uint32_t old100 = pdpat[Z_RH];          // wait at least 50nS
        while (pdpat[Z_RH] - old100 <= (saveclkratm1 + 1) / 2) { }
        pdpat[Z_RD] = rd & ~ d_arm_iCLOCK;      // drive clock low
        old100 = pdpat[Z_RH];                   // wait at least 50nS
        while (pdpat[Z_RH] - old100 <= (saveclkratm1 + 2) / 2) { }

        // read bus signals
        uint32_t re = pdpat[Z_RE];
        uint32_t rf = pdpat[Z_RF];

        // suppress output while halted
        if (rf & f_oRUN) {
            haltprinted = false;

            // print cycle information
            uint32_t majst = EXT (rf, f_oMAJST);
            uint32_t link  = EXT (rf, f_oLINK);
            uint32_t acum  = EXT (rf, f_oACUM);
            uint32_t madr  = EXT (re, e_oMADX);
            uint32_t mbuf  = EXT (re, e_oMBUF);
            printf ("TS=%c%c%c%c%c%c%c%c MS=%X L.AC=%o.%04o MA=%05o MB=%04o",
                EXT (rf, f_oTP1) ? '>' : ' ', EXT (rf, f_oTS1) ? '1' : ' ',
                EXT (rf, f_oTP2) ? '>' : ' ', EXT (rf, f_oTS2) ? '2' : ' ',
                EXT (rf, f_oTP3) ? '>' : ' ', EXT (rf, f_oTS3) ? '3' : ' ',
                EXT (rf, f_oTP4) ? '>' : ' ', EXT (rf, f_oTS4) ? '4' : ' ',
                majst,
                link,
                acum,
                madr,
                mbuf);

            ts1step = EXT (rf, f_oTS1) ? ts1step + 1 : 0;
            ts2step = EXT (rf, f_oTS2) ? ts2step + 1 : 0;
            if  (ts1step == 1) printf ("  %s", msnames[majst]);
            if ((ts2step == 1) && (majst == MS_FETCH)) {
                std::string dis = disassemble (mbuf, madr & 07777);
                printf ("    %05o: %s", madr, dis.c_str ());
            }
            putchar ('\n');
        } else if (! haltprinted) {
            printf ("<<halted>>\n");
            haltprinted = true;
        }
    }

    printf ("restoring clock\n");
    pdpat[Z_RD] |= INS (saveclkratm1, d_clkratm1);  // restore 10MHz clock

    return 0;
}

static void siginthand (int signum)
{
    if (ctrlcflag) exit (1);
    ctrlcflag = true;
    if ((signum == SIGINT) && (isatty (0) > 0)) {
        write (0, "\n", 1);
    }
}
