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

// Access the front panel lights and switches via I2C bus to PCB3 piggy-backed on backplane
// z8lpanel.cc -> i2czlib.cc -> pdp8lfpi2c.v -> i2cmaster.v -> i2c -> pcb3 -> mcp23017s -> lights & switches

#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "i2czlib.h"
#include "z8ldefs.h"

I2CZLib::I2CZLib ()
{
    z8p   = NULL;
    pdpat = NULL;
    fpat  = NULL;

    z8p   = new Z8LPage ();
    pdpat = z8p->findev ("8I", NULL, NULL, false);
    fpat  = z8p->findev ("FP", NULL, NULL, false);
}

I2CZLib::~I2CZLib ()
{
    if (z8p != NULL) {
        delete z8p;
    }
    z8p   = NULL;
    pdpat = NULL;
    fpat  = NULL;
}

void I2CZLib::openpads (bool real, bool sim)
{
    if (real) pdpat[Z_RE] &= ~ e_simit;
    if (sim)  pdpat[Z_RE] |=   e_simit;
}

// deposit 05252: jmp 05252 in memory then start it
void I2CZLib::loop52 ()
{
    // make sure processor halted
    Z8LPanel pads;
    for (int i = 0; i < 10; i ++) {
        this->readpads (&pads);
        if (! pads.light.run) goto halted;
        pads.togovr.sinst = true;
        pads.togval.sinst = true;
        this->writepads (&pads);
        usleep (200000);
    }
    fprintf (stderr, "I2CZLib::loop52: processor would not halt\n");
    fprintf (stderr, "I2CZLib::loop52: try ./z8lpanel hardreset\n");
    ABORT ();
halted:;

    // set switch register to 5252, all others to 0
    memset (&pads.togovr, -1, sizeof pads.togovr);
    pads.togval.sr = DOTJMPDOT;
    pads.togval.sinst = false;
    this->writepads (&pads);

    // load address
    pads.button.ldad = true;
    this->writepads (&pads);
    usleep (200000);
    pads.button.ldad = false;
    this->writepads (&pads);
    usleep (200000);

    // deposit
    pads.button.dep = true;
    this->writepads (&pads);
    usleep (200000);
    pads.button.dep = false;
    this->writepads (&pads);
    usleep (200000);

    // load address
    pads.button.ldad = true;
    this->writepads (&pads);
    usleep (200000);
    pads.button.ldad = false;
    this->writepads (&pads);
    usleep (200000);

    // start
    pads.button.start = true;
    this->writepads (&pads);
    usleep (200000);
    pads.button.start = false;
    this->writepads (&pads);
    usleep (200000);

    // see if that worked
    this->readpads (&pads);
    if (! pads.light.run || (pads.light.ma != DOTJMPDOT) || (pads.light.mb != DOTJMPDOT)) {
        fprintf (stderr, "I2CZLib::loop52: processor did not start (run=%o ma=%04o mb=%04o)\n",
            pads.light.run, pads.light.ma, pads.light.mb);
        ABORT ();
    }

    // release all switches
    this->relall ();
}

// release our override of all switches
void I2CZLib::relall ()
{
    Z8LPanel pads;
    memset (&pads, 0, sizeof pads);
    writepads (&pads);
}

// read light bulbs and switches
// pdp8ifpi2c.v is continuously scanning the lights and switches
//  and updating fpat[8,9,10,11,12] registers
void I2CZLib::readpads (Z8LPanel *pads)
{
    memset (pads, 0, sizeof *pads);

    uint32_t fp8  = fpat[8];
    uint32_t fp9  = fpat[9];
    uint32_t fp10 = fpat[10];
    uint32_t fp11 = fpat[11];
    uint32_t fp12 = fpat[12];

    pads->light.pc = EXT (fp8, fp8_lbPC);
    pads->light.ma = EXT (fp8, fp8_lbMA);

    if (EXT (fp8, fp8_lbFET)) pads->light.ms |= MS_FETCH;
    if (EXT (fp8, fp8_lbDEF)) pads->light.ms |= MS_DEFER;
    if (EXT (fp8, fp8_lbEXE)) pads->light.ms |= MS_EXEC;
    if (EXT (fp8, fp8_lbWCT)) pads->light.ms |= MS_WRDCT;
    if (EXT (fp8, fp8_lbCAD)) pads->light.ms |= MS_CURAD;
    if (EXT (fp8, fp8_lbBRK)) pads->light.ms |= MS_BREAK;

    pads->light.mb = EXT (fp9, fp9_lbMB);
    pads->light.ac = EXT (fp9, fp9_lbAC);

    if (EXT (fp9, fp9_lbAND)) pads->light.ir |= 0;
    if (EXT (fp9, fp9_lbTAD)) pads->light.ir |= 1;
    if (EXT (fp9, fp9_lbISZ)) pads->light.ir |= 2;
    if (EXT (fp9, fp9_lbDCA)) pads->light.ir |= 3;
    if (EXT (fp9, fp9_lbJMS)) pads->light.ir |= 4;
    if (EXT (fp9, fp9_lbJMP)) pads->light.ir |= 5;
    if (EXT (fp9, fp9_lbIOT)) pads->light.ir |= 6;
    if (EXT (fp9, fp9_lbOPR)) pads->light.ir |= 7;

    pads->light.mq     = EXT (fp10, fp10_lbMQ);
    pads->light.sc     = EXT (fp10, fp10_lbSC);
    pads->light.run    = EXT (fp10, fp10_lbRUN);
    pads->light.pau    = EXT (fp10, fp10_lbPAU);
    pads->light.ion    = EXT (fp10, fp10_lbION);
    pads->light.link   = EXT (fp10, fp10_lbLINK);
    pads->light.ifld   = EXT (fp10, fp10_lbIF);
    pads->light.dfld   = EXT (fp10, fp10_lbDF);

    pads->button.cont  = EXT (fp11, fp11_swCONT);
    pads->button.start = EXT (fp11, fp11_swSTART);
    pads->button.ldad  = EXT (fp11, fp11_swLDAD);
    pads->button.exam  = EXT (fp11, fp11_swEXAM);
    pads->button.dep   = EXT (fp11, fp11_swDEPOS);

    pads->togval.sr    = EXT (fp11, fp11_swSR);
    pads->togval.dfld  = EXT (fp11, fp11_swDFLD);
    pads->togval.ifld  = EXT (fp11, fp11_swIFLD);
    pads->togval.sinst = EXT (fp11, fp11_swSINST);
    pads->togval.sstep = EXT (fp11, fp11_swSSTEP);

    pads->togovr.sr    = EXT (fp12, fp11_swSR);
    pads->togovr.dfld  = EXT (fp12, fp11_swDFLD);
    pads->togovr.ifld  = EXT (fp12, fp11_swIFLD);
    pads->togovr.sinst = EXT (fp12, fp11_swSINST);
    pads->togovr.sstep = EXT (fp12, fp11_swSSTEP);
}

// write overidden switches
// pdp8ifpi2c.v is continuously reading fpat[11,12] registers
//  and passing them to the console board via i2c
void I2CZLib::writepads (Z8LPanel const *pads)
{
    // enable which bits are being sent out
    // - buttons need to be sent out only when pressed
    //   if released, resorts to what physical button is
    // - toggles are sent when explicitly enabled
    fpat[12] =
        (pads->button.cont  ? fp11_swCONT  : 0) |
        (pads->button.start ? fp11_swSTART : 0) |
        (pads->button.ldad  ? fp11_swLDAD  : 0) |
        (pads->button.exam  ? fp11_swEXAM  : 0) |
        (pads->button.dep   ? fp11_swDEPOS : 0) |
        (pads->togovr.sinst ? fp11_swSINST : 0) |
        (pads->togovr.sstep ? fp11_swSSTEP : 0) |
        INS (pads->togovr.dfld, fp11_swDFLD) |
        INS (pads->togovr.ifld, fp11_swIFLD) |
        INS (pads->togovr.sr,   fp11_swSR);

    // pdp8ifpi2c.v won't change any fpat[11] bits what have corresponding fpat[12] bit set
    // otherwise it will occasionally load fpat[11] bits from physical switches and ignore writes from the arm

    // set up values to be sent out
    fpat[11] =
        (pads->button.cont  ? fp11_swCONT  : 0) |
        (pads->button.start ? fp11_swSTART : 0) |
        (pads->button.ldad  ? fp11_swLDAD  : 0) |
        (pads->button.exam  ? fp11_swEXAM  : 0) |
        (pads->button.dep   ? fp11_swDEPOS : 0) |
        (pads->togval.sinst ? fp11_swSINST : 0) |
        (pads->togval.sstep ? fp11_swSSTEP : 0) |
        INS (pads->togval.dfld, fp11_swDFLD) |
        INS (pads->togval.ifld, fp11_swIFLD) |
        INS (pads->togval.sr,   fp11_swSR);

    // wait for them to get all clocked in
    // waits for an whole pass through all the rows
    ASSERT (fp7_mcpassno == 0xFFFFFE00U);
    ASSERT (fp7_mcpltrow == 0x000001C0U);
    uint32_t begnum = fpat[7] & 0xFFFFFFC0U;
    uint32_t nownum;
    uint32_t zrh = pdpat[Z_RH];
    do {
        if (pdpat[Z_RH] - zrh > 1000000) {  // give it 10mS
            fprintf (stderr, "I2CZLib::writepads: timed out\n");
            ABORT ();   // should take 1.68mS
        }
        usleep (345);
        nownum = fpat[7] & 0xFFFFFFC0U;
    } while (nownum - begnum <= 0x200U);
}
