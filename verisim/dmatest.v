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

/*

    0)

        forward brkgnti to brkgnto

    1)

        wait for
        * brkrqst negated - nothing requesting a break
        * brkgnti negated - processor not granting a break
        * blockgrantpass negated - we are not doing a break

        output
        * blockgrantpass asserted - block sending brkgnt out to next outer device
        * brkrqst asserted - request a break cycle from processor

    2)

        wait for
        * brkgnti - processor to grant the request

        output
        * dmafld
        * cycle3
        * cainc
        * wrmem

    3)

        wait for
        * TS2 of BREAK cycle

        output
        * data to INBUS if write cycle

        wait for
        * TP2 of BREAK cycle

        clock in
        * MBUF for read data if read cycle
        * BWCOV if 3-cycle

        output
        * brkrqst negated
        * remove write data from INBUS

    4)

        wait for
        * brkgnti negated

        output
        * blockgrantpass negated

*/

// generate random dma requests for testing dma request/grant signals

module dmatest (
    input[2:0] seed,
    input yclock, zclock, zreset,

    input armwrite,
    input[1:0] armraddr, armwaddr,
    input[31:00] armwdata,
    output[31:00] armrdata

    , input _BRKGNTI
    , input CLOK2
    , input _BRKCYC
    , input _BUSINI
    , input _BWCOV
    , input _MBUF_0
    , input _MBUF_1
    , input _MBUF_2
    , input _MBUF_3
    , input _MBUF_4
    , input _MBUF_5
    , input _MBUF_6
    , input _MBUF_7
    , input _MBUF_8
    , input _MBUF_9
    , input _MBUF_10
    , input _MBUF_11
    , input _RESET
    , input _TP2
    , input _TP3
    , input _TS2
    , input _TS3
    , input _TS4
    , input _BRKGNTO
    , input _BRKRQST
    , input _BRKWRM
    , input _CAINC
    , input _CYCLE3
    , input _DMAFLD_0
    , input _DMAFLD_1
    , input _DMAFLD_2
    , input _INBUS_0
    , input _INBUS_1
    , input _INBUS_2
    , input _INBUS_3
    , input _INBUS_4
    , input _INBUS_5
    , input _INBUS_6
    , input _INBUS_7
    , input _INBUS_8
    , input _INBUS_9
    , input _INBUS_10
    , input _INBUS_11

    , output _BRKGNTO_o
    , output _BRKRQST_o
    , output _BRKWRM_o
    , output _CAINC_o
    , output _CYCLE3_o
    , output _DMAFLD_0_o
    , output _DMAFLD_1_o
    , output _DMAFLD_2_o
    , output _INBUS_0_o
    , output _INBUS_1_o
    , output _INBUS_2_o
    , output _INBUS_3_o
    , output _INBUS_4_o
    , output _INBUS_5_o
    , output _INBUS_6_o
    , output _INBUS_7_o
    , output _INBUS_8_o
    , output _INBUS_9_o
    , output _INBUS_10_o
    , output _INBUS_11_o
);

    wire[14:00] addr;
    wire[11:00] rdata, wdata;
    wire cycl3req, caincreq, wrmemreq, wcover;

    // sim can read our status via arm port
    assign armrdata = (armraddr == 0) ? 32'h5A441002 : // [31:16] = 'ZD'; [15:12] = (log2 nreg) - 1; [11:00] = version
                      (armraddr == 1) ? { 1'b1,       //31
                                          6'b0,       //25
                                          seed,       //22
                                          1'b0,       //21 
                                          cycl3req,   //20
                                          caincreq,   //19
                                          wrmemreq,   //18
                                          1'b0,       //17
                                          ~ _BRKGNTI, //16
                                          16'b0       //00
                                        } :
                      (armraddr == 2) ? { 4'b0, wcover, addr, wdata } :
                      (armraddr == 3) ? { 20'b0, rdata } :
                                        32'hDEADBEEF;

    dmatester dmaboard (
        .yclock (yclock),
        .zclock (zclock),
        .zreset (zreset),

        ._BRKGNTI    (_BRKGNTI),
        .CLOK2       (CLOK2),
        .GND         (1'b0),
        .VCC         (1'b1),
        ._BRKCYC     (_BRKCYC),
        ._BUSINI     (_BUSINI),
        ._BWCOV      (_BWCOV),
        ._MBUF_0     (_MBUF_0),
        ._MBUF_1     (_MBUF_1),
        ._MBUF_2     (_MBUF_2),
        ._MBUF_3     (_MBUF_3),
        ._MBUF_4     (_MBUF_4),
        ._MBUF_5     (_MBUF_5),
        ._MBUF_6     (_MBUF_6),
        ._MBUF_7     (_MBUF_7),
        ._MBUF_8     (_MBUF_8),
        ._MBUF_9     (_MBUF_9),
        ._MBUF_10    (_MBUF_10),
        ._MBUF_11    (_MBUF_11),
        ._RESET      (_RESET),
        ._TP2        (_TP2),
        ._TP3        (_TP3),
        ._TS2        (_TS2),
        ._TS3        (_TS3),
        ._TS4        (_TS4),
        ._BRKGNTO    (_BRKGNTO),
        ._BRKRQST    (_BRKRQST),
        ._BRKWRM     (_BRKWRM),
        ._CAINC      (_CAINC),
        ._CYCLE3     (_CYCLE3),
        ._DMAFLD_0   (_DMAFLD_0),
        ._DMAFLD_1   (_DMAFLD_1),
        ._DMAFLD_2   (_DMAFLD_2),
        ._INBUS_0    (_INBUS_0),
        ._INBUS_1    (_INBUS_1),
        ._INBUS_2    (_INBUS_2),
        ._INBUS_3    (_INBUS_3),
        ._INBUS_4    (_INBUS_4),
        ._INBUS_5    (_INBUS_5),
        ._INBUS_6    (_INBUS_6),
        ._INBUS_7    (_INBUS_7),
        ._INBUS_8    (_INBUS_8),
        ._INBUS_9    (_INBUS_9),
        ._INBUS_10   (_INBUS_10),
        ._INBUS_11   (_INBUS_11),

        ._BRKGNTO_o  (_BRKGNTO_o),
        ._BRKRQST_o  (_BRKRQST_o),
        ._BRKWRM_o   (_BRKWRM_o),
        ._CAINC_o    (_CAINC_o),
        ._CYCLE3_o   (_CYCLE3_o),
        ._DMAFLD_0_o (_DMAFLD_0_o),
        ._DMAFLD_1_o (_DMAFLD_1_o),
        ._DMAFLD_2_o (_DMAFLD_2_o),
        ._INBUS_0_o  (_INBUS_0_o),
        ._INBUS_1_o  (_INBUS_1_o),
        ._INBUS_2_o  (_INBUS_2_o),
        ._INBUS_3_o  (_INBUS_3_o),
        ._INBUS_4_o  (_INBUS_4_o),
        ._INBUS_5_o  (_INBUS_5_o),
        ._INBUS_6_o  (_INBUS_6_o),
        ._INBUS_7_o  (_INBUS_7_o),
        ._INBUS_8_o  (_INBUS_8_o),
        ._INBUS_9_o  (_INBUS_9_o),
        ._INBUS_10_o (_INBUS_10_o),
        ._INBUS_11_o (_INBUS_11_o),

        .wcover    (wcover),
        .cycl3req  (cycl3req),
        .caincreq  (caincreq),
        .wrmemreq  (wrmemreq),
        .seed_0    (seed[0]),
        .seed_1    (seed[1]),
        .seed_2    (seed[2]),

        .wdata_0   (wdata[00]),
        .wdata_1   (wdata[01]),
        .wdata_2   (wdata[02]),
        .wdata_3   (wdata[03]),
        .wdata_4   (wdata[04]),
        .wdata_5   (wdata[05]),
        .wdata_6   (wdata[06]),
        .wdata_7   (wdata[07]),
        .wdata_8   (wdata[08]),
        .wdata_9   (wdata[09]),
        .wdata_10  (wdata[10]),
        .wdata_11  (wdata[11]),

        .rdata_0   (rdata[00]),
        .rdata_1   (rdata[01]),
        .rdata_2   (rdata[02]),
        .rdata_3   (rdata[03]),
        .rdata_4   (rdata[04]),
        .rdata_5   (rdata[05]),
        .rdata_6   (rdata[06]),
        .rdata_7   (rdata[07]),
        .rdata_8   (rdata[08]),
        .rdata_9   (rdata[09]),
        .rdata_10  (rdata[10]),
        .rdata_11  (rdata[11]),

        .addr_0    (addr[00]),
        .addr_1    (addr[01]),
        .addr_2    (addr[02]),
        .addr_3    (addr[03]),
        .addr_4    (addr[04]),
        .addr_5    (addr[05]),
        .addr_6    (addr[06]),
        .addr_7    (addr[07]),
        .addr_8    (addr[08]),
        .addr_9    (addr[09]),
        .addr_10   (addr[10]),
        .addr_11   (addr[11]),
        .addr_12   (addr[12]),
        .addr_13   (addr[13]),
        .addr_14   (addr[14])
    );
endmodule
