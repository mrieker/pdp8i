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

// test physical procalu board
// runs on raspi plugged into tester board with physical procalu board plugged in

// sends random numbers to the board then compares with verilator equivalent

#include <errno.h>
#include <fcntl.h>
#include <linux/i2c.h>
#include <linux/i2c-dev.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

#include "testlib.h"
#include "veriprocalu/Vprocalu.h"

#define SETBIT(b,v) do { uint32_t _v = v; setpin (pin_##b, _v); vpralu.b = _v; } while (0)
#define CHKBIT(b) do { uint32_t _vis = getpin (pin_##b); uint32_t _vsb = vpralu.b; if (_vis != _vsb) badpin (#b, _vis, _vsb); } while (0)

static bool error;

static void badpin (char const *pin, uint32_t is, uint32_t sb);

int main ()
{
    // access C equivalent of procalu board
    Vprocalu vpralu;

    // make masks of input and output pins so we know what words to send/receive on i2c busses
    fillmaskarray (boardipinmask, procalu_ipins);
    fillmaskarray (boardopinmask, procalu_opins);

    // access physical procalu board
    i2copen ();

    do {

        // generate random inputs to procalu board
        SETBIT (_ACCLEAR,  randbits (1));
        SETBIT (_ACUM_0,   randbits (1));
        SETBIT (_ACUM_1,   randbits (1));
        SETBIT (_ACUM_10,  randbits (1));
        SETBIT (_ACUM_11,  randbits (1));
        SETBIT (_ACUM_2,   randbits (1));
        SETBIT (_ACUM_3,   randbits (1));
        SETBIT (_ACUM_4,   randbits (1));
        SETBIT (_ACUM_5,   randbits (1));
        SETBIT (_ACUM_6,   randbits (1));
        SETBIT (_ACUM_7,   randbits (1));
        SETBIT (_ACUM_8,   randbits (1));
        SETBIT (_ACUM_9,   randbits (1));
        SETBIT (_BRKWRM,   randbits (1));
        SETBIT (_CAINC,    randbits (1));
        SETBIT (_CYCLE3,   randbits (1));
        SETBIT (_INBUS_0,  randbits (1));
        SETBIT (_INBUS_1,  randbits (1));
        SETBIT (_INBUS_10, randbits (1));
        SETBIT (_INBUS_11, randbits (1));
        SETBIT (_INBUS_2,  randbits (1));
        SETBIT (_INBUS_3,  randbits (1));
        SETBIT (_INBUS_4,  randbits (1));
        SETBIT (_INBUS_5,  randbits (1));
        SETBIT (_INBUS_6,  randbits (1));
        SETBIT (_INBUS_7,  randbits (1));
        SETBIT (_INBUS_8,  randbits (1));
        SETBIT (_INBUS_9,  randbits (1));
        SETBIT (_IOP,      randbits (1));
        SETBIT (_IREG_10,  randbits (1));
        SETBIT (_IREG_11,  randbits (1));
        SETBIT (_IREG_9,   randbits (1));
        SETBIT (_LINK,     randbits (1));
        SETBIT (_MADR_0,   randbits (1));
        SETBIT (_MADR_1,   randbits (1));
        SETBIT (_MADR_10,  randbits (1));
        SETBIT (_MADR_11,  randbits (1));
        SETBIT (_MADR_2,   randbits (1));
        SETBIT (_MADR_3,   randbits (1));
        SETBIT (_MADR_4,   randbits (1));
        SETBIT (_MADR_5,   randbits (1));
        SETBIT (_MADR_6,   randbits (1));
        SETBIT (_MADR_7,   randbits (1));
        SETBIT (_MADR_8,   randbits (1));
        SETBIT (_MADR_9,   randbits (1));
        SETBIT (_MAJST_0,  randbits (1));
        SETBIT (_MAJST_1,  randbits (1));
        SETBIT (_MAJST_2,  randbits (1));
        SETBIT (_MAJST_3,  randbits (1));
        SETBIT (_MBUF_0,   randbits (1));
        SETBIT (_MBUF_1,   randbits (1));
        SETBIT (_MBUF_10,  randbits (1));
        SETBIT (_MBUF_11,  randbits (1));
        SETBIT (_MBUF_2,   randbits (1));
        SETBIT (_MBUF_3,   randbits (1));
        SETBIT (_MBUF_4,   randbits (1));
        SETBIT (_MBUF_5,   randbits (1));
        SETBIT (_MBUF_6,   randbits (1));
        SETBIT (_MBUF_7,   randbits (1));
        SETBIT (_MBUF_8,   randbits (1));
        SETBIT (_MBUF_9,   randbits (1));
        SETBIT (_PCTR_0,   randbits (1));
        SETBIT (_PCTR_1,   randbits (1));
        SETBIT (_PCTR_10,  randbits (1));
        SETBIT (_PCTR_11,  randbits (1));
        SETBIT (_PCTR_2,   randbits (1));
        SETBIT (_PCTR_3,   randbits (1));
        SETBIT (_PCTR_4,   randbits (1));
        SETBIT (_PCTR_5,   randbits (1));
        SETBIT (_PCTR_6,   randbits (1));
        SETBIT (_PCTR_7,   randbits (1));
        SETBIT (_PCTR_8,   randbits (1));
        SETBIT (_PCTR_9,   randbits (1));
        SETBIT (_SWCONT,   randbits (1));
        SETBIT (_SWDEPOS,  randbits (1));
        SETBIT (_SWEXAM,   randbits (1));
        SETBIT (_SWLDAD,   randbits (1));
        SETBIT (_SWSTART,  randbits (1));
        SETBIT (_TS1,      randbits (1));
        SETBIT (_TS2,      randbits (1));
        SETBIT (_TS3,      randbits (1));
        SETBIT (_TS4,      randbits (1));
        SETBIT (nxtms_0,   randbits (1));
        SETBIT (nxtms_1,   randbits (1));
        SETBIT (nxtms_2,   randbits (1));
        SETBIT (nxtms_3,   randbits (1));
        SETBIT (_READSR,   randbits (1));

        // send random bits to physical board via i2c bus
        mcpsend ();

        // send random bits to verilog then compute reply
        // clock it through 500nS of chips-varns.v delays
        for (int i = 0; i < 100; i ++) {
            vpralu.eval ();
            vpralu.zclock = 1;
            vpralu.eval ();
            vpralu.zclock = 0;
        }

        // receive reply from physical board via i2c bus
        mcprecv ();

        // compare to make sure the replies are the same
        CHKBIT (_READSR);
        CHKBIT (aluq_0);
        CHKBIT (aluq_1);
        CHKBIT (aluq_10);
        CHKBIT (aluq_11);
        CHKBIT (aluq_2);
        CHKBIT (aluq_3);
        CHKBIT (aluq_4);
        CHKBIT (aluq_5);
        CHKBIT (aluq_6);
        CHKBIT (aluq_7);
        CHKBIT (aluq_8);
        CHKBIT (aluq_9);
        CHKBIT (cout);

        // stop if error
    } while (! error);

    return 0;
}

// print error message then set error flag
static void badpin (char const *pin, uint32_t is, uint32_t sb)
{
    fprintf (stderr, "pin %s is %u, should be %u\n", pin, is, sb);
    error = true;
}
