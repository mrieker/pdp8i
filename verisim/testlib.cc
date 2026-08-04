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
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "i2cmaster.h"

#include "testlib.h"

#define _TESTLIB_CC
#include "testerdefs.h"

int const mps__DFLD[]   = { mp__DFLD_2,   mp__DFLD_1,   mp__DFLD_0,    0 };
int const mps__DMAFLD[] = { mp__DMAFLD_2, mp__DMAFLD_1, mp__DMAFLD_0,  0 };
int const mps__IFLD[]   = { mp__IFLD_2,   mp__IFLD_1,   mp__IFLD_0,    0 };
int const mps__IREG[]   = { mp__IREG_11,  mp__IREG_10,  mp__IREG_9,    0 };
int const mps__MEAD[]   = { mp__MEAD_2,   mp__MEAD_1,   mp__MEAD_0,    0 };

int const mps__MAJST[]  = { mp__MAJST_3, mp__MAJST_2, mp__MAJST_1, mp__MAJST_0, 0 };

int const mps__SCTR[]   = { mp__SCTR_4,  mp__SCTR_3,  mp__SCTR_2,  mp__SCTR_1,  mp__SCTR_0,  0 };

int const mps__ACUM[]   = { mp__ACUM_11,  mp__ACUM_10,  mp__ACUM_9,  mp__ACUM_8,  mp__ACUM_7,  mp__ACUM_6,  mp__ACUM_5,  mp__ACUM_4,  mp__ACUM_3,  mp__ACUM_2,  mp__ACUM_1,  mp__ACUM_0,   0 };
int const mps__INBUS[]  = { mp__INBUS_11, mp__INBUS_10, mp__INBUS_9, mp__INBUS_8, mp__INBUS_7, mp__INBUS_6, mp__INBUS_5, mp__INBUS_4, mp__INBUS_3, mp__INBUS_2, mp__INBUS_1, mp__INBUS_0,  0 };
int const mps__MADR[]   = { mp__MADR_11,  mp__MADR_10,  mp__MADR_9,  mp__MADR_8,  mp__MADR_7,  mp__MADR_6,  mp__MADR_5,  mp__MADR_4,  mp__MADR_3,  mp__MADR_2,  mp__MADR_1,  mp__MADR_0,   0 };
int const mps__MBUF[]   = { mp__MBUF_11,  mp__MBUF_10,  mp__MBUF_9,  mp__MBUF_8,  mp__MBUF_7,  mp__MBUF_6,  mp__MBUF_5,  mp__MBUF_4,  mp__MBUF_3,  mp__MBUF_2,  mp__MBUF_1,  mp__MBUF_0,   0 };
int const mps__MQUO[]   = { mp__MQUO_11,  mp__MQUO_10,  mp__MQUO_9,  mp__MQUO_8,  mp__MQUO_7,  mp__MQUO_6,  mp__MQUO_5,  mp__MQUO_4,  mp__MQUO_3,  mp__MQUO_2,  mp__MQUO_1,  mp__MQUO_0,   0 };
int const mps__PCTR[]   = { mp__PCTR_11,  mp__PCTR_10,  mp__PCTR_9,  mp__PCTR_8,  mp__PCTR_7,  mp__PCTR_6,  mp__PCTR_5,  mp__PCTR_4,  mp__PCTR_3,  mp__PCTR_2,  mp__PCTR_1,  mp__PCTR_0,   0 };

uint16_t mcppins[NMCPWORDS];        // [0]=U10; [1]=U11; ...; [9]=U21; ...
uint16_t boardipinmask[NMCPWORDS];  // mask of pins going in board (coming out mcps)
uint16_t boardopinmask[NMCPWORDS];  // mask of pins coming out board (going in mcps)

// fill boardipinmask or boardopinmask with list of pins
// call this prior to mcpsetdir() so mcpsetdir() can set mcp pin directions
void setmpinmask (uint16_t *maskarray, int const *mpins)
{
    for (int mpin; (mpin = *mpins) != 0; mpins ++) {
        int addr = (mpin >> 4) ^ 8;
        uint16_t mask = 1U << (mpin & 15);
        maskarray[addr] |= mask;
    }
}

void clrmpinmask (uint16_t *maskarray, int const *mpins)
{
    for (int mpin; (mpin = *mpins) != 0; mpins ++) {
        int addr = (mpin >> 4) ^ 8;
        uint16_t mask = 1U << (mpin & 15);
        maskarray[addr] &= ~ mask;
    }
}

// set mcp device pin directions
// assumes setmpinmask has been called to set pin directions
void mcpsetdir ()
{
    // inputs to the board are outputs from the mcps
    // set output mode for inputs to board, all else are inputs to mcp
    for (int bus = 0; bus < 2; bus ++) {
        for (int chip = bus; chip < bus + 5; chip ++) {
            mcpwrite16 (bus, chip, 0x00, ~ boardipinmask[bus*8+chip]);
        }
    }
/***
    for (int bus = 0; bus < 2; bus ++) {
        for (int chip = bus; chip < bus + 5; chip ++) {
            uint16_t mcpdirbits = mcpread16 (bus, chip, 0x00);
            printf ("mcpsetdir*: bus=%d chip=%d dir=%04X sb %04X\n", bus, chip, mcpdirbits, (uint16_t) ~ boardipinmask[bus*8+chip]);
            for (int bit = 0; bit < 16; bit ++) {
                printf ("mcpsetdir*: %12s %s\n", pinnames[bus*128+chip*16+bit],
                    ((mcpdirbits >> bit) & 1) ? "board->raspi" : "raspi->board");
            }
        }
    }
***/
}

// send pin values in mcppins out to the board being tested
void mcpsend ()
{
    // send random bits to physical board via i2c bus
    for (int bus = 0; bus < 2; bus ++) {
        for (int chip = 0; chip < 8; chip ++) {
            if (boardipinmask[bus*8+chip] != 0) {
                mcpwrite16 (bus, chip, 0x14, mcppins[bus*8+chip]);
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
                mcppins[bus*8+chip] = mcpread16 (bus, chip, 0x12);
            }
        }
    }
}

// scatter a bunch of bits for some register
//  input:
//   mpins = array of mcp pin numbers for bits of register, starting with MSB
//   value = register as single value
void setmpins (int const *mpins, uint32_t value)
{
    int const *mpine = mpins;
    while (*mpine != 0) mpine ++;
    while (mpine > mpins) {
        int mpin = *(-- mpine);
        setmpin (mpin, value & 1);
        value >>= 1;
    }
}

// gather a bunch of bits for some register
//  input:
//   mpins = array of mcp pin numbers for bits of register, starting with MSB
//  output:
//   returns register as single value
uint32_t getmpins (int const *mpins)
{
    uint32_t value = 0;
    for (int mpin; (mpin = *mpins) > 0; mpins ++) {
        value += value + getmpin (mpin);
    }
    return value;
}

// set mcp pin value ready to go to physical board via i2c bus
void setmpin (int mpin, bool val)
{
    int addr = (mpin >> 4) ^ 8;
    uint16_t mask = 1U << (mpin & 15);
    if (val) mcppins[addr] |= mask;
      else mcppins[addr] &= ~ mask;
}

// get mcp pin value from physical board via i2c bus
bool getmpin (int mpin)
{
    int addr = (mpin >> 4) ^ 8;
    uint16_t word = mcppins[addr];
    return (word >> (mpin & 15)) & 1;
}

// write word to mcp23017 via raspi i2c bus
//  input:
//   bus = 0 or 1
//   chip = chip number 0..7
//   regno = even register number
//   data<07:00> = value to write to even (A) register
//   data<15:08> = value to write to odd (B) register
//  output:
//   data written to chip
void mcpwrite16 (int bus, uint8_t chip, uint8_t regno, uint16_t data)
{
    int rc = i2cmaster (bus + 1,
        (I2CWR << 62) | ((uint64_t)(MCPI2CBA + chip) << 55) | (I2CWW << 54) |
        (I2CWR << 52) | ((uint64_t)regno << 44) |
        (I2CWR << 42) | ((uint64_t)(data & 0x00FFULL) << 34) |    // byte for reg+0
        (I2CWR << 32) | ((uint64_t)(data & 0xFF00ULL) << 16),     // byte for reg+1
        NULL);
    if (rc < 0) {
        fprintf (stderr, "mcpwrite16: i2c bus %d chip %u error %d\n", bus, chip, rc);
        ABORT ();
    }
}

// read word from mcp23017 via raspi i2c bus
//  input:
//   bus = 0 or 1
//   chip = chip number 0..7
//   regno = even register number
//  output:
//   returns data<07:00> = value read from even (A) register
//           data<15:08> = value read from odd (B) register
uint16_t mcpread16 (int bus, uint8_t chip, uint8_t regno)
{
    uint64_t readdata = 0;
    int rc = i2cmaster (bus + 1,
        (I2CWR << 62) | ((uint64_t)(MCPI2CBA + chip) << 55) | (I2CWW << 54) |
        (I2CWR << 52) | ((uint64_t)regno << 44) |
        (I2CRS << 42) |
        (I2CWR << 40) | ((uint64_t)(MCPI2CBA + chip) << 33) | (I2CRR << 32) |
        (I2CRD << 30) |                                 // byte for reg+0
        (I2CRD << 28),                                  // byte for reg+1
        &readdata);
    if (rc < 0) {
        fprintf (stderr, "mcpread16: i2c bus %d chip %u error %d\n", bus, chip, rc);
        ABORT ();
    }
    return ((readdata >> 8) & 0xFF) | ((readdata & 0xFF) << 8);
}
