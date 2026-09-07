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

// Provide ARM processor access to PDP-8/I core memory via DMA requests

// arm registers:
//  [0] = ident='CM',sizecode=1,version
//  [1] = <enable> <wcovf> <rddone> <busy> <12-bit-data> <write> <15-bit-addr>
//    (rw) busy   = perform memory cycle (self-clearing)
//    (ro) wcovf  = wordcount overflow for 3-cycle
//    (ro) 3cycl  = do a 3-cycle transfer
//    (ro) cainc  = increment address in 3-cycle transfer
//    (rw) data   = write: data to be written to memory via dma cycle
//                  read: data read from memory
//    (rw) write  = write given data to memory
//    (rw) addr   = address of memory word to access
//  [3] = 32-bit test-and-set cell
//        always accepts writing anything when currently zero
//        otherwise writing its current value back clears it to zero

module pdp8icmem (
    input CLOCK, RESET,

    input armwrite,
    input[1:0] armraddr, armwaddr,
    input[31:00] armwdata,
    output[31:00] armrdata,

    output brk3cycl,
    output brkcainc,
    output brkgnto,
    output brkrqsto,
    output brkwrite,
    output dmagntd,
    output[2:0] brkema,
    output[11:00] brkinbus,

    input[11:00] brkmbuf,
    input brkcycle,
    input brktp2,
    input brkts2,
    input brkts4,
    input brkwcovf,
    input brkgnti,
    input brkrqsti,
    input busini
);

    reg ctl3cycl, ctlcainc, ctlbusy, ctlwcovf, ctlwrite, lastcird;
    reg[14:00] ctladdr;
    reg[11:00] ctldata;
    reg[31:00] armlock;
    wire blkgntpass;

    assign armrdata = (armraddr == 0) ? 32'h434D101A :  // [31:16] = 'CM'; [15:12] = (log2 nreg) - 1; [11:00] = version
                      (armraddr == 1) ? { ctlbusy, ctlwcovf, ctl3cycl, ctlcainc, ctldata, ctlwrite, ctladdr } :
                      (armraddr == 2) ? { 31'b0, brkgnti & blkgntpass } :
                      armlock;

    wire clockinreaddata, gateaddressout, gatecontrolsout, gatewrdataout;
    dmareq dmareqinst (
        .CLOCK      (CLOCK),                // 100MHz clock
        .RESET      (RESET),                // fpga reset
        .dorequest  (ctlbusy),              // start a request
        .wrmemreq   (ctlwrite),             // - it writes memory
        .busini     (busini),               // bus initialize
        .brkcyc     (brkcycle),             // break cycle in progress
        .brkgnti    (brkgnti),              // break grant input from next inner (or processor)
        .brkrqsti   (brkrqsti),             // break request line from bus
        .tp2        (brktp2),               // timing pulse and states
        .ts2        (brkts2),
        .ts4        (brkts4),

        .brkgnto    (brkgnto),              // break grant output to next outer (or nothing)
        .brkrqsto   (brkrqsto),             // break request line to bus
        .blkgntpass (blkgntpass),           // blocking passing grant along
        .clockinreaddata (clockinreaddata), // clock in memory read data from mbuf (also indicates end of write cycle)
        .gateaddressout  (gateaddressout),  // gate address out to inbus
        .gatecontrolsout (gatecontrolsout), // gate controls (dmafld, cycle3, cainc, brkwrm) out to bus
        .gatewrdataout   (gatewrdataout));  // gate write data out to bus

    assign brkinbus = (gateaddressout ? ctladdr[11:00] : 0) | (gatewrdataout ? ctldata : 0);

    assign brk3cycl = gatecontrolsout ? ctl3cycl       : 0;
    assign brkcainc = gatecontrolsout ? ctlcainc       : 0;
    assign brkwrite = gatecontrolsout ? ctlwrite       : 0;
    assign brkema   = gatecontrolsout ? ctladdr[14:12] : 0;
    assign dmagntd  = gatecontrolsout;

    always @(posedge CLOCK) begin
        if (RESET) begin
            armlock  <= 0;
            ctlbusy  <= 0;
            lastcird <= 0;
        end

        // arm processor is writing one of the registers
        else if (armwrite) begin
            case (armwaddr)
                1: begin
                    if (~ ctlbusy) begin
                        ctladdr   <= armwdata[14:00];
                        ctlwrite  <= armwdata[15];
                        ctldata   <= armwdata[27:16];
                        ctlcainc  <= armwdata[28];
                        ctl3cycl  <= armwdata[29];
                        ctlbusy   <= armwdata[31];
                    end
                end

                // test-and-set cell for arm processor use
                //  anything can be written when it is currently zero
                //  otherwise writing the same number back clears it to zero
                //  all other writes are ignored
                3: begin
                    if (armlock == 0) begin
                        armlock <= armwdata;
                    end else if (armlock == armwdata) begin
                        armlock <= 0;
                    end
                end
            endcase
        end

        // maybe we have dma cycle to finish
        else if (clockinreaddata) begin
            if (~ ctlwrite) begin
                ctldata <= brkmbuf;
            end
            ctlwcovf <= brkwcovf;
            lastcird <= 1;
        end

        // clockinreaddata dropped, clear busy telling arm
        // we are done and ready for another request
        else if (lastcird) begin
            ctlbusy  <= 0;
            lastcird <= 0;
        end
    end
endmodule
