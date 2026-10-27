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

// test mul36.pal

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "randbits.h"
#include "z8idefs.h"
#include "z8iutil.h"

static int testno;
static Z8IU32 *ttyat;

static bool findtt (void *param, Z8IU32 *ttyat);
static void testcase (uint64_t rand1hi, uint64_t rand1lo, uint64_t rand2hi, uint64_t rand2lo);
static char readwithecho ();
static void sendchartottykb (char ch);
static bool tt_getprchar (uint8_t *prchar_r);
static bool tt_putkbchar (uint8_t kbchar);

int main (int argc, char **argv)
{
    int port = 3;
    ttyat = z8ipage.findev ("TT", findtt, &port, true, true);
    ttyat[Z_TTYKB] = KB_ENAB;   // enable board to process io instructions

    setlinebuf (stdout);

    // systematic carry testing (444889 iterations)
    for (int iwidth = 0; iwidth <= 36; iwidth ++) {
        for (int ibit = 0; ibit + iwidth <= 36; ibit ++) {
            uint64_t ival = ((1ULL << iwidth) - 1) << ibit;
            for (int jwidth = 0; jwidth <= 36; jwidth ++) {
                for (int jbit = 0; jbit + jwidth <= 36; jbit ++) {
                    uint64_t jval = ((1ULL << jwidth) - 1) << jbit;

                    uint64_t rand1hi = ival >> 18;
                    uint64_t rand1lo = ival & 0777777;
                    uint64_t rand2hi = jval >> 18;
                    uint64_t rand2lo = jval & 0777777;
                    testcase (rand1hi, rand1lo, rand2hi, rand2lo);

                    if (jwidth == 0) break;
                }
            }
            if (iwidth == 0) break;
        }
    }

    // random test cases
    while (true) {
        uint64_t rand1hi = randbits (18);
        uint64_t rand1lo = randbits (18);
        uint64_t rand2hi = randbits (18);
        uint64_t rand2lo = randbits (18);
        testcase (rand1hi, rand1lo, rand2hi, rand2lo);
    }
}

static bool findtt (void *param, Z8IU32 *ttyat)
{
    int port = *(int *) param;
    if (ttyat == NULL) {
        fprintf (stderr, "findtt: cannot find TT port %02o\n", port);
        ABORT ();
    }
    return (ttyat[Z_TTYPN] & 077) == (uint32_t) port;
}

static void testcase (uint64_t rand1hi, uint64_t rand1lo, uint64_t rand2hi, uint64_t rand2lo)
{

    // print test number then wait for mul36.pal '>' prompt char
    printf ("%9u  ", ++ testno);
    while (readwithecho () != '>') { }

    char ch, probstr[30];
    snprintf (probstr, sizeof probstr, "%06o%06o*%06o%06o=",
        (unsigned) rand1hi, (unsigned) rand1lo, (unsigned) rand2hi, (unsigned) rand2lo);
    for (int i = 0; (ch = probstr[i]) != 0; i ++) {
        sendchartottykb (ch);
        char ec = readwithecho ();
        if (ec != ch) {
            fprintf (stderr, "char %c echoed as %c\n", ec, ch);
            ABORT ();
        }
    }

    // read reply that mul36.pal prints to the tty
    bool hitsp = false;
    uint64_t rephi = 0;
    uint64_t replo = 0;
    while (true) {
        ch = readwithecho ();
        if (ch == '\r') continue;
        if (ch == '\n') break;
        if (ch == ' ') hitsp = true;
        if (! hitsp) {
            if ((ch < '0') || (ch > '7')) {
                fprintf (stderr, "bad reply char %c\n", ch);
                ABORT ();
            }
            rephi = (rephi << 3) | (replo >> 33);
            replo = ((replo & 077777777777ULL) << 3) | (ch & 7);
        }
    }

    // compute 72-bit product
    uint64_t prod22bin = rand1lo * rand2lo;
    uint64_t prod21bin = rand1lo * rand2hi;
    uint64_t prod12bin = rand1hi * rand2lo;
    uint64_t prod11bin = rand1hi * rand2hi;

    uint64_t prod4bin = prod22bin & 0777777;
    uint64_t prod3bin = (prod22bin >> 18) + prod21bin + prod12bin;
    uint64_t prod2bin = (prod3bin >> 18) + prod11bin;
    uint64_t prod1bin = prod2bin >> 18;

    prod3bin = prod3bin & 0777777;
    prod2bin = prod2bin & 0777777;

    uint64_t prodhi = (prod1bin << 18) | prod2bin;
    uint64_t prodlo = (prod3bin << 18) | prod4bin;

    if ((rephi != prodhi) || (replo != prodlo)) {
        fprintf (stderr, "BAD  expect=%012llo%012llo  received=%012llo%012llo\n",
            (long long unsigned) prodhi, (long long unsigned) prodlo,
            (long long unsigned) rephi, (long long unsigned) replo);
        ABORT ();
    }
}

static char readwithecho ()
{
    uint8_t ch;
    while (! tt_getprchar (&ch)) { }
    putchar (ch);
    return ch;
}

static void sendchartottykb (char ch)
{
    while (! tt_putkbchar (ch)) { }
}

// get printer character from single terminal interface

static bool tt_getprchar (uint8_t *prchar_r)
{
    uint32_t prreg = ttyat[Z_TTYPR];
    if (! (prreg & PR_FULL)) return false;
    *prchar_r = prreg;
    ttyat[Z_TTYPR] = PR_FLAG;
    return true;
}

// put keyboard character to single terminal interface

static bool tt_putkbchar (uint8_t kbchar)
{
    if (ttyat[Z_TTYKB] & KB_FLAG) return false;
    ttyat[Z_TTYKB] = KB_FLAG | KB_ENAB | kbchar;
    return true;
}
