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

// PDP-8/I pulse bit generator

// arm registers:
//  [0] = ident='PB',sizecode=0,version
//  [1] = iszac 00000 width count

module pdp8ipbit (
    input CLOCK, RESET,

    input armwrite,
    input[2:0] armraddr, armwaddr,
    input[31:00] armwdata,
    output[31:00] armrdata,

    input iopstart,
    input iopstop,
    input[08:00] ioopcode,
    input[11:00] cputodev,

    output reg[11:00] devtocpu,
    output reg AC_CLEAR,
    output reg IO_SKIP,
    output reg SELECTED,
    output     PAUSE,

    output reg pulse
);

    reg iszac, lastpulse;
    reg [9:0] stretch, stcount;
    reg [12:00] count, width;
    reg [15:00] samprate, sampincr, sampcount, sampinteg;
    reg [31:00] sampbytes;
    reg [15:00] ffinal;
    reg [13:00] fpart1, fpart2, fpart3, fpart4;
    reg [24:00] qtrsec;

    assign armrdata = (armraddr == 0) ? 32'h50422008 : // [31:16] = 'PB'; [15:12] = (log2 nreg) - 1; [11:00] = version
                      (armraddr == 1) ? { iszac, 5'b0, width, count } :
                      (armraddr == 2) ? { samprate, sampincr } :
                      (armraddr == 3) ? sampbytes :
                      (armraddr == 4) ? { 7'b0, qtrsec } :
                      (armraddr == 5) ? { ffinal, 2'b0, fpart1 } :
                      (armraddr == 6) ? { 12'b0, stcount, stretch } :
                                        32'hDEADBEEF;

    assign PAUSE = stcount != 0;

    always @(posedge CLOCK) begin
        if (RESET) begin
            iszac  <= 0;        // don't do ISZ AC
            width  <= 599;      // 6.00uS pulse width
            count  <= 0;
            pulse  <= 0;
            qtrsec <= 0;
            fpart1 <= 0;
            stcount   <= 0;
            stretch   <= 0;
            lastpulse <= 0;
        end else begin

            // arm processor is writing the register
            if (armwrite) begin
                case (armwaddr)
                    1: begin
                        iszac <= armwdata[31];
                        width <= armwdata[25:13];
                        count <= 0;
                        pulse <= 0;
                    end
                    2: begin
                        samprate  <= armwdata[31:16];
                        sampincr  <= armwdata[15:00];
                        sampcount <= 0;
                        sampinteg <= 0;
                        sampbytes <= 0;
                    end
                    6: begin
                        stretch <= armwdata[09:00];
                    end
                endcase
            end else begin
                if (iopstart) begin

                    // any I/O instruction, start pulse going
                    count <= width;
                    pulse <= 1;

                    // maybe do increment accumulator and skip if zero
                    if (iszac & (ioopcode == 9'o004)) begin
                        stcount  <= stretch;
                        SELECTED <= 1;
                        AC_CLEAR <= 1;
                        { IO_SKIP, devtocpu } <= { 1'b0, cputodev } + 13'o00001;
                    end
                end else begin
                    if (iopstop) begin
                        devtocpu <= 0;
                        AC_CLEAR <= 0;
                        IO_SKIP  <= 0;
                        SELECTED <= 0;
                    end
                    if (count != 0) begin
                        count <= count - 1;
                    end else begin
                        pulse <= 0;
                    end

                    if (PAUSE) stcount <= stcount - 1;
                end

                // at 8000 samples/second:
                //  samprate = 100000000 / 8000 - 1 = 12499  ; how many 10nS clocks per integration
                //  sampincr = 65535 / (samprate + 1) = 5    ; how much to add to integration each 10nS
                if (sampcount == samprate) begin
                    sampbytes <= { sampbytes[23:00], sampinteg[15:08] };
                    sampcount <= 0;
                    sampinteg <= pulse ? sampincr : 0;
                end else begin
                    sampcount <= sampcount + 1;
                    if (pulse) sampinteg <= sampinteg + sampincr;
                end
            end

            // run a frequency counter
            // counts the 0-to-1 transitions of pulse
            if (qtrsec == 24999999) begin
                qtrsec <= 0;
                ffinal <= { 2'b0, fpart1 } + { 2'b0, fpart2 } + { 2'b0, fpart3 } + { 2'b0, fpart4 };
                fpart1 <= { 13'b0, ~ lastpulse & pulse };
                fpart2 <= fpart1;
                fpart3 <= fpart2;
                fpart4 <= fpart3;
            end else begin
                qtrsec <= qtrsec + 1;
                if (~ lastpulse & pulse & (fpart1 != 16383)) begin
                    fpart1 <= fpart1 + 1;
                end
            end

            lastpulse <= pulse;
        end
    end
endmodule
