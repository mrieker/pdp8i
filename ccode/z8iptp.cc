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

// Performs paper tape punch I/O for the PDP-8/I Zynq I/O board

#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "z8idefs.h"
#include "z8iutil.h"

#define PTP_FLAG 0x80000000U // tells PDP char has been punched
#define PTP_ENAB 0x40000000U // enables pdp8iptp.v to process i/o instructions
#define PTP_BUSY 0x20000000U // tells ARM there is a char to punch

static bool volatile ctrlcflag;
static uint8_t const nulls[16] = { 0 };

static void siginthand (int signum);

int main (int argc, char **argv)
{
    bool clear   = false;
    bool killit  = false;
    bool leader  = false;
    bool remcr   = false;
    bool remdel  = false;
    bool remnul  = false;
    bool trailer = false;
    char const *filename = NULL;
    uint32_t cps = 50;
    uint8_t mask = 0;
    for (int i = 0; ++ i < argc;) {
        if (strcmp (argv[i], "-?") == 0) {
            puts ("");
            puts ("     Access paper tape punch");
            puts ("");
            puts ("  ./z8iptp [-7bit] [-clear] [-cps <charspersec>] [-killit] [-leader] [-remcr] [-remdel] [-remnul] [-text] [-trailer] <filename>");
            puts ("     -7bit    : force top bit of byte = 0");
            puts ("     -clear   : clear status bits at beginning");
            puts ("     -cps     : set chars per second, default 50");
            puts ("     -killit  : kill other process that is processing paper tape punch");
            puts ("     -leader  : output 16-byte null leader");
            puts ("     -remcr   : remove <CR>s");
            puts ("     -remdel  : remove <DEL>s");
            puts ("     -remnul  : remove <NUL>s");
            puts ("     -text    : equivalent to -7bit -remcr -remdel -remnul");
            puts ("     -trailer : output 16-byte null trailer");
            puts ("");
            return 0;
        }
        if (strcasecmp (argv[i], "-7bit") == 0) {
            mask = 0200;
            continue;
        }
        if (strcasecmp (argv[i], "-clear") == 0) {
            clear = true;
            continue;
        }
        if (strcasecmp (argv[i], "-cps") == 0) {
            if ((++ i >= argc) || (argv[i][0] == '-')) {
                fprintf (stderr, "missing value for -cps\n");
                return 1;
            }
            char *p;
            cps = strtoul (argv[i], &p, 0);
            if ((*p != 0) || (cps == 0) || (cps > 1000)) {
                fprintf (stderr, "-cps value %s must be integer in range 1..1000\n", argv[i]);
                return 1;
            }
            continue;
        }
        if (strcasecmp (argv[i], "-killit") == 0) {
            killit = true;
            continue;
        }
        if (strcasecmp (argv[i], "-leader") == 0) {
            leader = true;
            continue;
        }
        if (strcasecmp (argv[i], "-remcr") == 0) {
            remcr = true;
            continue;
        }
        if (strcasecmp (argv[i], "-remdel") == 0) {
            remdel = true;
            continue;
        }
        if (strcasecmp (argv[i], "-remnul") == 0) {
            remnul = true;
            continue;
        }
        if (strcasecmp (argv[i], "-text") == 0) {
            mask   = 0200;
            remcr  = true;
            remdel = true;
            remnul = true;
            continue;
        }
        if (strcasecmp (argv[i], "-trailer") == 0) {
            trailer = true;
            continue;
        }
        if (argv[i][0] == '-') {
            fprintf (stderr, "unknown option %s\n", argv[i]);
            return 1;
        }
        if (filename != NULL) {
            fprintf (stderr, "unknown argument %s\n", argv[i]);
            return 1;
        }
        filename = argv[i];
    }

    if (filename == NULL) {
        fprintf (stderr, "missing filename\n");
        return 1;
    }
    FILE *fileptr = fopen (filename, "w");
    if (fileptr == NULL) {
        fprintf (stderr, "error creating %s: %m\n", filename);
        return 1;
    }
    if (leader) {
        int rc = fwrite (nulls, 1, sizeof nulls, fileptr);
        if (rc < 0) {
            fprintf (stderr, "error punching leader: %m\n");
            ABORT ();
        }
        if (rc < (int) sizeof nulls) {
            fprintf (stderr, "only punched %d of %d-byte leader\n", rc, (int) sizeof nulls);
            ABORT ();
        }
    }

    Z8IU32 *ptpat = z8ipage.findev ("PP", NULL, NULL, true, killit);
    if (clear) {
        ptpat[1]  = PTP_ENAB;   // enable pdp8iptp.v to process io instructions
    } else {
        ptpat[1] |= PTP_ENAB;   // enable pdp8iptp.v to process io instructions
    }

    signal (SIGINT,  siginthand);
    signal (SIGTERM, siginthand);

    uint32_t nbytes = 0;
    while (! ctrlcflag) {
        printf ("\r%u byte%s so far ", nbytes, ((nbytes == 1) ? "" : "s"));
        fflush (stdout);

        z8ipage.waitint (ZGINT_PP);
        uint32_t ptpreg = ptpat[1];
        if (ptpreg & PTP_BUSY) {

            uint8_t wrbyte = ptpreg & ~ mask;
            if ((! remcr || (wrbyte != '\r')) && (! remdel || (wrbyte != 127)) && (! remnul || (wrbyte != 0))) {
                int rc = fputc (wrbyte, fileptr);
                if (rc < 0) {
                    fprintf (stderr, "error writing %s: %m\n", filename);
                    fclose (fileptr);
                    ABORT ();
                }
            }

            ptpat[1] = PTP_FLAG | PTP_ENAB;
            ++ nbytes;
        }
    }

    if (trailer) {
        int rc = fwrite (nulls, 1, sizeof nulls, fileptr);
        if (rc < 0) {
            fprintf (stderr, "error punching trailer: %m\n");
            fclose (fileptr);
            ABORT ();
        }
        if (rc < (int) sizeof nulls) {
            fprintf (stderr, "only punched %d of %d-byte trailer\n", rc, (int) sizeof nulls);
            fclose (fileptr);
            ABORT ();
        }
    }

    if (fclose (fileptr) < 0) {
        fprintf (stderr, "error closing file: %m\n");
        ABORT ();
    }
    printf ("file successfully closed\n");
    return 0;
}

static void siginthand (int signum)
{
    if (ctrlcflag) exit (1);
    ctrlcflag = true;
    if ((signum == SIGINT) && (write (STDIN_FILENO, "\n", 1) < 0)) { }
}
