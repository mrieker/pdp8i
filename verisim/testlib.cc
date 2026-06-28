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

// library for testing physical boards plugged into the tester
// ...that is connected to a raspi via i2c busses

#include <fcntl.h>
#include <linux/i2c.h>
#include <linux/i2c-dev.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

#include "testlib.h"

int const bits_DFLD[]   = { pin__DFLD_2,   pin__DFLD_1,   pin__DFLD_0,    0 };
int const bits_DMAFLD[] = { pin__DMAFLD_2, pin__DMAFLD_1, pin__DMAFLD_0,  0 };
int const bits_IFLD[]   = { pin__IFLD_2,   pin__IFLD_1,   pin__IFLD_0,    0 };
int const bits_IREG[]   = { pin__IREG_11,  pin__IREG_10,  pin__IREG_9,    0 };
int const bits_MEAD[]   = { pin__MEAD_2,   pin__MEAD_1,   pin__MEAD_0,    0 };

int const bits_MAJST[]  = { pin__MAJST_3, pin__MAJST_2, pin__MAJST_1, pin__MAJST_0,  0 };

int const bits_SCTR[]   = { pin__SCTR_4,  pin__SCTR_3,  pin__SCTR_2,  pin__SCTR_1,  pin__SCTR_0,  0 };

int const bits_ACUM[]   = { pin__ACUM_11,  pin__ACUM_10,  pin__ACUM_9,  pin__ACUM_8,  pin__ACUM_7,  pin__ACUM_6,  pin__ACUM_5,  pin__ACUM_4,  pin__ACUM_3,  pin__ACUM_2,  pin__ACUM_1,  pin__ACUM_0,   0 };
int const bits_INBUS[]  = { pin__INBUS_11, pin__INBUS_10, pin__INBUS_9, pin__INBUS_8, pin__INBUS_7, pin__INBUS_6, pin__INBUS_5, pin__INBUS_4, pin__INBUS_3, pin__INBUS_2, pin__INBUS_1, pin__INBUS_0,  0 };
int const bits_MADR[]   = { pin__MADR_11,  pin__MADR_10,  pin__MADR_9,  pin__MADR_8,  pin__MADR_7,  pin__MADR_6,  pin__MADR_5,  pin__MADR_4,  pin__MADR_3,  pin__MADR_2,  pin__MADR_1,  pin__MADR_0,   0 };
int const bits_MBUF[]   = { pin__MBUF_11,  pin__MBUF_10,  pin__MBUF_9,  pin__MBUF_8,  pin__MBUF_7,  pin__MBUF_6,  pin__MBUF_5,  pin__MBUF_4,  pin__MBUF_3,  pin__MBUF_2,  pin__MBUF_1,  pin__MBUF_0,   0 };
int const bits_MQUO[]   = { pin__MQUO_11,  pin__MQUO_10,  pin__MQUO_9,  pin__MQUO_8,  pin__MQUO_7,  pin__MQUO_6,  pin__MQUO_5,  pin__MQUO_4,  pin__MQUO_3,  pin__MQUO_2,  pin__MQUO_1,  pin__MQUO_0,   0 };
int const bits_PCTR[]   = { pin__PCTR_11,  pin__PCTR_10,  pin__PCTR_9,  pin__PCTR_8,  pin__PCTR_7,  pin__PCTR_6,  pin__PCTR_5,  pin__PCTR_4,  pin__PCTR_3,  pin__PCTR_2,  pin__PCTR_1,  pin__PCTR_0,   0 };

int const procalu_ipins[] = {
    pin__ACCLEAR,
    pin__ACUM_0,
    pin__ACUM_1,
    pin__ACUM_10,
    pin__ACUM_11,
    pin__ACUM_2,
    pin__ACUM_3,
    pin__ACUM_4,
    pin__ACUM_5,
    pin__ACUM_6,
    pin__ACUM_7,
    pin__ACUM_8,
    pin__ACUM_9,
    pin__BRKWRM,
    pin__CAINC,
    pin__CYCLE3,
    pin__INBUS_0,
    pin__INBUS_1,
    pin__INBUS_10,
    pin__INBUS_11,
    pin__INBUS_2,
    pin__INBUS_3,
    pin__INBUS_4,
    pin__INBUS_5,
    pin__INBUS_6,
    pin__INBUS_7,
    pin__INBUS_8,
    pin__INBUS_9,
    pin__IOP,
    pin__IREG_10,
    pin__IREG_11,
    pin__IREG_9,
    pin__LINK,
    pin__MADR_0,
    pin__MADR_1,
    pin__MADR_10,
    pin__MADR_11,
    pin__MADR_2,
    pin__MADR_3,
    pin__MADR_4,
    pin__MADR_5,
    pin__MADR_6,
    pin__MADR_7,
    pin__MADR_8,
    pin__MADR_9,
    pin__MAJST_0,
    pin__MAJST_1,
    pin__MAJST_2,
    pin__MAJST_3,
    pin__MBUF_0,
    pin__MBUF_1,
    pin__MBUF_10,
    pin__MBUF_11,
    pin__MBUF_2,
    pin__MBUF_3,
    pin__MBUF_4,
    pin__MBUF_5,
    pin__MBUF_6,
    pin__MBUF_7,
    pin__MBUF_8,
    pin__MBUF_9,
    pin__PCTR_0,
    pin__PCTR_1,
    pin__PCTR_10,
    pin__PCTR_11,
    pin__PCTR_2,
    pin__PCTR_3,
    pin__PCTR_4,
    pin__PCTR_5,
    pin__PCTR_6,
    pin__PCTR_7,
    pin__PCTR_8,
    pin__PCTR_9,
    pin__SWCONT,
    pin__SWDEPOS,
    pin__SWEXAM,
    pin__SWLDAD,
    pin__SWSTART,
    pin__TS1,
    pin__TS2,
    pin__TS3,
    pin__TS4,
    pin_nxtms_0,
    pin_nxtms_1,
    pin_nxtms_2,
    pin_nxtms_3,
    pin__READSR,
    0
};

int const procalu_opins[] = {
    pin__READSR,
    pin_aluq_0,
    pin_aluq_1,
    pin_aluq_10,
    pin_aluq_11,
    pin_aluq_2,
    pin_aluq_3,
    pin_aluq_4,
    pin_aluq_5,
    pin_aluq_6,
    pin_aluq_7,
    pin_aluq_8,
    pin_aluq_9,
    pin_cout,
    0
};

int i2cfds[2];
uint16_t mcppins[NMCPWORDS];
uint16_t boardipinmask[NMCPWORDS];  // mask of pins going in board (coming out mcps)
uint16_t boardopinmask[NMCPWORDS];  // mask of pins coming out board (going in mcps)

// fill boardipinmask or boardopinmask with list of pins
// call this prior to i2copen() so i2copen() can set mcp pin directions
void fillmaskarray (uint16_t *maskarray, int const *pins)
{
    for (int pin; (pin = *pins) != 0; pins ++) {
        int addr = (pin >> 6) & 31;
        uint16_t mask = 1U << (pin & 15);
        mcppins[addr-8] |= mask;
    }
}

// send pin values in mcppins out to the board being tested
void mcpsend ()
{
    // send random bits to physical board via i2c bus
    for (int bus = 0; bus < 2; bus ++) {
        for (int chip = 0; chip < 8; chip ++) {
            if (boardipinmask[bus*8+chip] != 0) {
                i2cwrite16 (i2cfds[bus], chip, 0x14, mcppins[bus*8+chip]);
            }
        }
    }
}

// read pin values into mcppins from the board being tested
void mcprecv ()
{
    // receive reply from physical board via i2c bus
    for (int bus = 0; bus < 2; bus ++) {
        for (int chip = 0; chip < 8; chip ++) {
            if (boardopinmask[bus*8+chip] != 0) {
                mcppins[bus*8+chip] = i2cread16 (i2cfds[bus], chip, 0x12);
            }
        }
    }
}

// set pin value ready to go to physical board via i2c bus
void setpin (int pin, uint32_t val)
{
    int addr = (pin >> 6) & 31;
    uint16_t mask = 1U << (pin & 15);
    if (val & 1) mcppins[addr-8] |= mask;
          else mcppins[addr-8] &= ~ mask;
}

// get pin value from physical board via i2c bus
uint32_t getpin (int pin)
{
    int addr = (pin >> 6) & 31;
    uint16_t word = mcppins[addr-8];
    return (word >> (pin & 15)) & 1;
}

// get some pseudo-random bits
uint32_t randbits (int nbits)
{
    static uint64_t seed = 0x123456789ABCDEF0ULL;

    uint32_t randval = 0;

    while (-- nbits >= 0) {

        // https://www.xilinx.com/support/documentation/application_notes/xapp052.pdf
        uint64_t xnor = ~ ((seed >> 63) ^ (seed >> 62) ^ (seed >> 60) ^ (seed >> 59));
        seed = (seed << 1) | (xnor & 1);

        randval += randval + (seed & 1);
    }

    return randval;
}

// open i2c busses and set mcp device pin directions
void i2copen ()
{
    // bus connected to chips U10..U14
    i2cfds[0] = open ("/dev/i2c-1", O_RDWR);
    if (i2cfds[0] < 0) {
        fprintf (stderr, "error opening /dev/i2c-1: %m\n");
        ABORT ();
    }

    // bus connected to chips U21..U25
    i2cfds[1] = open ("/dev/i2c-2", O_RDWR);
    if (i2cfds[1] < 0) {
        fprintf (stderr, "error opening /dev/i2c-2: %m\n");
        ABORT ();
    }

    // inputs to the board are outputs from the mcps
    // set output mode for inputs to board, all else are inputs to mcp
    for (int bus = 0; bus < 2; bus ++) {
        for (int chip = bus; chip < bus + 5; chip ++) {
            i2cwrite16 (i2cfds[bus], chip, 0x00, ~ boardipinmask[bus*8+chip]);
        }
    }
}

// write word to mcp23017 via raspi i2c bus
//  input:
//   i2cfd = fd of /dev/i2c-n device
//   chip = chip number 0..7
//   regno = even register number
//   data<07:00> = value to write to even register
//   data<15:08> = value to write to odd register
//  output:
//   data written to chip
void i2cwrite16 (int i2cfd, uint8_t chip, uint8_t regno, uint16_t data)
{
    struct i2c_rdwr_ioctl_data msgset;
    struct i2c_msg iomsgs[1];
    uint8_t buf[3];

    memset (&msgset, 0, sizeof msgset);
    memset (iomsgs, 0, sizeof iomsgs);

    buf[0] = regno;             // MCP23017 register number
    buf[1] = data;              // byte for reg+0
    buf[2] = data >> 8;         // byte for reg+1

    iomsgs[0].addr  = MCPI2CBA + chip;
    iomsgs[0].flags = 0;        // write
    iomsgs[0].buf   = buf;
    iomsgs[0].len   = 3;

    msgset.msgs  = iomsgs;
    msgset.nmsgs = 1;

    int rc = ioctl (i2cfd, I2C_RDWR, &msgset);
    if (rc < 0) {
        fprintf (stderr, "i2cwrite16: error writing to %02X.%02X: %m\n", chip, regno);
        ABORT ();
    }
}

// read word from mcp23017 via raspi i2c bus
//  input:
//   i2cfd = fd of /dev/i2c-n device
//   chip = chip number 0..7
//   regno = even register number
//  output:
//   returns data<07:00> = value read from even register
//           data<15:08> = value read from odd register
uint16_t i2cread16 (int i2cfd, uint8_t chip, uint8_t regno)
{
    struct i2c_rdwr_ioctl_data msgset;
    struct i2c_msg iomsgs[2];
    uint8_t wbuf[1], rbuf[2];

    memset (&msgset, 0, sizeof msgset);
    memset (iomsgs, 0, sizeof iomsgs);

    for (int retry = 0; retry < 3; retry ++) {
        wbuf[0] = regno;            // MCP23017 register number
        iomsgs[0].addr  = MCPI2CBA + chip;
        iomsgs[0].flags = 0;        // write
        iomsgs[0].buf   = wbuf;
        iomsgs[0].len   = 1;

        iomsgs[1].addr  = chip;
        iomsgs[1].flags = I2C_M_RD; // read
        iomsgs[1].buf   = rbuf;
        iomsgs[1].len   = 2;

        msgset.msgs = iomsgs;
        msgset.nmsgs = 2;

        int rc = ioctl (i2cfd, I2C_RDWR, &msgset);
        if (rc >= 0) {
            if (retry > 0) fprintf (stderr, "i2cread16: reading recovered\n");
            // reg+1 in upper byte; reg+0 in lower byte
            return (rbuf[1] << 8) | rbuf[0];
        }

        fprintf (stderr, "i2cread16: error reading from %02X.%02X: %m\n", chip, regno);
    }
    ABORT ();
}
