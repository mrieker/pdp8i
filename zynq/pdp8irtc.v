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

// DK8-EP programmable real time clock
// small-computer-handbook-1972.pdf p7-26/p246

module pdp8irtc (
    input CLOCK, RESET, BINIT,

    input armwrite,
    input armraddr, armwaddr,
    input[31:00] armwdata,
    output[31:00] armrdata,

    input iopstart,
    input iopstop,
    input[11:00] ioopcode,
    input[11:00] cputodev,

    output reg[11:00] devtocpu,
    output reg AC_CLEAR,
    output reg IO_SKIP,
    output INT_RQST,
    output reg SELECTED
);

    reg[11:00] buffer, counter, enable;
    reg status11;

    assign armrdata = (armraddr == 0) ? 32'h52430001 : // [31:16] = 'RC'; [15:12] = (log2 nreg) - 1; [11:00] = version
                        { 1'b0, status11, enable[11:06], buffer, counter };

    assign INT_RQST = enable[11] & status11;

    reg[19:00] divider;
    wire tick =
        (enable[08:06] == 2) ? (divider >= 999999) :  // 100Hz
        (enable[08:06] == 3) ? (divider >=  99999) :  //   1KHz
        (enable[08:06] == 4) ? (divider >=   9999) :  //  10KHz
        (enable[08:06] == 5) ? (divider >=    999) :  // 100KHz
        (enable[08:06] == 6) ? (divider >=     99) :  //   1MHz
            0;

    wire overflow = ~ enable[10] & tick & (counter == 12'o7777);

    always @(posedge CLOCK) begin
        if (BINIT) begin
            enable   <= 0;
            status11 <= 0;
            divider  <= 0;
        end else begin

            // process the IOP only on the leading edge
            // ...but leave output signals to PDP-8/I in place until given the all clear
            if (iopstart) begin
                SELECTED <= (ioopcode & 12'o7770) == 12'o6130;
                case (ioopcode)
                    12'o6130: enable  <= enable & ~ cputodev;       // clear enable bits
                    12'o6131: IO_SKIP <= status11;                  // skip on clock overflow
                    12'o6132: enable  <= enable |   cputodev;       // set enable bits
                    12'o6133: begin
                        counter  <= cputodev;                       // set counter
                        buffer   <= cputodev;                       // and buffer
                    end
                    12'o6134: devtocpu <= enable;                   // read enable register
                    12'o6135: devtocpu <= { status11, 11'b0 };      // read status register
                                                                    // clear status below
                    12'o6136: devtocpu <= buffer;                   // read buffer register
                    12'o6137: begin
                        buffer   <= counter;                        // read counter into buffer
                        devtocpu <= counter;                        // ...and return to cpu
                    end
                    default: begin end
                endcase
            end

            // processor no longer sending an IOP, stop sending data over the bus so it doesn't jam other devices
            else if (iopstop) begin
                AC_CLEAR <= 0;
                devtocpu <= 0;
                IO_SKIP  <= 0;
                SELECTED <= 0;
            end

            // increment divider and counter and status
            if (iopstart & (ioopcode == 12'o6135) | overflow) status11 <= overflow;

            if (~ iopstart | (ioopcode != 12'o6133)) begin
                if (tick) begin
                    case (enable[10:09])
                        0: counter <= counter + 1;
                        1: counter <= (counter == 12'o7777) ? buffer : counter + 1;
                    endcase
                end
            end

            divider <= (tick | (enable[08:06] == 0)) ? 0 : divider + 1;
        end
    end
endmodule
