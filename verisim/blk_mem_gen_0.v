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

// PDP-8/I VC-8 video memory

module blk_mem_gen_0 (
      input clka,
      input ena,
      input wea,
      input[14:00] addra,
      input[21:00] dina,
      input clkb,
      input enb,
      input[14:00] addrb,
      output reg[21:00] doutb
    );

    reg[21:00] delay;
    reg[21:00] ram[32767:0];

    always @(posedge clka) begin
        if (ena & wea) begin
            ram[addra] <= dina;
        end
    end
    always @(posedge clkb) begin
        { doutb, delay } <= enb ? { delay, ram[addrb] } : 44'b0;
    end

endmodule
