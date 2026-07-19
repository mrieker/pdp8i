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

static void sighand (int signum);
static void writerow (int row, uint16_t data);
static uint16_t readrow (int row);

static void mantest ();
static void autotest ();
static void abouttopressldad ();
static void justreleasedldad ();

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
    for (int i = 0; i < 10; i ++) {
        setmpin (mp__CLOCK, 0);
        mcpsend ();
        setmpin (mp__CLOCK, 1);
        mcpsend ();
    }
    setmpin (mp__RESET, 1);
    mcpsend ();

    if ((argc > 1) && (strcasecmp (argv[1], "auto") == 0)) autotest ();
    if ((argc > 1) && (strcasecmp (argv[1], "man")  == 0)) mantest  ();

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
    ////???? row check ????
    return ((raw & 63) << 6) | ((raw >> 8) & 63);
}

static void mantest ()
{
    // console MCP23017 should have power-on reset to all inputs
    // it should leave the on-board clocking enabled

    int lttime  = 1 << 5;   // jumpered to div_5 => 3.3uS per light row
    int swtime  = 1 << 2;   // jumpered to div_2 => 0.5uS per switch row
    int nclocks = 8 * (lttime + 1) + 3 * (swtime + 1) + 1;

    int lbnum = 0;
    uint16_t ireg = 0;

    while (! ctrlcflag) {

        // pick next sequential light
        uint16_t acum   = 0;
        bool     ion    = 0;
        bool     link   = 0;
        uint16_t madr   = 0;
        uint16_t majst  = 0;
        uint16_t mbuf   = 0;
        uint16_t mquo   = 0;
        bool     pause  = 0;
        uint16_t pctr   = 0;
        bool     run    = 0;
        uint16_t sctr   = 0;

        switch (lbnum) {
            case  0: pctr = 04000; break;
            case  1: pctr = 02000; break;
            case  2: pctr = 01000; break;
            case  3: pctr = 00400; break;
            case  4: pctr = 00200; break;
            case  5: pctr = 00100; break;
            case  6: pctr = 00040; break;
            case  7: pctr = 00020; break;
            case  8: pctr = 00010; break;
            case  9: pctr = 00004; break;
            case 10: pctr = 00002; break;
            case 11: pctr = 00001; break;
            case 12: madr = 04000; break;
            case 13: madr = 02000; break;
            case 14: madr = 01000; break;
            case 15: madr = 00400; break;
            case 16: madr = 00200; break;
            case 17: madr = 00100; break;
            case 18: madr = 00040; break;
            case 19: madr = 00020; break;
            case 20: madr = 00010; break;
            case 21: madr = 00004; break;
            case 22: madr = 00002; break;
            case 23: madr = 00001; break;
            case 24: mbuf = 04000; break;
            case 25: mbuf = 02000; break;
            case 26: mbuf = 01000; break;
            case 27: mbuf = 00400; break;
            case 28: mbuf = 00200; break;
            case 29: mbuf = 00100; break;
            case 30: mbuf = 00040; break;
            case 31: mbuf = 00020; break;
            case 32: mbuf = 00010; break;
            case 33: mbuf = 00004; break;
            case 34: mbuf = 00002; break;
            case 35: mbuf = 00001; break;
            case 36: link = 1; break;
            case 37: acum = 04000; break;
            case 38: acum = 02000; break;
            case 39: acum = 01000; break;
            case 40: acum = 00400; break;
            case 41: acum = 00200; break;
            case 42: acum = 00100; break;
            case 43: acum = 00040; break;
            case 44: acum = 00020; break;
            case 45: acum = 00010; break;
            case 46: acum = 00004; break;
            case 47: acum = 00002; break;
            case 48: acum = 00001; break;
            case 49: sctr = 020; break;
            case 50: sctr = 010; break;
            case 51: sctr = 004; break;
            case 52: sctr = 002; break;
            case 53: sctr = 001; break;
            case 54: mquo = 04000; break;
            case 55: mquo = 02000; break;
            case 56: mquo = 01000; break;
            case 57: mquo = 00400; break;
            case 58: mquo = 00200; break;
            case 59: mquo = 00100; break;
            case 60: mquo = 00040; break;
            case 61: mquo = 00020; break;
            case 62: mquo = 00010; break;
            case 63: mquo = 00004; break;
            case 64: mquo = 00002; break;
            case 65: mquo = 00001; break;
            case 66: ireg = (ireg + 1) & 7; break;
            case 67: majst = 1; break;
            case 68: majst = 3; break;
            case 69: majst = 2; break;
            case 70: majst = 4; break;
            case 71: majst = 5; break;
            case 72: majst = 6; break;
            case 73: ion   = 1; break;
            case 74: pause = 1; break;
            case 75: run   = 1; break;
            default: abort ();
        }
        lbnum = (lbnum + 1) % 76;

        // always gate switch register to inbus
        bool readsr = true;

        // put values on bus to be displayed
        setmpins (mps__ACUM,    acum ^ 07777);
        setmpin  (mp__ION,    ! ion);
        setmpins (mps__IREG,    ireg ^ 7);
        setmpin  (mp__LINK,   ! link);
        setmpins (mps__MADR,    madr ^ 07777);
        setmpins (mps__MAJST,   majst ^ 017);
        setmpins (mps__MBUF,    mbuf ^ 07777);
        setmpins (mps__MQUO,    mquo ^ 07777);
        setmpin  (mp__PAUSE,  ! pause);
        setmpins (mps__PCTR,    pctr ^ 07777);
        setmpin  (mp__READSR, ! readsr);
        setmpin  (mp__RUN,    ! run);
        setmpins (mps__SCTR,    sctr ^ 037);
        mcpsend ();

        // clock to display them all and update switch flipflops
        for (int i = 0; i < nclocks; i ++) {
            setmpin  (mp__CLOCK, 0);
            mcpsend ();
            setmpin  (mp__CLOCK, 1);
            mcpsend ();
        }

        // read switches from bus and display
        mcprecv ();

        bool buscont  = ! getmpin (mp__SWCONT);
        bool busdepos = ! getmpin (mp__SWDEPOS);
        bool busexam  = ! getmpin (mp__SWEXAM);
        bool busldad  = ! getmpin (mp__SWLDAD);
        bool bussinst = ! getmpin (mp__SWSINST);
        bool bussstep = ! getmpin (mp__SWSSTEP);
        bool busstart = ! getmpin (mp__SWSTART);

        char dfstr[2], ifstr[2], srstr[7];
        strcpy (dfstr, "-");
        strcpy (ifstr, "-");
        strcpy (srstr, "----");
        if (busldad) {
            uint16_t busdfld = getmpins (mps__DFLD) ^ 7;
            uint16_t busifld = getmpins (mps__IFLD) ^ 7;
            dfstr[0] = '0' + busdfld;
            ifstr[0] = '0' + busifld;
        }
        if (readsr) {
            uint16_t businbus = getmpins (mps__INBUS) ^ 07777;
            snprintf (srstr, sizeof srstr, "%04o", businbus);
        }

        printf ("DF=%s IF=%s SR=%s %s %s %s %s %s %s %s\n",
            dfstr, ifstr, srstr,
            busstart ? "START" : "start",
            busldad  ? "LDAD"  : "ldad",
            busdepos ? "DEPOS" : "depos",
            busexam  ? "EXAM"  : "exam",
            buscont  ? "CONT"  : "cont",
            bussstep ? "SSTEP" : "sstep",
            bussinst ? "SINST" : "sinst");
    }
}

static void autotest ()
{
    // console MCP23017 is connected to the front panel gpio connector
    // it can drive or sense the data pins (gpio 4..15)
    // it can drive the row selection pins (gpio 16..18, 20..27)

    // set console mcp23017 pin direction
    //  iicsel output (drive gpio row selection pins)
    //    data input (sense gpio data pins)
    mcpwrite16 (1, 0, 0x00, 0x3F3F);

    // we are initially set up to read the dfld,ifld bus lines as if the ldad switch was being pressed
    mcprecv ();
    bool lastswldad = ! getmpin (mp__SWLDAD);       // read bus _SWLDAD signal (console board ldad flipflop)

    // if switch is actually released (very likely), set up tester board to drive the dfld,ifld lines
    if (! lastswldad) {
        setmpinmask (boardipinmask, dfldifldmpins);  // mcpsend() will send to dfld,ifld pins
        clrmpinmask (boardopinmask, dfldifldmpins);  // mcprecv() won't read what the board is outputting
        mcpsetdir ();
    }

    while (! ctrlcflag) {

        // make up random values for registers to be displayed in the lights
        // console board should ignore clock when using 23017 so make it random
        // if ldad is released,
        //   generate random values for the dfld,ifld lights
        // if ldad is pressed,
        //   dfld,ifld are being driven by the console board switch values
        //   which get looped back around into the lights, so use their values
        uint16_t acum   = randbits (12);
        bool     clock  = randbits (1);
        uint16_t dfld   = lastswldad ? getmpins (mps__DFLD) ^ 7 : randbits (3);
        uint16_t ifld   = lastswldad ? getmpins (mps__IFLD) ^ 7 : randbits (3);
        bool     ion    = randbits (1);
        uint16_t ireg   = randbits (3);
        bool     link   = randbits (1);
        uint16_t madr   = randbits (12);
        uint16_t majst  = randbits (4);
        uint16_t mbuf   = randbits (12);
        uint16_t mquo   = randbits (12);
        bool     pause  = randbits (1);
        uint16_t pctr   = randbits (12);
        bool     readsr = randbits (1);
        bool     run    = randbits (1);
        uint16_t sctr   = randbits (5);

        // put random values on bus to be displayed
        // if ldad pressed, dfld,ifld ignored cuz tester is not driving those lines
        setmpins (mps__ACUM,    acum ^ 07777);
        setmpin  (mp__CLOCK,  ! clock);
        setmpins (mps__DFLD,    dfld ^ 7);
        setmpins (mps__IFLD,    ifld ^ 7);
        setmpin  (mp__ION,    ! ion);
        setmpins (mps__IREG,    ireg ^ 7);
        setmpin  (mp__LINK,   ! link);
        setmpins (mps__MADR,    madr ^ 07777);
        setmpins (mps__MAJST,   majst ^ 017);
        setmpins (mps__MBUF,    mbuf ^ 07777);
        setmpins (mps__MQUO,    mquo ^ 07777);
        setmpin  (mp__PAUSE,  ! pause);
        setmpins (mps__PCTR,    pctr ^ 07777);
        setmpin  (mp__READSR, ! readsr);
        setmpin  (mp__RUN,    ! run);
        setmpins (mps__SCTR,    sctr ^ 037);
        mcpsend ();

        // compute what the light rows should be
        // if ldad pressed, dfld,ifld lights should show switch values
        uint16_t lbrows[8] = {
            pctr,                           // row 0
            madr,                           // row 1
            mbuf,                           // row 2
            acum,                           // row 3
            mquo,                           // row 4
            ((ireg  == 0) ? 0x800 : 0) |    // row 5
            ((ireg  == 1) ? 0x400 : 0) |
            ((ireg  == 2) ? 0x200 : 0) |
            ((ireg  == 3) ? 0x100 : 0) |
            ((ireg  == 4) ? 0x080 : 0) |
            ((ireg  == 5) ? 0x040 : 0) |
            ((ireg  == 6) ? 0x020 : 0) |
            ((ireg  == 7) ? 0x010 : 0) |
            ((majst == 1) ? 0x008 : 0) |
            ((majst == 3) ? 0x004 : 0) |
            ((majst == 2) ? 0x002 : 0) |
            ((majst == 4) ? 0x001 : 0),
            ((majst == 5) ? 0x800 : 0) |    // row 6
            ((majst == 6) ? 0x400 : 0) |
            (ion          ? 0x200 : 0) |
            (pause        ? 0x100 : 0) |
            (run          ? 0x080 : 0) |
            (sctr << 2),
            (dfld << 9) |                   // row 7
            (ifld << 6) |
            (link ? 0x020 : 0) |
            majst
        };
        static int const lbmasks[8] = { 0xFFF, 0xFFF, 0xFFF, 0xFFF, 0xFFF, 0xFFF, 0xFFC, 0xFEF };

        // generate random switch values
        uint16_t swdfld  = randbits (3);
        uint16_t swifld  = randbits (3);
        uint16_t swreg   = randbits (12);
        bool     swcont  = randbits (1);
        bool     swdepos = randbits (1);
        bool     swexam  = randbits (1);
        bool     swldad  = randbits (1);
        bool     swsinst = randbits (1);
        bool     swsstep = randbits (1);
        bool     swstart = randbits (1);
        bool     swstop  = randbits (1);

        uint16_t swrows[3] = {
            swreg,
            (swdfld << 9) | (swifld << 6),
            (swstart ? 0x800 : 0) |
            (swldad  ? 0x400 : 0) |
            (swdepos ? 0x200 : 0) |
            (swexam  ? 0x100 : 0) |
            (swcont  ? 0x080 : 0) |
            (swstop  ? 0x040 : 0) |
            (swsstep ? 0x020 : 0) |
            (swsinst ? 0x010 : 0)
        };

        // use console's 23017 to read the light rows then compare
        // console 23017 direction set to 3F3F  <7:6> outputs; <5:0> inputs
        //   GPA0 = gpio<13> (LSB)   GPB0 = gpio<07>
        //   GPA1 = gpio<12>         GPB1 = gpio<06>
        //   GPA2 = gpio<11>         GPB2 = gpio<05>
        //   GPA3 = gpio<10>         GPB3 = gpio<04>
        //   GPA4 = gpio<09>         GPB4 = gpio<15>
        //   GPA5 = gpio<08>         GPB5 = gpio<14> (MSB)
        //   GPA6 = iicsel<2>        GPB6 = iicsel<0>
        //   GPA7 = iicsel<3>        GPB7 = iicsel<1>
        for (int lr = 0; lr < 8; lr ++) {

            // set iicsel<3> = 0
            // set iicsel<2:0> = light row
            // gates bits from bus through 244s to gpio pins inverted
            writerow (lr, 0);
            uint16_t row = readrow (lr) ^ 07777;
            if ((row ^ lbrows[lr]) & lbmasks[lr]) {
                printf ("row %d is %04o sb %04o mask %04o\n", lr, row, lbrows[lr], lbmasks[lr]);
            }

            // update like-numbered switch row flipflops
            //  if just displayed light row 0, update switch row 0 then row 2 flipflops
            //  if just displayed light row 1, update switch row 1 flipflops
            if (lr <= 1) {
                int sr = lr;

                // at this point, ldswrow0,1,2 are all high
                // set data pins value to switch row and value:
                //  0x14 <=    2'b10 swval<11:06>
                //  0x15 <= row<1:0> swval<05:00>
                // only changes one iicsel bit (sets iicsel_3) to avoid glitching ldswrows<n>
                // ...which smoothly drives ldswrow<n> low
                writerow (sr | 8, swrows[sr]);

                // set data pins to output mode so bits get sent out the mcp to flipflop inpts
                mcpwrite16 (1, 0, 0x00, 0x0000);

                if (sr == 0) {

                    // doing swrow 0, transition iicsel from 1000 to 1011 might glitch
                    // so transition iicsel from 1000 to 1010 first
                    // by doing 0x15 <= 2'b10 val<05:00>
                    // driving ldswrow0 high (clocking data into swrow0)
                    //  with side-effect of driving ldswrow2 low
                    writerow (10, swrows[0]);

                    // ldswrow2 is now low after driving ldswrow0 high
                    // we must clock in proper swrow2 contents to drive ldswrow2 high
                    // ...as idle state of ldswrow0,1,2 is high
                    writerow (10, swrows[2]);

                    sr = 2;
                }

                // doing swrow 1 or 2, transition iicsel from 1001 or 1010 to 1011 won't glitch
                // drives ldswrow<n> high
                // so do 0x15 <= 2'b11 val<05:00>
                if ((sr == 2) && ! lastswldad && swldad) abouttopressldad ();
                writerow (11, swrows[sr]);
                if ((sr == 2) && lastswldad && ! swldad) justreleasedldad ();
                if (sr == 2) lastswldad = swldad;

                // new switch values have been clocked into switch flipflops

                // set data pins back to input mode
                mcpwrite16 (1, 0, 0x00, 0x3F3F);
            }

            // read like-numbered physical switch row
            //  if just displayed light row 4, sense switch row 0
            //  if just displayed light row 5, sense switch row 1
            //  if just displayed light row 6, sense switch row 2
            if ((lr >= 4) && (lr <= 6)) {
                int sr = lr - 4;

                // at this point, ldswrow0,1,2 are all high
                // set data pins value to switch row:
                //  0x14 <= 2'b11 6'b000000
                // only changes one iicsel bit (sets iicsel_3) to avoid glitching ldswrows<n>
                writerow (sr | 12, 0);

                // read physical switch pins from bGPIO: 0x12,0x13
                uint16_t row = readrow (sr | 12);
                printf ("phys sw row %d = %04o\n", sr, row);
            }
        }

        // check output pins to see if they match random switches
        mcprecv ();
        bool buscont  = ! getmpin (mp__SWCONT);  if (buscont  != swcont)  printf ("bus CONT  %o != switch CONT  %o\n", buscont,  swcont);
        bool busdepos = ! getmpin (mp__SWDEPOS); if (busdepos != swdepos) printf ("bus DEPOS %o != switch DEPOS %o\n", busdepos, swdepos);
        bool busexam  = ! getmpin (mp__SWEXAM);  if (busexam  != swexam)  printf ("bus EXAM  %o != switch EXAM  %o\n", busexam,  swexam);
        bool busldad  = ! getmpin (mp__SWLDAD);  if (busldad  != swldad)  printf ("bus LDAD  %o != switch LDAD  %o\n", busldad,  swldad);
        bool bussinst = ! getmpin (mp__SWSINST); if (bussinst != swsinst) printf ("bus SINST %o != switch SINST %o\n", bussinst, swsinst);
        bool bussstep = ! getmpin (mp__SWSSTEP); if (bussstep != swsstep) printf ("bus SSTEP %o != switch SSTEP %o\n", bussstep, swsstep);
        bool busstart = ! getmpin (mp__SWSTART); if (busstart != swstart) printf ("bus START %o != switch START %o\n", busstart, swstart);
        if (busldad) {
            uint16_t busdfld = getmpins (mps__DFLD) ^ 7; if (busdfld != swdfld) printf ("bus DFLD %o != switch DFLD %o\n", busdfld,  swdfld);
            uint16_t busifld = getmpins (mps__IFLD) ^ 7; if (busifld != swifld) printf ("bus IFLD %o != switch IFLD %o\n", busifld,  swifld);
        }
        if (readsr) {
            uint16_t businbus = getmpins (mps__INBUS) ^ 07777;
            if (businbus != swreg) printf ("bus INBUS %04o != swreg %04o\n", businbus, swreg);
        }
    }
}

// we are about to press the ldad switch (set console board ldad ff),
//  console board will start driving the dfld,ifld bus lines
//  make sure tester board isn't driving them as well
static void abouttopressldad ()
{
    clrmpinmask (boardipinmask, dfldifldmpins);  // mcpsend() won't send anything to dfld,ifld pins
    setmpinmask (boardopinmask, dfldifldmpins);  // mcprecv() will read what the board is outputting
    mcpsetdir ();
}

// we just released the ldad switch (cleared console board ldad ff),
//  console board has supposedly hi-Zd the dfld,ifld bus pins
//  enable tester mcp23017s to output dfld,ifld values for display
static void justreleasedldad ()
{
    setmpinmask (boardipinmask, dfldifldmpins);  // mcpsend() will send to dfld,ifld pins
    clrmpinmask (boardopinmask, dfldifldmpins);  // mcprecv() won't read what the board is outputting
    mcpsetdir ();
}
