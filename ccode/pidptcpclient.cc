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

// runs on zynq to send lights to and receive switches from raspi plugged into pidp8i panel
// this is a different pidp8i panel than one plugged into console.kicad_sch board

//  pidptcpclient <raspihostname>

#include <signal.h>
#include <string.h>
#include <time.h>

#include "i2czlib.h"
#include "pidp.h"
#include "z8idefs.h"

// gpio pins

                    //  LR1 LR2 LR3 LR4 LR5 LR6 LR7 LR8 SR1 SR2 SR3
#define COL1    14  //  pc1 ma1 mb1 ac1 mq1 and cad df1 sw1 df1 start   [MSB]
#define COL2    15  //  pc2 ma2 mb2 ac2 mq2 tad brk df2 sw2 df2 ldaddr
#define COL3     4  //  pc3 ma3 mb3 ac3 mq3 isz ion df3 sw3 df3 dep
#define COL4     5  //   .   .   .   .   .  dca pau if1  .  if1 exam
#define COL5     6  //   .   .   .   .   .  jms run if2  .  if2 cont
#define COL6     7  //   .   .   .   .   .  jmp sc1 if3  .  if3 stop
#define COL7     8  //   .   .   .   .   .  iot sc2 lnk  .      sstep
#define COL8     9  //   .   .   .   .   .  opr sc3      .      sinst
#define COL9    10  //   .   .   .   .   .  fet sc4      .
#define COL10   11  //   .   .   .   .   .  exe sc5      .
#define COL11   12  //   .   .   .   .   .  def          .
#define COL12   13  //   .   .   .   .   .  wct          .              [LSB]

#define COLMIN 4

static bool volatile ctrlcflag;
static uint16_t ledscrams[4096];
static uint16_t opcodeleds[8];
static uint16_t swunscrams[65536>>COLMIN];

static void siginthand (int signum);

int main (int argc, char **argv)
{
    setlinebuf (stdout);

    if (argc != 2) {
        fprintf (stderr, "missing server hostname\n");
        return 1;
    }
    pidp_open (argv[1]);

    opcodeleds[0] = 1 << COL1;
    opcodeleds[1] = 1 << COL2;
    opcodeleds[2] = 1 << COL3;
    opcodeleds[3] = 1 << COL4;
    opcodeleds[4] = 1 << COL5;
    opcodeleds[5] = 1 << COL6;
    opcodeleds[6] = 1 << COL7;
    opcodeleds[7] = 1 << COL8;

    for (uint16_t data = 0; data <= 07777; data ++) {
        uint16_t gpio = 0;
        if (data & 04000) gpio |= 1 << COL1;
        if (data & 02000) gpio |= 1 << COL2;
        if (data & 01000) gpio |= 1 << COL3;
        if (data & 00400) gpio |= 1 << COL4;
        if (data & 00200) gpio |= 1 << COL5;
        if (data & 00100) gpio |= 1 << COL6;
        if (data & 00040) gpio |= 1 << COL7;
        if (data & 00020) gpio |= 1 << COL8;
        if (data & 00010) gpio |= 1 << COL9;
        if (data & 00004) gpio |= 1 << COL10;
        if (data & 00002) gpio |= 1 << COL11;
        if (data & 00001) gpio |= 1 << COL12;
        ledscrams[data] = gpio;
        swunscrams[gpio>>COLMIN] = data;
    }

    // access FPGA I2C interface to console board
    I2CZLib i2czlib;
    Z8IPanel pads;
    memset (&pads, 0, sizeof pads);

    signal (SIGINT,  siginthand);
    signal (SIGTERM, siginthand);

    i2czlib.lockpads ();

    bool firstswrow = true;
    uint16_t lastswrows[3];
    memset (lastswrows, 0, sizeof lastswrows);

    PiDPMsg pidpmsg;
    memset (&pidpmsg, 0, sizeof pidpmsg);

    while (! ctrlcflag) {

        // read lights from fpga
        i2czlib.readpads (&pads, false);
        i2czlib.unlkpads ();

        // send lights over tcp to pidp panel
        pidpmsg.ledrows[0] = ledscrams[pads.light.pc];
        pidpmsg.ledrows[1] = ledscrams[pads.light.ma];
        pidpmsg.ledrows[2] = ledscrams[pads.light.mb];
        pidpmsg.ledrows[3] = ledscrams[pads.light.ac];
        pidpmsg.ledrows[4] = ledscrams[pads.light.mq];

        pidpmsg.ledrows[5] =
            opcodeleds[pads.light.ir] |
            ((pads.light.ms == MS_FETCH) ? (1 << COL9)  : 0) |
            ((pads.light.ms == MS_EXEC)  ? (1 << COL10) : 0) |
            ((pads.light.ms == MS_DEFER) ? (1 << COL11) : 0) |
            ((pads.light.ms == MS_WRDCT) ? (1 << COL12) : 0);

        pidpmsg.ledrows[6] =
            ((pads.light.ms == MS_CURAD) ? (1 << COL1) : 0) |
            ((pads.light.ms == MS_BREAK) ? (1 << COL2) : 0) |
            (pads.light.ion ? (1 << COL3) : 0) |
            (pads.light.pau ? (1 << COL4) : 0) |
            (pads.light.run ? (1 << COL5) : 0) |
            ledscrams[pads.light.sc<<2];

        pidpmsg.ledrows[7] =
            ledscrams[(pads.light.dfld<<9)|(pads.light.ifld<<6)] |
            (pads.light.link ? (1 << COL7) : 0);

        // ... also receives switches from pidp panel
        if (! pidp_proc (&pidpmsg)) continue;

        i2czlib.lockpads ();

        // only send switches to fpga if there is a change
        // - this allows other things (like tcl scripts) to use switches
        // - and it takes over the switches only when someone is using them
        if (! firstswrow && ((pidpmsg.swrows[0] != lastswrows[0]) || (pidpmsg.swrows[1] != lastswrows[1]) || (pidpmsg.swrows[2] != lastswrows[2]))) {

            // send all switches to fpga
            pads.togval.reg = swunscrams[pidpmsg.swrows[0]>>COLMIN];
            uint32_t sr2 = swunscrams[pidpmsg.swrows[1]>>COLMIN];
            pads.togval.dfld  = (sr2 >> 9) & 7;
            pads.togval.ifld  = (sr2 >> 6) & 7;
            pads.togval.sinst = (pidpmsg.swrows[1] >> COL8) & 1;
            pads.togval.sstep = (pidpmsg.swrows[1] >> COL7) & 1;
            pads.button.stop  = (pidpmsg.swrows[2] >> COL6) & 1;
            pads.button.cont  = (pidpmsg.swrows[2] >> COL5) & 1;
            pads.button.start = (pidpmsg.swrows[2] >> COL1) & 1;
            pads.button.ldad  = (pidpmsg.swrows[2] >> COL2) & 1;
            pads.button.exam  = (pidpmsg.swrows[2] >> COL4) & 1;
            pads.button.depos = (pidpmsg.swrows[2] >> COL3) & 1;
            pads.togovr.reg   = 07777;
            pads.togovr.dfld  = 7;
            pads.togovr.ifld  = 7;
            pads.togovr.sinst = true;
            pads.togovr.sstep = true;

            uint32_t now = time (NULL);
            printf ("%02u:%02u:%02u   %o %o  %04o  %s %s %s %s %s %s %s %s\n",
                now / 3600 % 24, now / 60 % 60, now % 60,
                pads.togval.dfld, pads.togval.ifld, pads.togval.reg,
                pads.button.start ? "START" : "     ",
                pads.button.ldad  ? "LDAD"  : "    ",
                pads.button.depos ? "DEPOS" : "     ",
                pads.button.exam  ? "EXAM"  : "    ",
                pads.button.cont  ? "CONT"  : "    ",
                pads.button.stop  ? "STOP"  : "    ",
                pads.togval.sstep ? "SSTEP" : "     ",
                pads.togval.sinst ? "SINST" : "     ");

            i2czlib.writepads (&pads);
        }
        firstswrow = false;
        lastswrows[0] = pidpmsg.swrows[0];
        lastswrows[1] = pidpmsg.swrows[1];
        lastswrows[2] = pidpmsg.swrows[2];
    }

    i2czlib.unlkpads ();

    return 0;
}

static void siginthand (int signum)
{
    if (ctrlcflag) exit (1);
    ctrlcflag = true;
}
