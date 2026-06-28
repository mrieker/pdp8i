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

// library for accessing pins on tester board
// used to test physical circuit boards by comparing them to verilator equivalents

#ifndef _TESTLIB_H
#define _TESTLIB_H

#include <stdint.h>

#define ABORT() do { fprintf (stderr, "ABORT %s %d\n", __FILE__, __LINE__); abort (); } while (0)

#define MCPI2CBA 0x20  // I2C address of MCP23017 chip 0

// digits 0wxyz
//   w = i2c bus (1 or 2)
//   x = chip address (0 .. 5)
//   y = port number (1=A 2=B)
//   z = bit number (0 .. 7)

#define pin__BRKCYC   01020
#define pin__BRKGNTI  01021
#define pin__BRKGNTO  01022
#define pin_CONSDA    01023
#define pin_CONSCK    01024

#define pin__TS2      01010
#define pin__TS3      01011
#define pin__TS4      01012
#define pin__TP1      01013
#define pin__TP2      01014
#define pin__TP3      01015
#define pin__TP4      01016

#define pin__IOSKIP   01120
#define pin__LNKTOG   01121
#define pin__MAJST_3  01122
#define pin__MAJST_2  01123
#define pin__MAJST_1  01124
#define pin__MAJST_0  01125
#define pin__TS1      01126

#define pin__RUN      01110
#define pin__BRKWRM   01111
#define pin__CAINC    01112
#define pin__CYCLE3   01113
#define pin__PAUSE    01114
#define pin__INTRQST  01115
#define pin__INTINH   01116

#define pin__SWSTART  01220
#define pin__SWSSTEP  01221
#define pin__SWSINST  01222
#define pin__CLOCK    01223
#define pin__RESET    01224
#define pin__IOP      01225
#define pin__LINK     01226

#define pin__ION      01210
#define pin__BUSINI   01211
#define pin__BWCOV    01212
#define pin__SWLDAD   01213
#define pin__SWEXAM   01214
#define pin__SWDEPOS  01215
#define pin__SWCONT   01216

#define pin__MEAD_0   01320
#define pin__MEMDIS   01321
#define pin__READSR   01322
#define pin__ACCLEAR  01323
#define pin__BRKRQST  01324
#define pin__IFLD_0   01325
#define pin__DMAFLD_0 01326

#define pin__IFLD_2   01310
#define pin__MEAD_2   01311
#define pin__DFLD_1   01312
#define pin__DMAFLD_1 01313
#define pin__IFLD_1   01314
#define pin__MEAD_1   01315
#define pin__DFLD_0   01316

#define pin__MBUF_0   01420
#define pin__INBUS_0  01421
#define pin__MQUO_0   01422
#define pin__PCTR_0   01423
#define pin__SCTR_0   01424
#define pin__DFLD_2   01425
#define pin__DMAFLD_2 01426

#define pin__MBUF_1   01410
#define pin__INBUS_1  01411
#define pin__MQUO_1   01412
#define pin__PCTR_1   01413
#define pin__MADR_0   01414
#define pin__ACUM_0   01415
#define pin__SCTR_1   01416

#define pin__ACUM_10  02520
#define pin__MADR_10  02521
#define pin__MBUF_10  02522
#define pin__INBUS_10 02523
#define pin__MQUO_10  02524
#define pin__PCTR_10  02525
#define pin__IREG_10  02526

#define pin__ACUM_11  02510
#define pin__MADR_11  02511
#define pin__MBUF_11  02512
#define pin__IREG_11  02513
#define pin__PCTR_11  02514
#define pin__MQUO_11  02515
#define pin__INBUS_11 02516

#define pin__MQUO_2   02120
#define pin__PCTR_2   02121
#define pin__SCTR_2   02122
#define pin__ACUM_1   02123
#define pin__MADR_1   02124

#define pin__MQUO_3   02110
#define pin__PCTR_3   02111
#define pin__SCTR_3   02112
#define pin__ACUM_2   02113
#define pin__MADR_2   02114
#define pin__INBUS_2  02115
#define pin__MBUF_2   02116

#define pin__MQUO_4   02220
#define pin__PCTR_4   02221
#define pin__SCTR_4   02222
#define pin__ACUM_3   02223
#define pin__MADR_3   02224
#define pin__MBUF_3   02225
#define pin__INBUS_3  02226

#define pin__INBUS_5  02210
#define pin__MQUO_5   02211
#define pin__PCTR_5   02212
#define pin__INBUS_4  02213
#define pin__MBUF_4   02214
#define pin__MADR_4   02215
#define pin__ACUM_4   02216

#define pin__MBUF_6   02320
#define pin__INBUS_6  02321
#define pin__MQUO_6   02322
#define pin__PCTR_6   02323
#define pin__ACUM_5   02324
#define pin__MADR_5   02325
#define pin__MBUF_5   02326

#define pin__MADR_7   02310
#define pin__MBUF_7   02311
#define pin__INBUS_7  02312
#define pin__MQUO_7   02313
#define pin__PCTR_7   02314
#define pin__ACUM_6   02315
#define pin__MADR_6   02316

#define pin__ACUM_8   02420
#define pin__MADR_8   02421
#define pin__MBUF_8   02422
#define pin__INBUS_8  02423
#define pin__MQUO_8   02424
#define pin__PCTR_8   02425
#define pin__ACUM_7   02426

#define pin__ACUM_9   02410
#define pin__MADR_9   02411
#define pin__MBUF_9   02412
#define pin__INBUS_9  02413
#define pin__IREG_9   02414
#define pin__PCTR_9   02415
#define pin__MQUO_9   02416

// list of pins for various multi-bit registers, MSB-to-LSB, zero terminated
extern int const pins_DFLD[];   // 3-bit
extern int const pins_DMAFLD[];
extern int const pins_IFLD[];
extern int const pins_IREG[];
extern int const pins_MEAD[];
extern int const pins_MAJST[];  // 4-bit
extern int const pins_SCTR[];   // 5-bit
extern int const pins_ACUM[];   // 12-bit
extern int const pins_INBUS[];
extern int const pins_MADR[];
extern int const pins_MBUF[];
extern int const pins_MQUO[];
extern int const pins_PCTR[];

// aliases for overloaded pins
#define pin_nxtms_0 pin__SCTR_0     // procalu, procreg
#define pin_nxtms_1 pin__SCTR_1
#define pin_nxtms_2 pin__SCTR_2
#define pin_nxtms_3 pin__SCTR_3
#define pin_aluq_0  pin__MQUO_0
#define pin_aluq_1  pin__MQUO_1
#define pin_aluq_2  pin__MQUO_2
#define pin_aluq_3  pin__MQUO_3
#define pin_aluq_4  pin__MQUO_4
#define pin_aluq_5  pin__MQUO_5
#define pin_aluq_6  pin__MQUO_6
#define pin_aluq_7  pin__MQUO_7
#define pin_aluq_8  pin__MQUO_8
#define pin_aluq_9  pin__MQUO_9
#define pin_aluq_10 pin__MQUO_10
#define pin_aluq_11 pin__MQUO_11
#define pin_cout    pin__DMAFLD_1

// input and output pins for various boards (zero terminated)
extern int const procalu_ipins[];   // signals going into procalu board
extern int const procalu_opins[];   // signals coming out of procalu board

#define NMCPWORDS 16    // size of mcp data arrays

extern int i2cfds[2];
extern uint16_t mcppins[NMCPWORDS];        // current pin values
extern uint16_t boardipinmask[NMCPWORDS];  // mask of pins going in board (coming out mcps)
extern uint16_t boardopinmask[NMCPWORDS];  // mask of pins coming out board (going in mcps)

void fillmaskarray (uint16_t *maskarray, int const *pins);
void setpin (int pin, uint32_t val);
uint32_t getpin (int pin);
uint32_t randbits (int nbits);
void mcpsend ();
void mcprecv ();

void i2copen ();
void i2cwrite16 (int i2cfd, uint8_t chip, uint8_t regno, uint16_t data);
uint16_t i2cread16 (int i2cfd, uint8_t chip, uint8_t regno);

#endif
