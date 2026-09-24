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

// Access the pidp-8 panel lights and switches via I2C bus to MCP23017 on console board
// z8ipanel.cc -> i2czlib.cc -> pdp8ifpi2c.v -> i2cmaster.v -> i2c -> console.kicad_sch -> mcp23017 -> gpio connector -> lights & switches

#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "i2czlib.h"
#include "z8idefs.h"

I2CZLib::I2CZLib ()
{
    pdpat = z8ipage.findev ("8I", NULL, NULL, false);   // zynq.v registers
    fpat  = z8ipage.findev ("FP", NULL, NULL, false);   // pdp8ifpi2c.v registers
    mypid = getpid ();
    pthread_mutex_init (&mutex, NULL);
}

I2CZLib::~I2CZLib ()
{
    pdpat = NULL;
    fpat  = NULL;
}

// get exclusive access to pdp8ifpi2c.v registers
void I2CZLib::lockpads ()
{
    pthread_mutex_lock (&mutex);
    ASSERT (FP6_LOCK == 0xFFFFFFFFU);
    while (true) {
        fpat[6] = mypid;
        uint32_t lkpid = fpat[6];
        if (lkpid == mypid) break;
        if ((lkpid > 0) && (kill (lkpid, 0) < 0) && (errno == ESRCH)) {
            fprintf (stderr, "I2CZLib::lockpads: unlocking from dead pid %u\n", lkpid);
            fpat[6] = lkpid;
            usleep (123456);
        } else {
            usleep (456);
        }
    }
}

// release exclusive access
void I2CZLib::unlkpads ()
{
    ASSERT (FP6_LOCK == 0xFFFFFFFFU);
    if (fpat[6] != mypid) ABORT ();
    fpat[6] = mypid;
    pthread_mutex_unlock (&mutex);
}

// read light bulbs and switches
// pdp8ifpi2c.v is continuously scanning the lights and switches
//  and updating fpat[8,9,10,11,12] registers
void I2CZLib::readpads (Z8IPanel *pads, bool wait)
{
    if (wait) waitpass ();

    memset (pads, 0, sizeof *pads);

    uint32_t fp8  = fpat[8];
    uint32_t fp9  = fpat[9];
    uint32_t fp10 = fpat[10];
    uint32_t fp11 = fpat[11];
    uint32_t fp12 = fpat[12];

    pads->light.pc = EXT (fp8, fp8_lbPC);
    pads->light.ma = EXT (fp8, fp8_lbMA);

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
    pads->light.ms     = EXT (fp10, fp10_lbMS);
    pads->light.link   = EXT (fp10, fp10_lbLINK);
    pads->light.ifld   = EXT (fp10, fp10_lbIF);
    pads->light.dfld   = EXT (fp10, fp10_lbDF);

    // buttons: logical OR of physical switch and value sent by writepads()
    pads->button.stop  = EXT (fp11, fp11_swSTOP);
    pads->button.cont  = EXT (fp11, fp11_swCONT);
    pads->button.start = EXT (fp11, fp11_swSTART);
    pads->button.ldad  = EXT (fp11, fp11_swLDAD);
    pads->button.exam  = EXT (fp11, fp11_swEXAM);
    pads->button.depos = EXT (fp11, fp11_swDEPOS);

    // toggle switch values
    pads->togval.reg   = EXT (fp11, fp11_swREG);
    pads->togval.dfld  = EXT (fp11, fp11_swDFLD);
    pads->togval.ifld  = EXT (fp11, fp11_swIFLD);
    pads->togval.sinst = EXT (fp11, fp11_swSINST);
    pads->togval.sstep = EXT (fp11, fp11_swSSTEP);

    // ovr=0: physical switch
    //     1: as overidden by writepads()
    pads->togovr.reg   = EXT (fp12, fp11_swREG);
    pads->togovr.dfld  = EXT (fp12, fp11_swDFLD);
    pads->togovr.ifld  = EXT (fp12, fp11_swIFLD);
    pads->togovr.sinst = EXT (fp12, fp11_swSINST);
    pads->togovr.sstep = EXT (fp12, fp11_swSSTEP);
}

// write overidden switches
// pdp8ifpi2c.v is continuously reading fpat[11,12] registers
//  and passing them to the console board via i2c
void I2CZLib::writepads (Z8IPanel const *pads)
{
    // enable which bits are being sent out
    // - buttons need to be sent out only when pressed
    //   if released, resorts to what physical button is
    // - toggles are sent when explicitly enabled
    fpat[12] =
        (pads->button.stop  ? fp11_swSTOP  : 0) |
        (pads->button.cont  ? fp11_swCONT  : 0) |
        (pads->button.start ? fp11_swSTART : 0) |
        (pads->button.ldad  ? fp11_swLDAD  : 0) |
        (pads->button.exam  ? fp11_swEXAM  : 0) |
        (pads->button.depos ? fp11_swDEPOS : 0) |
        (pads->togovr.sinst ? fp11_swSINST : 0) |
        (pads->togovr.sstep ? fp11_swSSTEP : 0) |
        INS (pads->togovr.dfld, fp11_swDFLD) |
        INS (pads->togovr.ifld, fp11_swIFLD) |
        INS (pads->togovr.reg,  fp11_swREG);

    // pdp8ifpi2c.v won't update fpat[11] bits from physical switches what have corresponding fpat[12] bit set
    // otherwise it will periodically load fpat[11] bits from physical switches and ignore writes from the arm

    // set up values to be sent out
    fpat[11] =
        (pads->button.stop  ? fp11_swSTOP  : 0) |
        (pads->button.cont  ? fp11_swCONT  : 0) |
        (pads->button.start ? fp11_swSTART : 0) |
        (pads->button.ldad  ? fp11_swLDAD  : 0) |
        (pads->button.exam  ? fp11_swEXAM  : 0) |
        (pads->button.depos ? fp11_swDEPOS : 0) |
        (pads->togval.sinst ? fp11_swSINST : 0) |
        (pads->togval.sstep ? fp11_swSSTEP : 0) |
        INS (pads->togval.dfld, fp11_swDFLD) |
        INS (pads->togval.ifld, fp11_swIFLD) |
        INS (pads->togval.reg,  fp11_swREG);

    // wait for them to get all clocked in
    waitpass ();
}

// waits for an whole pass through all the rows
void I2CZLib::waitpass ()
{
    ASSERT (fp7_mcpassno == 0xFFFFFE00U);
    ASSERT (fp7_mcpltrow == 0x000001C0U);
    uint32_t begnum = fpat[7] & 0xFFFFFFC0U;    // pass,ltrow
    uint32_t begzrh = pdpat[Z_RH];              // 100MHz
    while (true) {
        uint32_t nowzrh = pdpat[Z_RH];
        uint32_t nownum = fpat[7] & 0xFFFFFFC0U;
        if (nownum - begnum > 0x200U) break;
        if (nowzrh - begzrh > 3300000) {        // 31.5mS with i2c,ltspeed at slowest
            if (fpat[5] & FP5_MANUAL) {
                fprintf (stderr, "I2CZLib::waitpass: fpi2c in manual\n");
            } else {
                fprintf (stderr, "I2CZLib::waitpass: timed out\n");
            }
            ABORT ();
        }
        usleep (345);
    }
}
