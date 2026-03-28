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

module synk (input CLOCK, output reg q, input o);
    reg eo, p;
    always @(posedge CLOCK) begin
        if (eo) p <= o;
           else q <= p;
        eo <= ~ eo;
    end
endmodule

// main program for the zynq implementation

module Zynq (
    input  CLOCK,
    input  RESET_N,
    output LEDoutR,     // IO_B34_LN6 R14
    output LEDoutG,     // IO_B34_LP7 Y16
    output LEDoutB,     // IO_B34_LN7 Y17

    inout  bDMABUSA,
    inout  bDMABUSB,
    inout  bDMABUSC,
    inout  bDMABUSD,
    inout  bDMABUSE,
    inout  bDMABUSF,
    inout  bDMABUSH,
    inout  bDMABUSJ,
    inout  bDMABUSK,
    inout  bDMABUSL,
    inout  bDMABUSM,
    inout  bDMABUSN,
    inout  bMEMBUSA,
    inout  bMEMBUSB,
    inout  bMEMBUSC,
    inout  bMEMBUSD,
    inout  bMEMBUSE,
    inout  bMEMBUSF,
    inout  bMEMBUSH,
    inout  bMEMBUSJ,
    inout  bMEMBUSK,
    inout  bMEMBUSL,
    inout  bMEMBUSM,
    inout  bMEMBUSN,
    inout  bPIOBUSA,
    inout  bPIOBUSB,
    inout  bPIOBUSC,
    inout  bPIOBUSD,
    inout  bPIOBUSE,
    inout  bPIOBUSF,
    inout  bPIOBUSH,
    inout  bPIOBUSJ,
    inout  bPIOBUSK,
    inout  bPIOBUSL,
    inout  bPIOBUSM,
    inout  bPIOBUSN,

    output     i3CYCLE,
    output     iAC_CLEAR,
    output     iBRK_RQST,
    output     i_EA,
    output     iEMA,
    output     iEXTDMAADD_12,
    output     iINT_INHIBIT,
    output     iIO_SKIP,
    output     i_MEMDONE,
    output     iMEMINCR,
    output     i_STROBE,

    output     i_B36V1,
    output     iBEMA,
    output     i_CA_INCRMNT,
    output     i_D36B2,
    output     i_DATA_IN,
    output     iINT_RQST,
    output     i_MEM_07,

    input  o_ADDR_ACCEPT,
    input  oB_RUN,
    input  o_BF_ENABLE,
    input  oBUSINIT,
    input  o_DF_ENABLE,
    input  o_KEY_CLEAR,
    input  o_KEY_DF,
    input  o_KEY_IF,
    input  o_KEY_LOAD,
    input  o_LOAD_SF,
    input  o_SP_CYC_NEXT,
    input  o_B_BREAK,
    input  oBIOP1,
    input  oBIOP2,
    input  oBIOP4,
    input  oBTP2,
    input  oBTP3,
    input  oBTS_1,
    input  oBTS_3,
    input  o_BWC_OVERFLOW,
    input  oC36B2,
    input  oD35B2,
    input  oE_SET_F_SET,
    input  oJMP_JMS,
    input  oLINE_LOW,
    input  oMEMSTART,
    output r_BAC,
    output r_BMB,
    output r_MA,
    output x_DMAADDR,
    output x_DMADATA,
    output x_INPUTBUS,
    output x_MEM,

    output[14:00] xbraddr,
    output[11:00] xbrwdat,
    input[11:00] xbrrdat,
    output xbrenab,
    output xbrwena,

    output[14:00] vidaddra, vidaddrb,
    output[21:00] viddataa,
    output videnaba, vidwrena, videnabb,
    input[21:00] viddatab,

    // i2c interface to front panel
    inout      bFPI2CLOCK,      // bi-dir clock bus
    inout      bFPI2CDATA,      // bi-dir data bus
    output reg i_FPI2CDENA,     // low to turn on bi-dir driver; high to shut off
    output reg iFPI2CDDIR,      // high when sending; low when receiving

    // arm processor memory bus interface (AXI)
    // we are a slave for accessing the control registers (read and write)
    input[11:00]  saxi_ARADDR,
    output reg    saxi_ARREADY,
    input         saxi_ARVALID,
    input[11:00]  saxi_AWADDR,
    output reg    saxi_AWREADY,
    input         saxi_AWVALID,
    input         saxi_BREADY,
    output[1:0]   saxi_BRESP,
    output reg    saxi_BVALID,
    output[31:00] saxi_RDATA,
    input         saxi_RREADY,
    output[1:0]   saxi_RRESP,
    output reg    saxi_RVALID,
    input[31:00]  saxi_WDATA,
    output reg    saxi_WREADY,
    input         saxi_WVALID);

    // bus values that are constants
    assign saxi_BRESP = 0;  // A3.4.4/A10.3 transfer OK
    assign saxi_RRESP = 0;  // A3.4.4/A10.3 transfer OK

    // [31:16] = '8I'; [15:12] = (log2 len)-1; [11:00] = version
    localparam VERSION = 32'h38484001;

    reg[11:02] readaddr, writeaddr;
    reg[31:00] regctla, regctlb, regctlh;
    wire[31:00] regctlc, regctld, regctle, regctlf, regctlg, regctli;

    reg[14:00] ilaarray[4095:0], ilardata;
    reg[11:00] ilaafter, ilaindex;
    reg ilaarmed;

    // tty registers
    wire[31:00] ttyarmrd;
    wire[11:00] ttypdprd;
    wire ttyacclr, ttyioskp, ttyintrq;

    /////////////////////////////////////
    // send register being read to ARM //
    /////////////////////////////////////

    assign saxi_RDATA =
        (readaddr        == 10'b0000000000) ? VERSION    :  // 00000xxxxx00
        (readaddr        == 10'b0000000001) ? regctla    :
        (readaddr        == 10'b0000000010) ? regctlb    :
        (readaddr        == 10'b0000000011) ? regctlc    :
        (readaddr        == 10'b0000000100) ? regctld    :
        (readaddr        == 10'b0000000101) ? regctle    :
        (readaddr        == 10'b0000000110) ? regctlf    :
        (readaddr        == 10'b0000000111) ? regctlg    :
        (readaddr        == 10'b0000001000) ? regctlh    :
        (readaddr        == 10'b0000001001) ? regctli    :
        (readaddr        == 10'b0000010001) ? { ilaarmed, 3'b0, ilaafter, 4'b0, ilaindex } :
        (readaddr        == 10'b0000010010) ? { 17'b0, ilardata[14:00] } :
        (readaddr        == 10'b0000010011) ? { 32'b0                  } :
        (readaddr[11:04] ==  8'b00001000)   ? ttyarmrd   :  // 00001000xx00
        32'hDEADBEEF;

    wire armwrite = saxi_WREADY & saxi_WVALID;          // arm is writing a register (single fpga clock cycle)
    wire ttyarmwt = armwrite & (writeaddr[11:04] == 8'b00001000);

    // A3.3.1 Read transaction dependencies
    // A3.3.1 Write transaction dependencies
    //        AXI4 write response dependency
    always @(posedge CLOCK) begin
        if (~ RESET_N) begin
            saxi_ARREADY <= 1;                          // we are ready to accept read address
            saxi_RVALID  <= 0;                          // we are not sending out read data

            saxi_AWREADY <= 1;                          // we are ready to accept write address
            saxi_WREADY  <= 0;                          // we are not ready to accept write data
            saxi_BVALID  <= 0;                          // we are not acknowledging any write

        end else begin

            /////////////////////
            //  register read  //
            /////////////////////

            // check for PS sending us a read address
            if (saxi_ARREADY & saxi_ARVALID) begin
                readaddr <= saxi_ARADDR[11:02];             // save address bits we care about
                saxi_ARREADY <= 0;                          // we are no longer accepting a read address
                saxi_RVALID <= 1;                           // we are sending out the corresponding data

            // check for PS acknowledging receipt of data
            end else if (saxi_RVALID & saxi_RREADY) begin
                saxi_ARREADY <= 1;                          // we are ready to accept an address again
                saxi_RVALID <= 0;                           // we are no longer sending out data
            end

            //////////////////////
            //  register write  //
            //////////////////////

            // check for PS sending us write data
            if (armwrite) begin
                case (writeaddr)                            // write data to register
                    10'b0000000001: begin
                        regctla <= saxi_WDATA;
                    end

                    10'b0000000010: begin
                        regctlb <= saxi_WDATA;
                    end

                    10'b0000001000: begin
                        regctlh <= saxi_WDATA;
                    end
                endcase
                saxi_AWREADY <= 1;                          // we are ready to accept an address again
                saxi_WREADY  <= 0;                          // we are no longer accepting write data
                saxi_BVALID  <= 1;                          // we have accepted the data

            end else begin
                // check for PS sending us a write address
                if (saxi_AWREADY & saxi_AWVALID) begin
                    writeaddr <= saxi_AWADDR[11:02];        // save address bits we care about
                    saxi_AWREADY <= 0;                      // we are no longer accepting a write address
                    saxi_WREADY  <= 1;                      // we are ready to accept write data
                end

                // check for PS acknowledging write acceptance
                if (saxi_BVALID & saxi_BREADY) begin
                    saxi_BVALID <= 0;
                end
            end
        end
    end

    // ctla..b - bits going to backplane
    // ctlc..g - bits coming from backplane
    // ctlh    - gpio bits going to backplane, eg, switches
    // ctli    - gpio bits coming from backplane, eg, lights

    wire[11:00] businbus = regctlb[26:15] | ttypdprd;
    wire busacclr = regctla[03] | ttyacclr;
    wire busintrq = regctla[07] | ttyintrq;
    wire busioskp = regctla[08] | ttyioskp;

    assign regctlg[26:12] = { busioskp, busintrq, busacclr, businbus };

    backplane backboard (
        .zclock   (regctla[12]),        // 100MHz clock
        .zreset   (regctla[13]),        // power-on reset

        .clok2    (regctlc[23]),        // 10MHz clock
        .reset    (regctla[01]),        // power-on reset

        .i3CYCLE  (regctla[02]),        // do 3-cycle break
        .iACCLEAR (busacclr),           // io pulse clears AC
        .iBRKRQST (regctla[04]),        // requesting break
        .iBRKWRM  (regctla[05]),        // break cycle writes memory
        .iCAINC   (regctla[06]),        // curad cycle increments address word
        .iINTRQST (busintrq),           // request interrupt
        .iIOSKIP  (busioskp),           // increment PC at end of IO pulse
        .iLNKTOG  (regctla[09]),        // toggle link register
        .iPAUSE   (regctla[10]),        // pause processor clocking          (stretch cycle)
        .memdisab (regctla[11]),        // disable extmemory,v internal memory

        .iDMAADDR (regctlb[14:00]),     // device sending address for DMA
        .iINBUS   (businbus),           // device sending data for PIO or DMA

        .oBREAK   (regctlc[00]),        // currently doing BREAK          (DMA) cycle
        .oBUSINI  (regctlc[01]),        // initialize bus devices
        .oBWCOV   (regctlc[02]),        // 3-cycle DMA wordcount overflowed
        .oIOP     (regctlc[03]),        // io instruction pulse
        .oLINK    (regctlc[04]),        // link register
        .oRUN     (regctlc[05]),
        .oTP1     (regctlc[06]),
        .oTP2     (regctlc[07]),
        .oTP3     (regctlc[08]),
        .oTP4     (regctlc[09]),
        .oTS1     (regctlc[10]),
        .oTS2     (regctlc[11]),
        .oTS3     (regctlc[12]),
        .oTS4     (regctlc[13]),

        .swstart  (regctlc[14]),
        .swldad   (regctlc[15]),
        .swdepos  (regctlc[16]),
        .swexam   (regctlc[17]),
        .swcont   (regctlc[18]),
        .swstop   (regctlc[19]),
        .swsstep  (regctlc[20]),
        .swsinst  (regctlc[21]),

        .oION     (regctlc[22]),

        .memfield (regctld[02:00]),
        .majst    (regctld[06:03]),
        .sctr     (regctld[11:07]),
        .swdfld   (regctld[26:24]),
        .swifld   (regctld[29:27]),

        .oMADR    (regctle[11:00]),
        .oMBUF    (regctle[23:12]),
        .oACUM    (regctlf[11:00]),
        .mquo     (regctlf[23:12]),
        .pctr     (regctlg[11:00]),

        .gpin     (regctlh),
        .gpout    (regctli)
    );

    wire businit = regctlc[01];
    wire iopulse = regctlc[03];
    wire[11:00] mbuf = regctle[23:12];
    wire[11:00] acum = regctlf[11:00];

    pdp8itty ttyinst (
        .CLOCK (CLOCK),
        .RESET (~ RESET_N),
        .BINIT (businit),

        .armwrite (ttyarmwt),
        .armraddr (readaddr[03:02]),
        .armwaddr (writeaddr[03:02]),
        .armwdata (saxi_WDATA),
        .armrdata (ttyarmrd),

        .iopulse  (iopulse),
        .ioopcode (mbuf[08:00]),
        .cputodev (acum),

        .devtocpu (ttypdprd),
        .AC_CLEAR (ttyacclr),
        .IO_SKIP  (ttyioskp),
        .INT_RQST (ttyintrq)
    );

    // integrated logic analyzer
    //  ilaarmed = 0: trigger condition satisfied
    //             1: waiting for trigger condition
    //  ilaafter = number of cycles to record after trigger condition satisfied
    //  ilaindex = next entry in ilaarray to write

    /*
    always @(posedge CLOCK) begin
        if (~ RESET_N) begin
            ilaarmed <= 0;
            ilaafter <= 0;
        end else begin

            if (armwrite & (writeaddr == 10'b0000010001)) begin

                // arm processor is writing control register
                ilaarmed <= saxi_WDATA[31];
                ilaafter <= saxi_WDATA[27:16];
                ilaindex <= saxi_WDATA[11:00];
                ilardata <= ilaarray[saxi_WDATA[11:00]];
            end else begin

                // capture signals while before trigger and for ilaafter cycles thereafter
                if (ilaarmed | (ilaafter != 0)) begin
                    ilaarray[ilaindex] <= {
                        sim_lbPRTE,
                        arm_swMPRT,
                        sim_iBEMA,
                        sim_oMA
                    };

                    ilaindex <= ilaindex + 1;
                    if (~ ilaarmed) ilaafter <= ilaafter - 1;
                end

                // check trigger condition
                // - disk controller requesting dma cycle
                if (sim_lbPRTE) begin
                    ilaarmed <= 0;
                end
            end
        end
    end
    */
endmodule
