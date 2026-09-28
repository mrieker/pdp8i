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

// PDP-8/I paper tape reader interface

// arm registers:
//  [0] = ident='PR',sizecode=0,version
//  [1] = <rdflag> <enable> <rdstep> 00000000000000000 <rdchar>

module pdp8iptr (
    input CLOCK, RESET, BINIT,

    input armwrite,
    input armraddr, armwaddr,
    input[31:00] armwdata,
    output[31:00] armrdata,
    output armintrq,

    input iopstart,
    input iopstop,
    input[08:00] ioopcode,
    input[11:00] cputodev,

    output reg[11:00] devtocpu,
    output reg AC_CLEAR,
    output reg IO_SKIP,
    output INT_RQST,
    output reg SELECTED
);

    reg enable, rdflag, rdstep;
    reg[11:00] rdchar;

    assign armrdata = ~ armraddr ? 32'h50520002 : // [31:16] = 'PR'; [15:12] = (log2 nreg) - 1; [11:00] = version
                      { rdflag, enable, rdstep, 17'b0, rdchar };

    assign armintrq = rdstep;

    assign INT_RQST = rdflag;

    always @(posedge CLOCK) begin
        if (BINIT) begin
            if (RESET) begin
                enable <= 0;
            end
            rdflag <= 0;
            rdstep <= 0;
        end

        // arm processor is writing one of the registers
        else if (armwrite) begin
            case (armwaddr)

                // arm processor is sending a reader char for the PDP-8/I code to read
                // - typically sets rdflag = 1 indicating rdchar has something in it
                1: begin
                    rdflag <= armwdata[31];
                    enable <= armwdata[30];
                    rdstep <= armwdata[29];
                    rdchar <= armwdata[11:00];
                end
            endcase
        end else begin

            // process the IOP only on the leading edge
            // ...but leave output signals to PDP-8/I in place until given the all clear
            if (iopstart & enable & (ioopcode[08:03] == 6'o01)) begin
                SELECTED <= 1;
                if (ioopcode[00]) begin IO_SKIP <= rdflag; end                              // skip if reader char ready
                if (ioopcode[01]) begin devtocpu <= rdchar; rdflag <= 0; end                // read char, clear flag
                if (ioopcode[02]) begin rdflag <= 0; rdstep <= 1; end                       // clear flag, step reader
            end

            // processor no longer sending an IOP, stop sending data over the bus so it doesn't jam other devices
            else if (iopstop) begin
                AC_CLEAR <= 0;
                devtocpu <= 0;
                IO_SKIP  <= 0;
                SELECTED <= 0;
            end
        end
    end
endmodule
