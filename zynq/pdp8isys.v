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

// PDP-8/I system call interface
// communicates with z8isys.cc to access some linux system calls
// uses I/O opcodes 6310..6317

module pdp8isys (
    input CLOCK, RESET, BINIT,

    input armwrite,
    input armraddr, armwaddr,
    input[31:00] armwdata,
    output[31:00] armrdata,

    input iopstart,
    input iopstop,
    input[08:00] ioopcode,
    input[11:00] cputodev,

    output reg[11:00] devtocpu,
    output reg AC_CLEAR,
    output reg IO_SKIP,
    output reg INT_RQST,
    output reg PAUSE,
    output reg SELECTED
);

    reg enable;
    reg[14:00] counter;

    assign armrdata = (armraddr == 0) ? 32'h53590001 : // [31:16] = 'SY'; [15:12] = (log2 nreg) - 1; [11:00] = version
                      (armraddr == 1) ? { enable, counter, PAUSE, INT_RQST, IO_SKIP, AC_CLEAR, devtocpu } :
                      32'hDEADBEEF;

    always @(posedge CLOCK) begin
        if (BINIT) begin
            if (RESET) begin
                enable  <= 1;
                counter <= 0;
            end
            INT_RQST <= 0;
            PAUSE    <= 0;
        end

        // arm processor is writing one of the registers
        else if (armwrite) begin
            case (armwaddr)
                1: begin
                    enable   <= armwdata[31];
                    PAUSE    <= armwdata[15];
                    INT_RQST <= armwdata[14];
                    IO_SKIP  <= armwdata[13];
                    AC_CLEAR <= armwdata[12];
                    devtocpu <= armwdata[11:00];
                end
            endcase
        end else begin

            // signal the arm to process the opcode
            // it will clear PAUSE when it finishes
            if (iopstart & enable & (ioopcode[08:03] == 6'o31) & (ioopcode[02:00] != 3)) begin
                SELECTED <= 1;
                PAUSE    <= 1;
                counter  <= counter + 1;
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
