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

// synchronize input signal to the clock
module synk (input CLOCK, output reg q, input o);
    reg eo, p;
    always @(posedge CLOCK) begin
        if (eo) p <= o;
           else q <= p;
        eo <= ~ eo;
    end
endmodule

// main program for the zynq implementation
// it operates as an I/O device for the PDP-8/I
// it also has an I2C connection to the PDP-8/I front panel

// real mode tested a pc with cd verisim ; ./simtest.sh
// sim mode tested on a zynq with demo program, eg, cd demos ; ../ccode/z8ipanel -sim kaleid.tcl e

// RESETS
//      RESET_N = fpga power-on reset       reset everything including AXI bus state        pulsed when zynq boots (or verimain or verizynq started)
//   arm_iRESET = arm-commanded reset       reset everything except AXI bus state           pulsed by hardreset TCL command
//   dev_iRESET = ~ RESET_N | arm_iRESET    reset devices and processor to power-on state   pulsed by either of the above
//  dev_iBUSINI = dev_iRESET | startswitch  reset devices to power-on state                 pulsed by any of the above + start switch

// CLOCKS
//       CLOCK = fpga 100MHz clock
//  dev_iCLOCK = 10MHz PDP clock

module Zynq #(parameter BIDIRCONSDA=1) (
    input         CLOCK,        // 100MHz
    input         RESET_N,      // FPGA reset
    output        LEDoutR_N,    // IO_B34_LN6 R14
    output        LEDoutG_N,    // IO_B34_LP7 Y16
    output        LEDoutB_N,    // IO_B34_LN7 Y17

    // io bus connections
    input[11:00]  hdw_oACUM,
    input         hdw_oBRKCYC,
    input         hdw_oBRKGNTI, // grant coming in from processor-side of bus
    input         hdw_oBRKRQST,
    input         hdw_oBUSINI,  // hdw_iRESET + start switch
    input         hdw_oBWCOV,
    input         hdw_oIOP,
    input         hdw_oLINK,
    input[11:00]  hdw_oMADR,
    input[11:00]  hdw_oMBUF,
    input[2:0]    hdw_oMEAD,
    input[3:0]    hdw_oMAJST,
    input         hdw_oRUN,
    input         hdw_oTP1,
    input         hdw_oTP2,
    input         hdw_oTP3,
    input         hdw_oTP4,
    input         hdw_oTS1,
    input         hdw_oTS2,
    input         hdw_oTS3,
    input         hdw_oTS4,

    output        hdw_iACCLEAR, // [hdw_ioenabd]
    output        hdw_iBRKGNTO, // [hdw_poweron] grant going out to end-side of bus
    output        hdw_iBRKRQST, // [hdw_poweron] open collector
    output        hdw_iBRKWRM,  // [hdw_dmagntd]
    output        hdw_iCAINC,   // [hdw_dmagntd]
    output        hdw_iCLOCK,   // [hdw_poweron] 10MHz to external processor
    output        hdw_iCYCLE3,  // [hdw_dmagntd]
    output[2:0]   hdw_iDMAFLD,  // [hdw_dmagntd]
    output[11:00] hdw_iINBUS,   // [hdw_ioenabd]
    output        hdw_iINTRQST, // [hdw_poweron] open collector
    output        hdw_iIOSKIP,  // [hdw_ioenabd]
    output        hdw_iMEMDIS,  // [hdw_poweron]
    output        hdw_iPAUSE,   // [hdw_poweron] open collector
    output        hdw_iRESET,   // [hdw_poweron] external boards should do a power-on reset
    output        hdw_ioenabd_n,  // my io cycle | dma granted & TS4 | dma granted & BRKCYC & TS2 | memdis & TS1
    output        hdw_dmagntd_n,  // enable the dma cycle outputs
    output reg    hdw_poweron_n,  // enable the 'always on' and 'open collector' outputs

    // i2c interface to hardware front panel
    output        hdw_iCONSCK,
    inout         hdw_bCONSDA,
    output        hdw_iCONSDA,
    input         hdw_oCONSDA,

    // spare pins not used for anything
    input         spare1,
    input         spare2,
    input         spare3,

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
    input         saxi_WVALID
);

    // [31:16] = '8I'; [15:12] = (log2 len)-1; [11:00] = version
    localparam VERSION = 32'h38494001;

    reg[11:02] readaddr, writeaddr;
    wire debounced, lastswLDAD, lastswSTART, simmemen;

    // PDP-8/I module signals

    //  hdw_i... : signals going to hardware PDP-8/I
    //  hdw_o... : signals coming from hardware PDP-8/I

    //  sim_i... : signals going to simulated PDP-8/I (pdp8isim.v)
    //  sim_o... : signals coming from simulated PDP-8/I (pdp8isim.v)

    //  dev_i... : signals from internal io devices going to both hdw_i... and sim_i...
    //  dev_o... : selected from hdw_o... or sim_o... going to internal io devices

    //  arm_i... : signals from arm processor as an internal io device (merged onto dev_i... bus)
    //  arm uses dev_o... signals instead of having arm_o... signals

    wire[31:00] regctla, regctlb, regctlc, regctle, regctlf, regctlg, regctli;
    reg[05:00] regctld, clkdiv;
    reg[31:00] regctlh;

    wire[11:00] sim_oACUM;
    wire        sim_oBRKCYC;
    wire        sim_oBRKGNTI;
    wire        sim_oBRKRQST;
    wire        sim_oBUSINI;
    wire        sim_oBWCOV;
    wire        sim_oIOP;
    wire        sim_oLINK;
    wire[11:00] sim_oMADR;
    wire[11:00] sim_oMBUF;
    wire[2:0]   sim_oMEAD;
    wire[3:0]   sim_oMAJST;
    wire        sim_oRUN;
    wire        sim_oTP1;
    wire        sim_oTP2;
    wire        sim_oTP3;
    wire        sim_oTP4;
    wire        sim_oTS1;
    wire        sim_oTS2;
    wire        sim_oTS3;
    wire        sim_oTS4;

    wire        sim_iACCLEAR;
    wire        sim_iBRKGNTO;
    wire        sim_iBRKRQST;
    wire        sim_iBRKWRM;
    wire        sim_iCAINC;
    wire        sim_iCLOCK;
    wire        sim_iCYCLE3;
    wire[2:0]   sim_iDMAFLD;
    wire[11:00] sim_iINBUS;
    wire        sim_iINTRQST;
    wire        sim_iIOSKIP;
    wire        sim_iMEMDIS;
    wire        sim_iPAUSE;
    wire        sim_iRESET;

    wire        sim_iCONSCK;
    wire        sim_iCONSDA;
    wire        sim_oCONSDA;

    wire[11:00] dev_oACUM;
    wire        dev_oBRKCYC;
    wire        dev_oBRKGNTI;
    wire        dev_oBRKRQST;
    wire        dev_oBUSINI;
    wire        dev_oBWCOV;
    wire        dev_oIOP;
    wire        dev_oLINK;
    wire[11:00] dev_oMADR;
    wire[11:00] dev_oMBUF;
    wire[2:0]   dev_oMEAD;
    wire[3:0]   dev_oMAJST;
    wire        dev_oRUN;
    wire        dev_oTP1;
    wire        dev_oTP2;
    wire        dev_oTP3;
    wire        dev_oTP4;
    wire        dev_oTS1;
    wire        dev_oTS2;
    wire        dev_oTS3;
    wire        dev_oTS4;

    wire        dev_iACCLEAR;
    wire        dev_iBRKGNTO;
    wire        dev_iBRKRQST;
    wire        dev_iBRKWRM;
    wire        dev_iCAINC;
    reg         dev_iCLOCK;
    wire        dev_iCYCLE3;
    wire[2:0]   dev_iDMAFLD;
    wire[11:00] dev_iINBUS;
    wire        dev_iINTRQST;
    wire        dev_iIOSEL;
    wire        dev_iIOSKIP;
    wire        dev_iMEMDIS;
    wire        dev_iPAUSE;
    wire        dev_iRESET;

    reg[9:0] meminprog;

    reg simit, lastts3, didio;
    wire acclr, intrq, ioskp;
    reg[31:00] memcycctr;

    // arm interface wires;
    reg        arm_iACCLEAR;
    reg        arm_iBRKGNTO;
    reg        arm_iBRKRQST;
    reg        arm_iBRKWRM;
    reg        arm_iCAINC;
    reg        arm_iCLOCK;
    reg        arm_iCYCLE3;
    reg[2:0]   arm_iDMAFLD;
    reg[11:00] arm_iINBUS;
    reg        arm_iINTRQST;
    reg        arm_iIOSKIP;
    reg        arm_iMEMDIS;
    reg        arm_iPAUSE;
    reg        arm_iRESET;
    reg        arm_swCONT;
    reg        arm_swDEPOS;
    reg[2:0]   arm_swDFLD;
    reg        arm_swEXAM;
    reg[2:0]   arm_swIFLD;
    reg        arm_swLDAD;
    reg        arm_swSINST;
    reg        arm_swSSTEP;
    reg        arm_swSTART;
    reg[11:00] arm_swSREG;

    reg arm_hizmembus, dev_hizmembus;
    wire hizmembus;

    // shadow interface wires
    wire shad_freeze;
    wire[31:00] shardata;

    // rtc interface wires
    wire[31:00] rcardata;
    wire[11:00] rcibus;
    wire rcacclr, rcintrq, rciosel, rcioskp;

    // tty interface wires
    wire[31:00] ttardata;
    wire[11:00] ttibus;
    wire ttacclr, ttintrq, ttiosel, ttioskp;

    // dc02 interface wires
    wire[31:00] dcardata;
    wire[11:00] dcibus;
    wire dcacclr, dcintrq, dciosel, dcioskp;

    // disk interface wires
    wire[31:00] rkardata;
    wire[11:00] rkibus;
    wire rkacclr, rkintrq, rkiosel, rkioskp;

    // front panel i2c interface
    wire[31:00] fpi2crdata;

    // core memory interface wires
    wire[31:00] cmardata;
    wire cmbrkrqst, cmbrkwrite, cmbrk3cycl, cmbrkcainc;
    wire cmbrkgnti, cmbrkgnto, cmdmagntd;
    wire[11:00] cmbrkinbus;
    wire[2:0] cmbrkema;

    // tape interface wires
    wire[31:00] tcardata;
    wire[11:00] tcibus;
    wire tcacclr, tcintrq, tciosel, tcioskp;

    // paper tape reader interface wires
    wire[31:00] prardata;
    wire[11:00] pribus;
    wire pracclr, printrq, priosel, prioskp;

    // paper tape punch interface wires
    wire[31:00] ppardata;
    wire ppintrq, ppiosel, ppioskp;

    // video interface wires
    wire[31:00] vcardata;
    wire[11:00] vcibus;
    wire vcacclr, vcintrq, vciosel, vcioskp;

    // pulsebit interface wires
    wire[31:00] pbardata;
    wire[11:00] pbibus;
    wire pbacclr, pbiosel, pbioskp;
    wire pulsebit;

    // bus values that are constants
    assign saxi_BRESP = 0;  // A3.4.4/A10.3 transfer OK
    assign saxi_RRESP = 0;  // A3.4.4/A10.3 transfer OK

    // our own integrated logic analyzer
    reg[31:00] ilaarray[4095:0], ilardata;
    reg[11:00] ilaafter, ilaindex;
    reg ilaarmed;

    // generate 10MHz PDP clock
    // or whatever frequency is selected in regctld[05:00]
    //  0: use arm_iCLOCK to clock from arm
    //  1:  20nS = 50.0MHz
    //  7:  80nS = 12.5MHz
    //  8:  90nS = 11.1MHz
    //  9: 100nS = 10.0MHz (default)
    // 10: 110nS =  9.1MHz
    // 11: 120nS =  8.3MHz
    // 63: 640nS =  1.6MHz
    always @(posedge CLOCK) begin
        if (~ RESET_N | (clkdiv == regctld[5:0]) | shad_freeze) begin
            clkdiv <= 0;
            dev_iCLOCK <= arm_iCLOCK;
        end else begin
            clkdiv <= clkdiv + 1;
            if (clkdiv == { 1'b0, regctld[5:1] }) dev_iCLOCK <= 1;
        end
    end

    /////////////////////////////////////
    // send register being read to ARM //
    /////////////////////////////////////

    assign saxi_RDATA =
        (readaddr        == 10'b0000000000) ? VERSION    :  // 00000xxxxx00
        (readaddr        == 10'b0000000001) ? regctla    :
        (readaddr        == 10'b0000000010) ? regctlb    :
        (readaddr        == 10'b0000000011) ? regctlc    :
        (readaddr        == 10'b0000000100) ? { 20'b0, clkdiv, regctld } :
        (readaddr        == 10'b0000000101) ? regctle    :
        (readaddr        == 10'b0000000110) ? regctlf    :
        (readaddr        == 10'b0000000111) ? regctlg    :
        (readaddr        == 10'b0000001000) ? regctlh    :
        (readaddr        == 10'b0000001001) ? regctli    :
        (readaddr        == 10'b0000001110) ? memcycctr  :
        (readaddr        == 10'b0000010001) ? { ilaarmed, 3'b0, ilaafter, 4'b0, ilaindex } :
        (readaddr        == 10'b0000010010) ? { ilardata[31:00] } :
        (readaddr        == 10'b0000010011) ? { 32'b0           } :
        (readaddr[11:06] ==  6'b000010)     ? fpi2crdata :
        (readaddr[11:05] ==  7'b0000110)    ? rkardata   :
        (readaddr[11:05] ==  7'b0000111)    ? vcardata   :
        (readaddr[11:05] ==  7'b0001000)    ? pbardata   :
        (readaddr[11:05] ==  7'b0001001)    ? dcardata   :
        (readaddr[11:05] ==  7'b0001010)    ? shardata   :
        (readaddr[11:04] ==  8'b00010110)   ? cmardata   :
        (readaddr[11:04] ==  8'b00010111)   ? ttardata   :
        (readaddr[11:03] ==  9'b000110000)  ? prardata   :
        (readaddr[11:03] ==  9'b000110001)  ? ppardata   :
        (readaddr[11:03] ==  9'b000110010)  ? tcardata   :
        (readaddr[11:03] ==  9'b000110011)  ? rcardata   :
        32'hDEADBEEF;

    wire armwrite   = saxi_WREADY & saxi_WVALID;    // arm is writing a register (single fpga clock cycle)
    wire fpi2cwrite = armwrite & writeaddr[11:06] == 6'b000010;
    wire rkawrite   = armwrite & writeaddr[11:05] == 7'b0000110;
    wire vcawrite   = armwrite & writeaddr[11:05] == 7'b0000111;
    wire pbawrite   = armwrite & writeaddr[11:05] == 7'b0001000;
    wire dcawrite   = armwrite & writeaddr[11:05] == 7'b0001001;
    wire shawrite   = armwrite & writeaddr[11:05] == 7'b0001010;
    wire cmawrite   = armwrite & writeaddr[11:04] == 8'b00010110;
    wire ttawrite   = armwrite & writeaddr[11:04] == 8'b00010111;
    wire prawrite   = armwrite & writeaddr[11:03] == 9'b000110000;
    wire ppawrite   = armwrite & writeaddr[11:03] == 9'b000110001;
    wire tcawrite   = armwrite & writeaddr[11:03] == 9'b000110010;
    wire rcawrite   = armwrite & writeaddr[11:03] == 9'b000110011;

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

            hdw_poweron_n <= 1;                         // start with 'always on' outputs turned off

            arm_iRESET  <= 0;

            regctld     <= 9;                           // default 10MHz PDP clock
            simit       <= 0;                           // assume want to access real PDP-8/I by default

        end else begin

            /////////////////////
            //  register read  //
            /////////////////////

            // check for PS sending us a read address
            if (saxi_ARREADY & saxi_ARVALID) begin
                readaddr <= saxi_ARADDR[11:02];             // save address bits we care about
                saxi_ARREADY <= 0;                          // we are no longer accepting a read address
                saxi_RVALID  <= 1;                          // we are sending out the corresponding data
            end

            // check for PS acknowledging receipt of data
            else if (saxi_RVALID & saxi_RREADY) begin
                saxi_ARREADY <= 1;                          // we are ready to accept an address again
                saxi_RVALID  <= 0;                          // we are no longer sending out data
            end

            //////////////////////
            //  register write  //
            //////////////////////

            // check for PS sending us write data
            if (armwrite) begin
                hdw_poweron_n <= 0;                         // z8ipanel or some such is running, turn 'always on' outputs on

                case (writeaddr)                            // write data to register
                     10'b0000000001: begin
                        arm_iACCLEAR <= saxi_WDATA[00];
                        arm_iBRKGNTO <= saxi_WDATA[01];
                        arm_iBRKRQST <= saxi_WDATA[02];
                        arm_iBRKWRM  <= saxi_WDATA[03];
                        arm_iCAINC   <= saxi_WDATA[04];
                        arm_iCLOCK   <= saxi_WDATA[05];
                        arm_iCYCLE3  <= saxi_WDATA[06];
                        arm_iDMAFLD  <= saxi_WDATA[09:07];
                        arm_iINBUS   <= saxi_WDATA[21:10];
                        arm_iINTRQST <= saxi_WDATA[22];
                        arm_iIOSKIP  <= saxi_WDATA[23];
                        arm_iMEMDIS  <= saxi_WDATA[24];
                        arm_iPAUSE   <= saxi_WDATA[25];
                        arm_iRESET   <= saxi_WDATA[26];
                    end

                    10'b0000000010: begin
                        arm_swCONT   <= saxi_WDATA[00];
                        arm_swDEPOS  <= saxi_WDATA[01];
                        arm_swDFLD   <= saxi_WDATA[04:02];
                        arm_swEXAM   <= saxi_WDATA[05];
                        arm_swIFLD   <= saxi_WDATA[08:06];
                        arm_swLDAD   <= saxi_WDATA[09];
                        arm_swSINST  <= saxi_WDATA[10];
                        arm_swSSTEP  <= saxi_WDATA[11];
                        arm_swSTART  <= saxi_WDATA[12];
                        arm_swSREG   <= saxi_WDATA[24:13];
                    end

                    10'b0000000100: begin
                        regctld[05:00] <= saxi_WDATA[05:00];
                    end

                    10'b0000000101: begin
                        simit        <= saxi_WDATA[00];
                    end

                    default: begin end
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

        if (~ armwrite & dev_iRESET) begin
            arm_iACCLEAR <= 0;
            arm_iBRKGNTO <= 0;
            arm_iBRKRQST <= 0;
            arm_iBRKWRM  <= 0;
            arm_iCAINC   <= 0;
            arm_iCYCLE3  <= 0;
            arm_iDMAFLD  <= 0;
            arm_iINBUS   <= 0;
            arm_iINTRQST <= 0;
            arm_iIOSKIP  <= 0;
            arm_iMEMDIS  <= 0;
            arm_iPAUSE   <= 0;
            arm_swCONT   <= 0;
            arm_swDEPOS  <= 0;
            arm_swDFLD   <= 0;
            arm_swEXAM   <= 0;
            arm_swIFLD   <= 0;
            arm_swLDAD   <= 0;
            arm_swSINST  <= 0;
            arm_swSSTEP  <= 0;
            arm_swSTART  <= 0;
            arm_swSREG   <= 0;
        end
    end

    /////////////////////////////////////////////////
    //  synchronize signals output by the PDP-8/I  //
    /////////////////////////////////////////////////

    wire hsy_oBRKGNTI, hsy_oBRKRQST, hsy_oBUSINI, hsy_oIOP, hsy_oRUN, hsy_oTP1;
    wire hsy_oTP2, hsy_oTP3, hsy_oTP4, hsy_oTS1, hsy_oTS2, hsy_oTS3, hsy_oTS4;

    synk synkbg (CLOCK, hsy_oBRKGNTI, hdw_oBRKGNTI);
    synk synkbr (CLOCK, hsy_oBRKRQST, hdw_oBRKRQST);
    synk synkbi (CLOCK, hsy_oBUSINI,  hdw_oBUSINI);
    synk synkip (CLOCK, hsy_oIOP,     hdw_oIOP);
    synk synkrn (CLOCK, hsy_oRUN,     hdw_oRUN);
    synk synkp1 (CLOCK, hsy_oTP1,     hdw_oTP1);
    synk synkp2 (CLOCK, hsy_oTP2,     hdw_oTP2);
    synk synkp3 (CLOCK, hsy_oTP3,     hdw_oTP3);
    synk synkp4 (CLOCK, hsy_oTP4,     hdw_oTP4);
    synk synks1 (CLOCK, hsy_oTS1,     hdw_oTS1);
    synk synks2 (CLOCK, hsy_oTS2,     hdw_oTS2);
    synk synks3 (CLOCK, hsy_oTS3,     hdw_oTS3);
    synk synks4 (CLOCK, hsy_oTS4,     hdw_oTS4);

    /////////////////////////////////////////////////////
    //  select between simulated and hardware PDP-8/I  //
    /////////////////////////////////////////////////////

    // signals coming from arm registers : arm_i*
    // signals coming from devices       : dev_i*
    // signals coming from real PDP      : hsy_o*
    // signals coming from simulator     : sim_o*

    // signals going to devices   dev_o* = simit ? sim_o* : hsy_o*
    // signals going to simulator sim_i* = simit ? dev_i* :    0
    // signals going to real PDP  hdw_i* = simit ?    0   : dev_i*

    /*
                        +------------+
    (pdp hsy_o* )  -->  | D0       Q |  -->  ( dev_o*  devices)
                        |     mux    |
    (sim sim_o* )  -->  | D1       S |<--simit
                        +------------+

    (arm regs arm_i* )  -->
             (devices)  -->  wired-or-busses  -->  dev_i*  -->  gated with  simit  -->  ( sim_i*  sim)
                                                           -->  gated with ~simit  -->  ( hdw_i*  pdp)
    */

    // when simulating, send signals from devices on to the simulated PDP-8/I
    // when not simming, send signals from devices on to the hardware PDP-8/I

    assign sim_iACCLEAR = simit ? dev_iACCLEAR : 0;
    assign sim_iBRKRQST = simit ? dev_iBRKRQST : 0;
    assign sim_iBRKWRM  = simit ? dev_iBRKWRM  : 0;
    assign sim_iCAINC   = simit ? dev_iCAINC   : 0;
    assign sim_iCLOCK   = simit ? dev_iCLOCK   : 0;
    assign sim_iCYCLE3  = simit ? dev_iCYCLE3  : 0;
    assign sim_iDMAFLD  = simit ? dev_iDMAFLD  : 0;
    assign sim_iINBUS   = simit ? dev_iINBUS   : 0;
    assign sim_iINTRQST = simit ? dev_iINTRQST : 0;
    assign sim_iIOSKIP  = simit ? dev_iIOSKIP  : 0;
    assign sim_iMEMDIS  = simit ? dev_iMEMDIS  : 0;
    assign sim_iPAUSE   = simit ? dev_iPAUSE   : 0;
    assign sim_iRESET   = simit ? dev_iRESET   : 1;

    assign hdw_iACCLEAR = simit ? 0 : dev_iACCLEAR;
    assign hdw_iBRKGNTO = simit ? hdw_oBRKGNTI : dev_iBRKGNTO;
    assign hdw_iBRKRQST = simit ? 0 : dev_iBRKRQST;
    assign hdw_iBRKWRM  = simit ? 0 : dev_iBRKWRM;
    assign hdw_iCAINC   = simit ? 0 : dev_iCAINC;
    assign hdw_iCLOCK   = simit ? 0 : dev_iCLOCK;
    assign hdw_iCYCLE3  = simit ? 0 : dev_iCYCLE3;
    assign hdw_iDMAFLD  = simit ? 0 : dev_iDMAFLD;
    assign hdw_iINBUS   = simit ? 0 : dev_iINBUS;
    assign hdw_iINTRQST = simit ? 0 : dev_iINTRQST;
    wire   hdw_iIOSEL   = simit ? 0 : dev_iIOSEL;
    assign hdw_iIOSKIP  = simit ? 0 : dev_iIOSKIP;
    assign hdw_iMEMDIS  = simit ? 0 : dev_iMEMDIS;
    assign hdw_iPAUSE   = simit ? 0 : dev_iPAUSE;
    assign hdw_iRESET   = simit ? 1 : dev_iRESET;

    // enable 74AHC540s to drive io signals to bus during iop whenever
    // any of our io devices is selected by current io instruction
    // also whenever dma granted and TS4 to output dma address over inbus
    //                           and TS2 of BREAK cycle to output write data over inbus
    //               and during TS1 if memory chips on extmemory.kicad_sch are disabled (arm provides data on arm_iINBUS)
    assign hdw_ioenabd_n = ~ (hdw_iIOSEL |
                            ~ hdw_dmagntd_n & hdw_oTS4 |
                            ~ hdw_dmagntd_n & hdw_oBRKCYC & hdw_oTS2 |
                              hdw_iMEMDIS & hdw_oTS1);

    // enable 74AHC540s to drive dma signals to bus
    // while grated use of dma bus lines
    assign hdw_dmagntd_n = simit ? 1 : ~ cmdmagntd;

    // when simulating, send signals from the simulated PDP-8/I on to the internal devices
    // when not simming, send signals from the hardware PDP-8/I on to the internal devices

    assign dev_oACUM    = simit ? sim_oACUM    : hdw_oACUM;
    assign dev_oBRKCYC  = simit ? sim_oBRKCYC  : hdw_oBRKCYC;
    assign dev_oBRKGNTI = simit ? sim_oBRKGNTI : hsy_oBRKGNTI;
    assign dev_oBRKRQST = simit ? sim_oBRKRQST : hsy_oBRKRQST;
    assign dev_oBUSINI  = simit ? sim_oBUSINI  : hsy_oBUSINI;
    assign dev_oBWCOV   = simit ? sim_oBWCOV   : hdw_oBWCOV;
    assign dev_oIOP     = simit ? sim_oIOP     : hsy_oIOP;
    assign dev_oLINK    = simit ? sim_oLINK    : hdw_oLINK;
    assign dev_oMADR    = simit ? sim_oMADR    : hdw_oMADR;
    assign dev_oMBUF    = simit ? sim_oMBUF    : hdw_oMBUF;
    assign dev_oMEAD    = simit ? sim_oMEAD    : hdw_oMEAD;
    assign dev_oMAJST   = simit ? sim_oMAJST   : hdw_oMAJST;
    assign dev_oRUN     = simit ? sim_oRUN     : hsy_oRUN;
    assign dev_oTP1     = simit ? sim_oTP1     : hsy_oTP1;
    assign dev_oTP2     = simit ? sim_oTP2     : hsy_oTP2;
    assign dev_oTP3     = simit ? sim_oTP3     : hsy_oTP3;
    assign dev_oTP4     = simit ? sim_oTP4     : hsy_oTP4;
    assign dev_oTS1     = simit ? sim_oTS1     : hsy_oTS1;
    assign dev_oTS2     = simit ? sim_oTS2     : hsy_oTS2;
    assign dev_oTS3     = simit ? sim_oTS3     : hsy_oTS3;
    assign dev_oTS4     = simit ? sim_oTS4     : hsy_oTS4;

    assign regctla[00]    = arm_iACCLEAR;
    assign regctla[01]    = arm_iBRKGNTO;
    assign regctla[02]    = arm_iBRKRQST;
    assign regctla[03]    = arm_iBRKWRM;
    assign regctla[04]    = arm_iCAINC;
    assign regctla[05]    = arm_iCLOCK;
    assign regctla[06]    = arm_iCYCLE3;
    assign regctla[09:07] = arm_iDMAFLD;
    assign regctla[21:10] = arm_iINBUS;
    assign regctla[22]    = arm_iINTRQST;
    assign regctla[23]    = arm_iIOSKIP;
    assign regctla[24]    = arm_iMEMDIS;
    assign regctla[25]    = arm_iPAUSE;
    assign regctla[26]    = arm_iRESET;
    assign regctla[31:27] = 0;

    assign regctlb[00]    = arm_swCONT;
    assign regctlb[01]    = arm_swDEPOS;
    assign regctlb[04:02] = arm_swDFLD;
    assign regctlb[05]    = arm_swEXAM;
    assign regctlb[08:06] = arm_swIFLD;
    assign regctlb[09]    = arm_swLDAD;
    assign regctlb[10]    = arm_swSINST;
    assign regctlb[11]    = arm_swSSTEP;
    assign regctlb[12]    = arm_swSTART;
    assign regctlb[24:13] = arm_swSREG;
    assign regctlb[31:25] = 0;

    assign regctlc[00]    = dev_iACCLEAR;
    assign regctlc[01]    = dev_iBRKGNTO;
    assign regctlc[02]    = dev_iBRKRQST;
    assign regctlc[03]    = dev_iBRKWRM;
    assign regctlc[04]    = dev_iCAINC;
    assign regctlc[05]    = dev_iCLOCK;
    assign regctlc[06]    = dev_iCYCLE3;
    assign regctlc[09:07] = dev_iDMAFLD;
    assign regctlc[21:10] = dev_iINBUS;
    assign regctlc[22]    = dev_iINTRQST;
    assign regctlc[23]    = dev_iIOSKIP;
    assign regctlc[24]    = dev_iMEMDIS;
    assign regctlc[25]    = dev_iPAUSE;
    assign regctlc[26]    = dev_iRESET;
    assign regctlc[31:27] = 0;

    assign regctle[00]    = simit;
    assign regctle[04:01] = 0;
    assign regctle[16:05] = dev_oMADR;
    assign regctle[19:17] = dev_oMEAD;
    assign regctle[31:20] = dev_oMBUF;

    assign regctlf[11:00] = dev_oACUM;
    assign regctlf[12]    = dev_oBRKCYC;
    assign regctlf[13]    = dev_oBRKGNTI;
    assign regctlf[14]    = dev_oBRKRQST;
    assign regctlf[15]    = dev_oBUSINI;
    assign regctlf[16]    = dev_oBWCOV;
    assign regctlf[17]    = dev_oIOP;
    assign regctlf[18]    = dev_oLINK;
    assign regctlf[19]    = dev_oRUN;
    assign regctlf[20]    = dev_oTP1;
    assign regctlf[21]    = dev_oTP2;
    assign regctlf[22]    = dev_oTP3;
    assign regctlf[23]    = dev_oTP4;
    assign regctlf[24]    = dev_oTS1;
    assign regctlf[25]    = dev_oTS2;
    assign regctlf[26]    = dev_oTS3;
    assign regctlf[27]    = dev_oTS4;
    assign regctlf[31:28] = dev_oMAJST;

    assign regctli = 0;

    // count memory cycles
    // z8ipanelini.tcl uses it to see when exam/depos cycle completes
    // dectape uses it for timing in z8itc08.cc
    always @(posedge CLOCK) begin
        regctlh <= RESET_N ? regctlh + 1 : 0;
        if (~ RESET_N) begin
            memcycctr <= 0;
        end else if (~ lastts3 & dev_oTS3) begin
            memcycctr <= memcycctr + 1;
        end
        lastts3 <= dev_oTS3;
    end

    // see if PDP is doing stuff with the busses
    // everything the PDP does begins with a MEMSTART pulse and lasts less than 5uS
    // so we start a counter at 1023 at memstart and count it down to 0 (taking 10.23uS)
    // ...restarting whenever we see memstart
    // this is kind of like RUN, but takes into account cycles initiated by the console
    always @(posedge CLOCK) begin
        if (dev_iRESET) begin
            meminprog <= 0;
        end else begin
            if (dev_oTS1) begin
                meminprog <= 1023;
            end else if (meminprog != 0) begin
                meminprog <= meminprog - 1;
            end
        end
    end

    // internal pio busses - wire-ored (active high) from device to processor
    assign dev_iACCLEAR = arm_iACCLEAR | ttacclr | rkacclr | vcacclr | tcacclr | pracclr | pbacclr | dcacclr | rcacclr;
    assign dev_iBRKRQST = arm_iBRKRQST | cmbrkrqst;
    assign dev_iBRKWRM  = arm_iBRKWRM  | cmbrkwrite;
    assign dev_iCAINC   = arm_iCAINC   | cmbrkcainc;
    assign dev_iCYCLE3  = arm_iCYCLE3  | cmbrk3cycl;
    assign dev_iDMAFLD  = arm_iDMAFLD  | cmbrkema;
    assign dev_iINBUS   = arm_iINBUS   | ttibus  | rkibus  | vcibus  | tcibus  | pribus  | pbibus  | dcibus  | rcibus  | cmbrkinbus;
    assign dev_iINTRQST = arm_iINTRQST | ttintrq | rkintrq | vcintrq | tcintrq | printrq | ppintrq | dcintrq | rcintrq;
    assign dev_iIOSEL   =                ttiosel | rkiosel | vciosel | tciosel | priosel | ppiosel | dciosel | rciosel | pbiosel;
    assign dev_iIOSKIP  = arm_iIOSKIP  | ttioskp | rkioskp | vcioskp | tcioskp | prioskp | ppioskp | dcioskp | rcioskp | pbioskp;
    assign dev_iMEMDIS  = arm_iMEMDIS;
    assign dev_iPAUSE   = arm_iPAUSE;
    assign dev_iRESET   = arm_iRESET   | ~ RESET_N;

    ///////////////////////////////////
    //  simulated PDP-8/I processor  //
    ///////////////////////////////////

    assign LEDoutR_N = ~ shad_freeze;   // turn on when frozen
    assign LEDoutG_N = ~ dev_oRUN;      // turn on when running
    assign LEDoutB_N = ~ simit;         // turn on when simming

    wire[3:0] sim_majst;
    wire sim_run, sim_swldad, sim_swdepos, sim_swexam, sim_swstart, sim_swcont;

    assign regctlg = 0;

    pdp8isim siminst (
        .CLOCK          (CLOCK),
        .RESET          (~ RESET_N),

        .iACCLEAR       (sim_iACCLEAR),
        .iBRKRQST       (sim_iBRKRQST),
        .iBRKWRM        (sim_iBRKWRM),
        .iCAINC         (sim_iCAINC),
        .iCLOCK         (sim_iCLOCK),
        .iCYCLE3        (sim_iCYCLE3),
        .iDMAFLD        (sim_iDMAFLD),
        .iINBUS         (sim_iINBUS),
        .iINTRQST       (sim_iINTRQST),
        .iIOSKIP        (sim_iIOSKIP),
        .iMEMDIS        (sim_iMEMDIS),
        .iPAUSE         (sim_iPAUSE),
        .iRESET         (sim_iRESET),

        .oACUM          (sim_oACUM),
        .oBRKCYC        (sim_oBRKCYC),
        .oBRKGNTO       (sim_oBRKGNTI),
        .oBUSINI        (sim_oBUSINI),
        .oBWCOV         (sim_oBWCOV),
        .oIOP           (sim_oIOP),
        .oLINK          (sim_oLINK),
        .oMADR          (sim_oMADR),
        .oMBUF          (sim_oMBUF),
        .oMEAD          (sim_oMEAD),
        .oMAJST         (sim_oMAJST),
        .oRUN           (sim_oRUN),
        .oTP1           (sim_oTP1),
        .oTP2           (sim_oTP2),
        .oTP3           (sim_oTP3),
        .oTP4           (sim_oTP4),
        .oTS1           (sim_oTS1),
        .oTS2           (sim_oTS2),
        .oTS3           (sim_oTS3),
        .oTS4           (sim_oTS4),

        .iCONSCK        (sim_iCONSCK),
        .iCONSDA        (sim_iCONSDA),
        .oCONSDA        (sim_oCONSDA)

        ,.majst         (sim_majst)
        ,.run           (sim_run)
        ,.swldad        (sim_swldad)
        ,.swdepos       (sim_swdepos)
        ,.swexam        (sim_swexam)
        ,.swstart       (sim_swstart)
        ,.swcont        (sim_swcont)
    );

    ///////////////////////
    //  DMA grant chain  //
    ///////////////////////

    assign cmbrkgnti = dev_oBRKGNTI;    // pass grant from inner devs to cmem
    assign dev_iBRKGNTO = cmbrkgnto;    // pass grant from cmem to outer devs

    ////////////////////////////////
    //  shadow PDP-8/I processor  //
    ////////////////////////////////

    // verifies that the processor is doing what it should be doing

    pdp8ishad shadinst (
        .CLOCK      (CLOCK),
        .RESET      (~ RESET_N),

        .armwrite   (shawrite),
        .armraddr   (readaddr[4:2]),
        .armwaddr   (writeaddr[4:2]),
        .armwdata   (saxi_WDATA),
        .armrdata   (shardata),

        // all signals coming in from the bus
        .oACUM      (dev_oACUM),
        .oBRKCYC    (dev_oBRKCYC),
        .oBRKGNTI   (dev_oBRKGNTI),
        .oBRKRQST   (dev_oBRKRQST),
        .oBUSINI    (dev_oBUSINI),
        .oBWCOV     (dev_oBWCOV),
        .oIOP       (dev_oIOP),
        .oLINK      (dev_oLINK),
        .oMADR      (dev_oMADR),
        .oMBUF      (dev_oMBUF),
        .oMEAD      (dev_oMEAD),
        .oMAJST     (dev_oMAJST),
        .oRUN       (dev_oRUN),
        .oTP1       (dev_oTP1),
        .oTP2       (dev_oTP2),
        .oTP3       (dev_oTP3),
        .oTP4       (dev_oTP4),
        .oTS1       (dev_oTS1),
        .oTS2       (dev_oTS2),
        .oTS3       (dev_oTS3),
        .oTS4       (dev_oTS4),

        // fpga outputs these signals conditionally
        // otherwise we do not know their state on the bus
        .dmagntd    (cmdmagntd),
        .iBRKWRM    (dev_iBRKWRM),
        .iCAINC     (dev_iCAINC),
        .iCYCLE3    (dev_iCYCLE3),
        .iDMAFLD    (dev_iDMAFLD),

        .ioenabd    (~ hdw_ioenabd_n | simit),
        .iACCLEAR   (dev_iACCLEAR),
        .iINBUS     (dev_iINBUS),
        .iIOSKIP    (dev_iIOSKIP),

        .poweron    (~ hdw_poweron_n | simit),
        .iCLOCK     (dev_iCLOCK),
        .iMEMDIS    (dev_iMEMDIS),
        .iRESET     (dev_iRESET),
        .iBRKRQST   (dev_iBRKRQST),
        .iINTRQST   (dev_iINTRQST),
        .iPAUSE     (dev_iPAUSE),

        // stop clocking processor
        .freeze     (shad_freeze)
    );

    /////////////////////
    //  io interfaces  //
    /////////////////////

    // generate iopstart pulse for an io instruction followed by iopstop
    //  iopstart is pulsed at beginning of TP2, long after the dev_oACUM and dev_oMBUF bits are valid
    //   also gives plenty of time for reply data to make it back to the processor
    //  iopstop happens when the processor no longer wants the reply data

    reg iopstart, lasttp2;
    always @(posedge CLOCK) begin
        if (~ armwrite) begin
            iopstart <= ~ lasttp2 & dev_oTP2 & dev_oIOP;
            lasttp2  <= dev_oTP2;
        end else begin
            iopstart <= 0;
        end
    end

    wire iopstop = ~ dev_oIOP;

    // teletype interface

    pdp8itty ttinst (
        .CLOCK (CLOCK),
        .RESET (dev_iRESET),
        .BINIT (dev_oBUSINI),

        .armwrite (ttawrite),
        .armraddr (readaddr[3:2]),
        .armwaddr (writeaddr[3:2]),
        .armwdata (saxi_WDATA),
        .armrdata (ttardata),

        .iopstart (iopstart),
        .iopstop  (iopstop),
        .ioopcode (dev_oMBUF),
        .cputodev (dev_oACUM),

        .devtocpu (ttibus),
        .AC_CLEAR (ttacclr),
        .IO_SKIP  (ttioskp),
        .INT_RQST (ttintrq),
        .SELECTED (ttiosel)
    );

    // terminal multiplexor

    pdp8idc02 dcinst (
        .CLOCK (CLOCK),
        .RESET (dev_iRESET),
        .BINIT (dev_oBUSINI),

        .armwrite (dcawrite),
        .armraddr (readaddr[4:2]),
        .armwaddr (writeaddr[4:2]),
        .armwdata (saxi_WDATA),
        .armrdata (dcardata),

        .iopstart (iopstart),
        .iopstop  (iopstop),
        .ioopcode (dev_oMBUF),
        .cputodev (dev_oACUM),

        .devtocpu (dcibus),
        .AC_CLEAR (dcacclr),
        .IO_SKIP  (dcioskp),
        .INT_RQST (dcintrq),
        .SELECTED (dciosel)
    );

    // disk interface

    pdp8irk8je rkinst (
        .CLOCK (CLOCK),
        .RESET (dev_iRESET),
        .BINIT (dev_oBUSINI),

        .armwrite (rkawrite),
        .armraddr (readaddr[4:2]),
        .armwaddr (writeaddr[4:2]),
        .armwdata (saxi_WDATA),
        .armrdata (rkardata),

        .iopstart (iopstart),
        .iopstop  (iopstop),
        .ioopcode (dev_oMBUF),
        .cputodev (dev_oACUM),

        .devtocpu (rkibus),
        .AC_CLEAR (rkacclr),
        .IO_SKIP  (rkioskp),
        .INT_RQST (rkintrq),
        .SELECTED (rkiosel)
    );

    // core memory interface
    // gives arm access to the pdp's 4K core memory via pdp's dma interface
    // can also access the upper 28K via dma for testing
    // pdp must be running for this to work
    // does not process any pdp io instructions

    pdp8icmem cminst (
        .CLOCK (CLOCK),
        .RESET (dev_iRESET),

        .armwrite (cmawrite),                   //< arm writing to backside register
        .armraddr (readaddr[3:2]),              //< arm reading from backside register
        .armwaddr (writeaddr[3:2]),             //< arm writing to backside register
        .armwdata (saxi_WDATA),                 //< data to write to backside register
        .armrdata (cmardata),                   //> data being read from backside register

        .brk3cycl (cmbrk3cycl),                 //> dma 3-cycle
        .brkcainc (cmbrkcainc),                 //> increment current address in 3-cycle
        .brkwrite (cmbrkwrite),                 //> dma cycle wants to write memory
        .brkema   (cmbrkema),                   //> upper address bits
        .brkinbus (cmbrkinbus),                 //> address and write data
        .brkrqsto (cmbrkrqst),                  //> requesting dma cycle
        .brkgnto  (cmbrkgnto),                  //> outgoing dma grant
        .dmagntd  (cmdmagntd),                  //> granted use of dma bus signals

        .busini   (dev_oBUSINI),
        .brkrqsti (dev_oBRKRQST),               //< something is requesting dma cycle
        .brkgnti  (cmbrkgnti),                  //< incoming dma grant
        .brkmbuf  (dev_oMBUF),                  //< data read from memory
        .brkwcovf (dev_oBWCOV),                 //< wordcount overflow for 3-cycle
        .brkcycle (dev_oBRKCYC),                //< this is the BREAK cycle
        .brktp2   (dev_oTP2),
        .brkts2   (dev_oTS2),
        .brkts4   (dev_oTS4)
    );

    // tape interface

    pdp8itc08 tcinst (
        .CLOCK (CLOCK),
        .RESET (dev_iRESET),
        .BINIT (dev_oBUSINI),

        .armwrite (tcawrite),
        .armraddr (readaddr[2]),
        .armwaddr (writeaddr[2]),
        .armwdata (saxi_WDATA),
        .armrdata (tcardata),

        .iopstart (iopstart),
        .iopstop  (iopstop),
        .ioopcode (dev_oMBUF),
        .cputodev (dev_oACUM),

        .devtocpu (tcibus),
        .AC_CLEAR (tcacclr),
        .IO_SKIP  (tcioskp),
        .INT_RQST (tcintrq),
        .SELECTED (tciosel)
    );

    // video interface

    pdp8ivc8 vcinst (
        .CLOCK (CLOCK),
        .RESET (dev_iRESET),
        .BINIT (dev_oBUSINI),

        .armwrite (vcawrite),
        .armraddr (readaddr[4:2]),
        .armwaddr (writeaddr[4:2]),
        .armwdata (saxi_WDATA),
        .armrdata (vcardata),

        .iopstart (iopstart),
        .iopstop  (iopstop),
        .ioopcode (dev_oMBUF),
        .cputodev (dev_oACUM),

        .devtocpu (vcibus),
        .AC_CLEAR (vcacclr),
        .IO_SKIP  (vcioskp),
        .INT_RQST (vcintrq),
        .SELECTED (vciosel)
    );

    wire fpi2c_clock, fpi2c_datao, fpi2c_datai;

    assign hdw_iCONSCK = simit ? 1'b1 : fpi2c_clock;
    assign hdw_bCONSDA = simit ? 1'bZ : fpi2c_datao ? 1'bZ : 1'b0;
    assign hdw_iCONSDA = simit ? 1'b1 : fpi2c_datao;
    assign sim_iCONSCK = simit ? fpi2c_clock : 1'b1;
    assign sim_iCONSDA = simit ? fpi2c_datao : 1'b1;
    assign fpi2c_datai = simit ? sim_oCONSDA : BIDIRCONSDA ? hdw_bCONSDA : hdw_oCONSDA;

    // PDP-8/I front panel i2c interface
    pdp8ifpi2c fpi2cinst (
        .CLOCK  (CLOCK),
        .RESET  (~ RESET_N),
        .iRESET (dev_iRESET),

        .armwrite (fpi2cwrite),
        .armraddr (readaddr[5:2]),
        .armwaddr (writeaddr[5:2]),
        .armwdata (saxi_WDATA),
        .armrdata (fpi2crdata),

        .i2cclo (fpi2c_clock),
        .i2ccli (fpi2c_clock),
        .i2cdao (fpi2c_datao),
        .i2cdai (fpi2c_datai)
    );

    // paper tape reader interface
    pdp8iptr prinst (
        .CLOCK (CLOCK),
        .RESET (dev_iRESET),
        .BINIT (dev_oBUSINI),

        .armwrite (prawrite),
        .armraddr (readaddr[2]),
        .armwaddr (writeaddr[2]),
        .armwdata (saxi_WDATA),
        .armrdata (prardata),

        .iopstart (iopstart),
        .iopstop  (iopstop),
        .ioopcode (dev_oMBUF),
        .cputodev (dev_oACUM),

        .devtocpu (pribus),
        .AC_CLEAR (pracclr),
        .IO_SKIP  (prioskp),
        .INT_RQST (printrq),
        .SELECTED (priosel)
    );

    // pulse bit interface
    pdp8ipbit pbinst (
        .CLOCK (CLOCK),
        .RESET (dev_iRESET),

        .armwrite (pbawrite),
        .armraddr (readaddr[4:2]),
        .armwaddr (writeaddr[4:2]),
        .armwdata (saxi_WDATA),
        .armrdata (pbardata),

        .iopstart (iopstart),
        .iopstop  (iopstop),
        .ioopcode (dev_oMBUF),
        .cputodev (dev_oACUM),

        .devtocpu (pbibus),
        .AC_CLEAR (pbacclr),
        .IO_SKIP  (pbioskp),
        .SELECTED (pbiosel),

        .pulse (pulsebit)
    );

    // paper tape punch interface
    pdp8iptp ppinst (
        .CLOCK (CLOCK),
        .RESET (dev_iRESET),
        .BINIT (dev_oBUSINI),

        .armwrite (ppawrite),
        .armraddr (readaddr[2]),
        .armwaddr (writeaddr[2]),
        .armwdata (saxi_WDATA),
        .armrdata (ppardata),

        .iopstart (iopstart),
        .iopstop  (iopstop),
        .ioopcode (dev_oMBUF),
        .cputodev (dev_oACUM),

        .IO_SKIP  (ppioskp),
        .INT_RQST (ppintrq),
        .SELECTED (ppiosel)
    );

    // realtime clock interface

    pdp8irtc rcinst (
        .CLOCK (CLOCK),
        .RESET (dev_iRESET),
        .BINIT (dev_oBUSINI),

        .armwrite (rcawrite),
        .armraddr (readaddr[2]),
        .armwaddr (writeaddr[2]),
        .armwdata (saxi_WDATA),
        .armrdata (rcardata),

        .iopstart (iopstart),
        .iopstop  (iopstop),
        .ioopcode (dev_oMBUF),
        .cputodev (dev_oACUM),

        .devtocpu (rcibus),
        .AC_CLEAR (rcacclr),
        .IO_SKIP  (rcioskp),
        .INT_RQST (rcintrq),
        .SELECTED (rciosel)
    );

    // integrated logic analyzer
    //  ilaarmed = 0: trigger condition satisfied
    //             1: waiting for trigger condition
    //  ilaafter = number of cycles to record after trigger condition satisfied
    //  ilaindex = next entry in ilaarray to write

    reg lastldad;

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
                        arm_iRESET,
                        9'b0,
                        sim_iRESET,
                        sim_swldad,
                        sim_swdepos,
                        clkdiv,
                        sim_iCLOCK,
                        sim_majst,
                        sim_oTP1,
                        sim_oTP2,
                        sim_oTP3,
                        sim_oTP4,
                        sim_oTS1,
                        sim_oTS2,
                        sim_oTS3,
                        sim_oTS4
                    };

                    ilaindex <= ilaindex + 1;
                    if (~ ilaarmed) ilaafter <= ilaafter - 1;
                end

                // check trigger condition
                if (sim_run) begin
                    ilaarmed <= 0;
                end
            end
        end

        lastldad <= sim_swldad;
    end
endmodule
