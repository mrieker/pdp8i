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

#ifndef _VERIZYNQ_H
#define _VERIZYNQ_H

#include <stdint.h>

#define VERIZYNQ_SHMNM "/z8lverizynq"

#define VERIZYNQ_CPID  ((1<<29)-1)  // client pid mask
#define VERIZYNQ_STATE (7<<29)      // state mask
#define VERIZYNQ_IDLE  (0<<29)      // not being used
#define VERIZYNQ_BUSY  (1<<29)      // client filling in request
#define VERIZYNQ_READ  (2<<29)      // client waiting for server to do axi bus read request to verilated zynq code
#define VERIZYNQ_WRITE (3<<29)      // client waiting for server to do axi bus write request to verilated zynq code
#define VERIZYNQ_DONE  (4<<29)      // server waiting for client to pick up result

struct VeriPage {
    int serverpid;
    int state;          // <31:29>:state; <28:00>:clientpid
    uint32_t index;     // 0..1023
    uint32_t value;
};

#endif
