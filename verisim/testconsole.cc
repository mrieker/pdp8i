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

    // raw<15:14> = GPB<7:6> = iicsel<1:0>
    // raw<13:08> = GPB<5:0> = fpdata<11:06>
    // raw<07:06> = GPA<7:6> = iicsel<3:2>
    // raw<05:00> = GPA<5:0> = fpdata<05:00>

    int iicsel = ((raw & 0x00C0) >> 4) | ((raw & 0xC000) >> 14);
    if (iicsel != row) printf ("%8u %8u readrow: iicsel is %X, expect %X\n", ++ errors, passes, iicsel, row);

    return ((raw & 0x3F00) >> 2) | (raw & 0x003F);
}


//            LR0 LR1 LR2 LR3 LR4 LR5 LR6 LR7  SR0 SR1 SR2
// 14  GPB5   pc1 ma1 mb1 ac1 mq1 and cad df1  sw1 df1 start   [MSB]
// 15  GPB4   pc2 ma2 mb2 ac2 mq2 tad brk df2  sw2 df2 ldaddr
//  4  GPB3   pc3 ma3 mb3 ac3 mq3 isz ion df3  sw3 df3 dep
//  5  GPB2    .   .   .   .   .  dca pau if1   .  if1 exam
//  6  GPB1    .   .   .   .   .  jms run if2   .  if2 cont
//  7  GPB0    .   .   .   .   .  jmp sc1 if3   .  if3 stop
//  8  GPA5    .   .   .   .   .  iot sc2 lnk   .      sstep
//  9  GPA4    .   .   .   .   .  opr sc3       .      sinst
// 10  GPA3    .   .   .   .   .  fet sc4 ms1   .
// 11  GPA2    .   .   .   .   .  exe sc5 ms2   .
// 12  GPA1    .   .   .   .   .  def     ms3   .
// 13  GPA0    .   .   .   .   .  wct     ms4   .              [LSB]

static int const mps__LINK[]  = { mp__LINK,  0 };
static int const mps__ION[]   = { mp__ION,   0 };
static int const mps__PAUSE[] = { mp__PAUSE, 0 };
static int const mps__RUN[]   = { mp__RUN,   0 };

static void showlightrow (int ltrow, int const *mpins, uint16_t value);

static void mantest ()
{
    justreleasedldad ();

    // set console mcp23017 pin direction
    //  iicsel output (drive gpio row selection pins)
    //    data input (sense gpio data pins)
    mcpwrite16 (1, 0, 0x00, 0x3F3F);

    // turn on pullups for input pins
    mcpwrite16 (1, 0, 0x0C, 0x3F3F);

    uint16_t ireg = 0;

    while (! ctrlcflag) {
        for (uint16_t dfld = 8; dfld > 0; dfld /= 2) showlightrow (7, mps__DFLD, dfld / 2);
        for (uint16_t ifld = 8; ifld > 0; ifld /= 2) showlightrow (7, mps__IFLD, ifld / 2);
        for (uint16_t pctr = 010000; pctr > 0; pctr /= 2) showlightrow (0, mps__PCTR, pctr / 2);
        for (uint16_t madr = 010000; madr > 0; madr /= 2) showlightrow (1, mps__MADR, madr / 2);
        for (uint16_t mbuf = 010000; mbuf > 0; mbuf /= 2) showlightrow (2, mps__MBUF, mbuf / 2);
        for (uint16_t link = 2;      link > 0; link /= 2) showlightrow (7, mps__LINK, link / 2);
        for (uint16_t acum = 010000; acum > 0; acum /= 2) showlightrow (3, mps__ACUM, acum / 2);
        for (uint16_t sctr = 000040; sctr > 0; sctr /= 2) showlightrow (6, mps__SCTR, sctr / 2);
        for (uint16_t mquo = 010000; mquo > 0; mquo /= 2) showlightrow (4, mps__MQUO, mquo / 2);
        showlightrow (5, mps__IREG, ireg); ireg = (ireg + 1) & 7;
        for (uint16_t majst = 1; majst <= 7; majst ++) showlightrow (majst <= 4 ? 5 : 6, mps__MAJST, majst ^ ((majst & 6) == 2));
        for (uint16_t ion   = 2; ion   > 0; ion   /= 2) showlightrow (6, mps__ION,   ion   / 2);
        for (uint16_t pause = 2; pause > 0; pause /= 2) showlightrow (6, mps__PAUSE, pause / 2);
        for (uint16_t run   = 2; run   > 0; run   /= 2) showlightrow (6, mps__RUN,   run   / 2);

        uint16_t swrows[3];
        for (int swr = 0; swr < 3; swr ++) {
            writerow (swr + 12, 0);
            swrows[swr] = readrow (swr + 12) ^ 07777;
        }
        printf (" swrows %04o %04o %04o\n", swrows[0], swrows[1], swrows[2]);
    }
}

// write value to bus pins then gate those pins to the front panel
//  input:
//   ltrow = which light row to gate bus pins to
//   mpins = which bus pins to write
//   value = value to write to the bus pins
static void showlightrow (int ltrow, int const *mpins, uint16_t value)
{
    setmpins (mpins, ~ value);
    mcpsend ();
    writerow (ltrow, 0);
    if (value > 0) {
        usleep (250000);
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

    // confirm the switch is actually released as supposedly assured by RESET
    if (! getmpin (mp__SWLDAD)) {
        fprintf (stderr, "autotest: resetting did not clear LDAD switch flipflop\n");
        ABORT ();
    }

    // switch test mcp23017s to drive dlfd,ifld bus lines
    // then dfld,ifld values on bus lines will flow through to dfld,ifld lights
    justreleasedldad ();

    while (! ctrlcflag) {
        ++ passes;

        // make up random values for registers to be displayed in the lights
        // console board should ignore clock when using 23017 so make it random
        // always leave ldad switch released, we test it separately later
        uint16_t acum   = randbits (12);
        bool     clock  = randbits (1);
        uint16_t dfld   = randbits (3);
        uint16_t ifld   = randbits (3);
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

        // generate random switch values to get stuffed into flipflops
        uint16_t swdfld  = randbits (3);
        uint16_t swifld  = randbits (3);
        uint16_t swreg   = randbits (12);
        bool     swcont  = randbits (1);
        bool     swdepos = randbits (1);
        bool     swexam  = randbits (1);
        bool     swsinst = randbits (1);
        bool     swsstep = randbits (1);
        bool     swstart = randbits (1);
        bool     swstop  = randbits (1);

        printf ("%8u %8u acum=%04o clock=%o dfld=%o ifld=%o ion=%o ireg=%o link=%o madr=%04o majst=%X mbuf=%04o mquo=%04o pause=%o pctr=%04o readsr=%o run=%o sctr=%02o "
            "sw dfld=%o ifld=%o reg=%04o cont=%o depos=%o exam=%o sinst=%o sstep=%o start=%o stop=%o\n",
            errors, passes, acum, clock, dfld, ifld, ion, ireg, link, madr, majst, mbuf, mquo, pause, pctr, readsr, run, sctr,
            swdfld, swifld, swreg, swcont, swdepos, swexam, swsinst, swsstep, swstart, swstop);

        // put random values on bus to be displayed
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

        // compute what the light and switch rows should be given those random numbers
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

        uint16_t swrows[3] = {
            swreg,                          // row 0
            (swdfld << 9) | (swifld << 6),  // row 1
            (swstart ? 0x800 : 0) |         // row 2
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
        // also update switch flipflops with their random numbers
        for (int lr = 0; lr < 8; lr ++) {

            // set iicsel<3> = 0
            // set iicsel<2:0> = light row
            // gates bits from bus through 244s to gpio pins inverted
            writerow (lr, 0);
            uint16_t row = readrow (lr) ^ 07777;
            if ((row ^ lbrows[lr]) & lbmasks[lr]) {
                printf ("%8u %8u light row %d is %04o sb %04o mask %04o\n", ++ errors, passes, lr, row, lbrows[lr], lbmasks[lr]);
            }

            // update like-numbered switch row flipflops with generated random numbers
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
                writerow (11, swrows[sr]);

                // new switch values have been clocked into switch flipflops

                // set data pins back to input mode
                mcpwrite16 (1, 0, 0x00, 0x3F3F);
            }

            // read like-numbered physical switch row
            //  if just displayed light row 4, sense physical switch row 0
            //  if just displayed light row 5, sense physical switch row 1
            //  if just displayed light row 6, sense physical switch row 2
            if (false && (lr >= 4) && (lr <= 6)) {
                int sr = lr - 4;

                // at this point, ldswrow0,1,2 are all high
                // set data pins value to switch row:
                //  0x14 <= 2'b11 6'b000000
                // only changes one iicsel bit (sets iicsel_3) to avoid glitching ldswrows<n>
                writerow (sr | 12, 0);

                // read physical switch pins from bGPIO: 0x12,0x13
                uint16_t row = readrow (sr | 12);
                printf ("%8u %8u phys sw row %d = %04o\n", errors, passes, sr, row);
            }
        }

        // check switch bus lines to see if they match random switches
        // console board ORs the SINST and STOP switches together onto single SINST bus line
        mcprecv ();
        bool buscont  = ! getmpin (mp__SWCONT);  if (buscont  != swcont)  printf ("%8u %8u bus CONT  %o != switch CONT  %o\n", ++ errors, passes, buscont,  swcont);
        bool busdepos = ! getmpin (mp__SWDEPOS); if (busdepos != swdepos) printf ("%8u %8u bus DEPOS %o != switch DEPOS %o\n", ++ errors, passes, busdepos, swdepos);
        bool busexam  = ! getmpin (mp__SWEXAM);  if (busexam  != swexam)  printf ("%8u %8u bus EXAM  %o != switch EXAM  %o\n", ++ errors, passes, busexam,  swexam);
        bool busldad  = ! getmpin (mp__SWLDAD);  if (busldad  != false)   printf ("%8u %8u bus LDAD  %o != switch LDAD  %o\n", ++ errors, passes, busldad,  false);
        bool bussinst = ! getmpin (mp__SWSINST); if (bussinst != (swsinst | swstop)) printf ("%8u %8u bus SINST %o != switch SINST %o\n", ++ errors, passes, bussinst, swsinst);
        bool bussstep = ! getmpin (mp__SWSSTEP); if (bussstep != swsstep) printf ("%8u %8u bus SSTEP %o != switch SSTEP %o\n", ++ errors, passes, bussstep, swsstep);
        bool busstart = ! getmpin (mp__SWSTART); if (busstart != swstart) printf ("%8u %8u bus START %o != switch START %o\n", ++ errors, passes, busstart, swstart);
        if (readsr) {
            uint16_t businbus = getmpins (mps__INBUS) ^ 07777;
            if (businbus != swreg) printf ("%8u %8u bus INBUS %04o != swreg %04o\n", ++ errors, passes, businbus, swreg);
        }

        // press LDAD switch which gates SWDFLD, SWIFLD flipflops onto DFLD, IFLD bus lines
        abouttopressldad ();                // disable tester board mcp23017s outputting to DFLD,IFLD bus lines
        writerow  (2, 0);                   // set iicsel = 2 (was 7) so transition to 10 won't glitch any ldswrow lines
        writerow (10, swrows[2] | 0x400);   // set ldswrow2 = 0 (was 1), all row2 switches as before + SWLDAD=1
        mcpwrite16 (1, 0, 0x00, 0x0000);    // turn console mcp23017 data pins to outputs so they will drive switch flipflop inputs
        writerow (11, swrows[2] | 0x400);   // set ldswrow2 = 1, clocking all that into switch flipflops
        mcprecv ();                         // read bus lines using tester board mcp23017s
        if (getmpin (mp__SWLDAD)) {         // LDAD switch should show up on bus (active low)
            fprintf (stderr, "autotest: pressing LDAD did not set LDAD switch flipflop\n");
            ABORT ();
        }

        // make sure the DFLD,IFLD bus lines match what we wrote to the the DFLD,IFLD switch flipflops
        uint16_t busdfld = getmpins (mps__DFLD) ^ 7; if (busdfld != swdfld) printf ("%8u %8u bus DFLD %o != switch DFLD %o\n", ++ errors, passes, busdfld,  swdfld);
        uint16_t busifld = getmpins (mps__IFLD) ^ 7; if (busifld != swifld) printf ("%8u %8u bus IFLD %o != switch IFLD %o\n", ++ errors, passes, busifld,  swifld);

        // release LDAD switch by writing 0 to its flipflop.  the DFLD,IFLD bus lines will no longer be driven by console board
        writerow (10, swrows[2]);           // set ldswrow2 = 0 (was 1), all row2 switches as before + SWLDAD=0
        writerow (11, swrows[2]);           // set ldswrow2 = 1, clocking all that into switch flipflops
        mcprecv ();
        if (! getmpin (mp__SWLDAD)) {       // make sure LDAD switch is off (active low)
            fprintf (stderr, "autotest: releasing LDAD did not clear LDAD switch flipflop\n");
            ABORT ();
        }
        mcpwrite16 (1, 0, 0x00, 0x3F3F);    // turn console mcp23017 data pins to inputs so they won't jam light row drivers
        writerow (3, 0);                    // switch to a light row without glitching any ldswrow line (11->3 doesn't glitch)
        justreleasedldad ();                // enable tester board mcp23017s outputting to DFLD,IFLD bus lines
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
