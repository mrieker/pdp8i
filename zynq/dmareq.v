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

// perform a DMA (break) cycle

module dmareq (
    input  CLOCK,           // 100MHz clock
    input  RESET,           // fpga reset
    input  dorequest,       // start a request
    input  wrmemreq,        // - it writes memory
    input  busini,          // bus initialize
    input  brkcyc,          // break cycle in progress
    input  brkgnti,         // break grant input from next inner (or processor)
    input  brkrqsti,        // break request line from bus
    input  tp2, ts2, ts4,   // timing pulse and states
    output brkgnto,         // break grant output to next outer (or nothing)
    output reg brkrqsto,    // break request line to bus
    output reg blkgntpass,  // when set, blocks passing grant signal along
    output clockinreaddata, // clock in memory read data from mbuf
                            // also clocks for write cycles to indicate end of cycle
    output gateaddressout,  // gate address out to inbus
    output gatecontrolsout, // gate controls (dmafld, cycle3, cainc, brkwrm) out to bus
    output gatewrdataout);  // gate write data out to bus

    // when idle, pass grant signal from inner boards to outer boards
    // when active, block passing grant signal
    assign brkgnto = brkgnti & ~ blkgntpass;

    // our request is being granted whenever we are requesting and we are receiving the grant
    // - note we do not initiate a request unless nothing is requested and nothing is granted
    wire isgranted = brkrqsto & brkgnti;

    // we are currently doing the break cycle of our request
    wire endofbrk = isgranted & brkcyc;

    // clock in read data at TP2 of the break cycle
    assign clockinreaddata = endofbrk & tp2;

    // gate control signals out as long as our request is being granted
    assign gatecontrolsout = isgranted;

    // gate address out during TS4 and our request is being granted
    assign gateaddressout = ts4 & isgranted;

    // gate write data out during TS2 of our break cycle
    assign gatewrdataout = ts2 & wrmemreq & endofbrk;

    // state machine loop
    always @(posedge CLOCK) begin

        // shut off while being reset
        if (RESET | busini) begin
            blkgntpass <= 0;
            brkrqsto <= 0;
        end

        // otherwise if no request (including ours) and nothing being granted,
        // block outgoing grants and start a request
        else if (dorequest & ~ brkgnti & ~ brkrqsti) begin
            blkgntpass <= 1;
            brkrqsto <= 1;
        end

        else begin

            // drop request at TP2 of our break cycle
            // keep blocking outgoing grant until our incoming grant stops
            if (endofbrk & tp2) begin
                brkrqsto <= 0;
            end

            // allow grant to pass when our grant is finally dropped by processor
            // this makes it impossible for outer requestor to see last nip of our grant
            if (~ brkrqsto & ~ brkgnti) begin
                blkgntpass <= 0;
            end
        end
    end
endmodule
