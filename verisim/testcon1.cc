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

// test physical console board
// runs on raspi plugged into tester board with physical console board plugged in

// two modes:
//  ./testconsole man - manual testing
//    drags single light aound panel
//    displays switch contents
//    assumes console board jumpers
//      lttime = div_5
//      swtime = div_2
//  ./testconsole auto - automatic testing
//    tests with random numbers
//    uses console mcp23017 for gpio access
//    assumes tester consck,consda jumpers in
//    front panel connected is optional

#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "testlib.h"

static int const console_impins[] = {
    mp__ACUM_0, mp__ACUM_1, mp__ACUM_2, mp__ACUM_3, mp__ACUM_4, mp__ACUM_5, mp__ACUM_6, mp__ACUM_7, mp__ACUM_8, mp__ACUM_9,
    mp__ACUM_10, mp__ACUM_11, mp__CLOCK, mp__ION, mp__IREG_9, mp__IREG_10,
    mp__IREG_11, mp__LINK, mp__MADR_0, mp__MADR_1, mp__MADR_2, mp__MADR_3, mp__MADR_4, mp__MADR_5, mp__MADR_6, mp__MADR_7, mp__MADR_8,
    mp__MADR_9, mp__MADR_10, mp__MADR_11, mp__MAJST_0, mp__MAJST_1, mp__MAJST_2, mp__MAJST_3, mp__MBUF_0,mp__MBUF_1, mp__MBUF_2, mp__MBUF_3, 
    mp__MBUF_4, mp__MBUF_5, mp__MBUF_6, mp__MBUF_7, mp__MBUF_8, mp__MBUF_9, mp__MBUF_10, mp__MBUF_11, 
    mp__MQUO_0, mp__MQUO_1, mp__MQUO_2, mp__MQUO_3, mp__MQUO_4, mp__MQUO_5, mp__MQUO_6, mp__MQUO_7, mp__MQUO_8,
    mp__MQUO_9, mp__MQUO_10, mp__MQUO_11, mp__PAUSE,
    mp__PCTR_0, mp__PCTR_1, mp__PCTR_2, 
    mp__PCTR_3, mp__PCTR_4, mp__PCTR_5, mp__PCTR_6, mp__PCTR_7, mp__PCTR_8, mp__PCTR_9, mp__PCTR_10, mp__PCTR_11, 
    mp__READSR, mp__RESET, mp__RUN, mp__SCTR_0, mp__SCTR_1, mp__SCTR_2, 
    mp__SCTR_3, mp__SCTR_4, 0 };

// assume console board is outputting DFLD,IFLD switches to the bus
// it does that whenever the LDAD switch is pressed which manual test mode can't control
static int const console_ompins[] = {
    mp__DFLD_0, mp__DFLD_1, mp__DFLD_2, mp__IFLD_0, mp__IFLD_1, mp__IFLD_2,
    mp__SWCONT, mp__SWDEPOS, mp__SWEXAM, mp__SWLDAD, mp__SWSINST, mp__SWSSTEP, mp__SWSTART,
    mp__INBUS_0, mp__INBUS_1, mp__INBUS_2, mp__INBUS_3, mp__INBUS_4, mp__INBUS_5, mp__INBUS_6, mp__INBUS_7, mp__INBUS_8, mp__INBUS_9,
    mp__INBUS_10, mp__INBUS_11, 0 };

static int const dfldifldmpins[] = {
    mp__DFLD_0, mp__DFLD_1, mp__DFLD_2, mp__IFLD_0, mp__IFLD_1, mp__IFLD_2, 0 };

static volatile bool ctrlcflag;
static uint32_t errors;
static uint32_t passes;

static void sighand (int signum);
static void writerow (int row, uint16_t data);
static uint16_t readrow (int row);

int main (int argc, char **argv)
{
    setlinebuf (stdout);

    signal (SIGINT, sighand);

    // access tester board mcp23017s and set pin directions
    setmpinmask (boardipinmask, console_impins);
    setmpinmask (boardopinmask, console_ompins);
    mcpsetdir ();

    // reset console board state
    setmpin (mp__RESET, 0);
    mcpsend ();
    setmpin (mp__CLOCK, 0);
    mcpsend ();
    setmpin (mp__CLOCK, 1);
    mcpsend ();
    setmpin (mp__RESET, 1);
    mcpsend ();

    writerow (15, 0);                       // maintain iicsel = 15 when iicsel pins set to output mode

    mcpwrite16 (1, 0, 0x00, 0x3F3F);
    mcpwrite16 (1, 0, 0x0C, 0x3F3F);        // enable pullups on input pins


    while (! ctrlcflag) {
        uint16_t swrows[3];
        for (int i = 0; i < 3; i ++) {
            writerow (12 + i, 0);                       // set iicsel = 12 to sense physical switch row 0
            swrows[i] = readrow (12 + i);
        }
        printf (" %04o %04o %04o\n", swrows[0], swrows[1], swrows[2]);
    }

    printf ("resetting\n");
    setmpin (mp__RESET, 0);
    mcpsend ();

    return 0;
}

static void sighand (int signum)
{
    if (ctrlcflag) exit (1);
    ctrlcflag = true;
}

// send row selection and data to console mcp23017
static void writerow (int row, uint16_t data)
{
    uint8_t areg = ((row & 12) << 4) | (data & 63);
    uint8_t breg = ((row &  3) << 6) | (data >> 6);

    mcpwrite16 (1, 0, 0x14, ((uint16_t) breg << 8) | areg);
}

// get row data from console mcp23017
static uint16_t readrow (int row)
{
    uint16_t raw = mcpread16 (1, 0, 0x12);

    // raw<15:14> = GPB<7:6> = iicsel<1:0>
    // raw<13:08> = GPB<5:0> = fpdata<11:06>
    // raw<07:06> = GPA<7:6> = iicsel<3:2>
    // raw<05:00> = GPA<5:0> = fpdata<05:00>

    int iicsel = ((raw & 0x00C0) >> 4) | ((raw & 0xC000) >> 14);
    if (iicsel != row) printf ("%8u %8u readrow: iicsel is %X, expect %X\n", ++ errors, passes, iicsel, row);

    return ((raw & 0x3F00) >> 2) | (raw & 0x003F);
}
