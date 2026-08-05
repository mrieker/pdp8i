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

#ifndef ABORT
#define ABORT() do { fprintf (stderr, "abort() %s %d\n", __FILE__, __LINE__); abort (); } while (0)
#endif

#define MCPI2CBA 0x20  // I2C address of MCP23017 chip 0

// mcp23017 pins : mp_ digits 0wxyz
//   w = i2c bus (1 or 2)
//   x = chip address (0 .. 5)
//   y = port number (1=A 2=B)
//   z = bit number (0 .. 7)

// connector pins : cp_ digits 0jpp
//   j = jack (1..4)
//  pp = pin (2..043)

#include "testerdefs.h"

// mcp23017 pin names
//  index = (bus-1)*128 + chip*16 + bit
extern char const *const mpnames[256];
extern int const mptocp[256];

// connector pin names
//  index = (jack-1)*64 + pin
extern char const *const cpnames[256];
extern int const cptomp[256];

// list of pins for various multi-bit registers, MSB-to-LSB, zero terminated
extern int const mps__DFLD[];   // 3-bit
extern int const mps__DMAFLD[];
extern int const mps__IFLD[];
extern int const mps__IREG[];
extern int const mps__MEAD[];
extern int const mps__MAJST[];  // 4-bit
extern int const mps__SCTR[];   // 5-bit
extern int const mps__ACUM[];   // 12-bit
extern int const mps__INBUS[];
extern int const mps__MADR[];
extern int const mps__MBUF[];
extern int const mps__MQUO[];
extern int const mps__PCTR[];

// aliases for overloaded pins
#define mp_nxtms_0 mp__SCTR_0   // procalu, procreg
#define mp_nxtms_1 mp__SCTR_1
#define mp_nxtms_2 mp__SCTR_2
#define mp_nxtms_3 mp__SCTR_3
#define mp_aluq_0  mp__MQUO_0
#define mp_aluq_1  mp__MQUO_1
#define mp_aluq_2  mp__MQUO_2
#define mp_aluq_3  mp__MQUO_3
#define mp_aluq_4  mp__MQUO_4
#define mp_aluq_5  mp__MQUO_5
#define mp_aluq_6  mp__MQUO_6
#define mp_aluq_7  mp__MQUO_7
#define mp_aluq_8  mp__MQUO_8
#define mp_aluq_9  mp__MQUO_9
#define mp_aluq_10 mp__MQUO_10
#define mp_aluq_11 mp__MQUO_11
#define mp_cout    mp__DMAFLD_1

#define NMCPWORDS 16    // size of mcp data arrays

extern int i2cfds[2];
extern uint16_t mcppins[NMCPWORDS];        // current pin values
extern uint16_t boardipinmask[NMCPWORDS];  // mask of pins going in board (coming out mcps)
extern uint16_t boardopinmask[NMCPWORDS];  // mask of pins coming out board (going in mcps)
extern uint16_t boardpulpmask[NMCPWORDS];

void setmpinmask (uint16_t *maskarray, int const *mpins);
void clrmpinmask (uint16_t *maskarray, int const *mpins);
void mcpsetdir ();
void mcpsend ();
void mcprecv ();
void setmpins (int const *mpins, uint32_t value);
uint32_t getmpins (int const *mpins);
void setmpin (int mpin, bool val);
bool getmpin (int mpin);
void mcpwrite16 (int i2cfd, uint8_t chip, uint8_t regno, uint16_t data);
uint16_t mcpread16 (int i2cfd, uint8_t chip, uint8_t regno);

#endif
