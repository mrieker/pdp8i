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

module Zynq (
    input         CLOCK,
    input         RESET_N,
    output        LEDoutR,      // IO_B34_LN6 R14
    output        LEDoutG,      // IO_B34_LP7 Y16
    output        LEDoutB,      // IO_B34_LN7 Y17

    // io bus connections
    input[11:00]  hdw_oACUM,
    input         hdw_oBRKCYC,
    input         hdw_oBRKGNTI,
    input         hdw_oBRKRQST,
    input         hdw_oBUSINI,
    input         hdw_oBWCOV,
    input         hdw_oCLOCK,
    input         hdw_oIOP,
    input[11:00]  hdw_oMBUF,
    input         hdw_oRESET,
    input         hdw_oTP1,
    input         hdw_oTP2,
    input         hdw_oTP3,
    input         hdw_oTP4,
    input         hdw_oTS1,
    input         hdw_oTS2,
    input         hdw_oTS3,
    input         hdw_oTS4,

    output        hdw_iACCLEAR,
    output        hdw_iBRKGNTO,
    output        hdw_iBRKRQST,
    output        hdw_iBRKWRM,
    output        hdw_iCAINC,
    output        hdw_iCYCLE3,
    output[2:0]   hdw_iDMAFLD,
    output[11:00] hdw_iINBUS,
    output        hdw_iINTRQST,
    output        hdw_iIOSKIP,
    output        hdw_iPAUSE,

    // i2c interface to hardware front panel
    output        fpi2c_clock,
    output        fpi2c_datao,
    input         fpi2c_datai,

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

    //  dev_i... : signals from io devices going to both hdw_i... and sim_i...
    //  dev_o... : selected from hdw_o... or sim_o... going to io devices

    wire[31:00] regctla, regctlb, regctlc, regctld, regctle, regctlf, regctlg, regctlh, regctli, regctlj, regctlk;

    wire[11:00] sim_oACUM;
    wire        sim_oBRKCYC;
    wire        sim_oBRKGNTI;
    wire        sim_oBRKRQST;
    wire        sim_oBUSINI;
    wire        sim_oBWCOV;
    wire        sim_oCLOCK;
    wire        sim_oIOP;
    wire[11:00] sim_oMBUF;
    wire        sim_oRESET;
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
    wire        sim_iCYCLE3;
    wire[2:0]   sim_iDMAFLD;
    wire[11:00] sim_iINBUS;
    wire        sim_iINTRQST;
    wire        sim_iIOSKIP;
    wire        sim_iPAUSE;

    wire[11:00] sim_lbAC;
    wire        sim_lbBRK;
    wire        sim_lbCA;
    wire        sim_lbDEF;
    wire        sim_lbEA;
    wire        sim_lbEXE;
    wire        sim_lbFET;
    wire        sim_lbION;
    wire[2:0]   sim_lbIR;
    wire        sim_lbLINK;
    wire[11:00] sim_lbMA;
    wire[11:00] sim_lbMB;
    wire        sim_lbRUN;
    wire        sim_lbWC;

    wire[11:00] dev_oACUM;
    wire        dev_oBRKCYC;
    wire        dev_oBRKGNTI;
    wire        dev_oBRKRQST;
    wire        dev_oBUSINI;
    wire        dev_oBWCOV;
    wire        dev_oCLOCK;
    wire        dev_oIOP;
    wire[11:00] dev_oMBUF;
    wire        dev_oRESET;
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
    wire        dev_iCYCLE3;
    wire[2:0]   dev_iDMAFLD;
    wire[11:00] dev_iINBUS;
    wire        dev_iINTRQST;
    wire        dev_iIOSKIP;
    wire        dev_iPAUSE;

    reg[9:0] meminprog;

    reg bareit, simit, lastts1, lastts3, didio;
    reg nanocontin, nanocstep, nanotrigger, fpgareset;
    wire acclr, intrq, ioskp;
    reg[3:0] iopsetcount;               // count fpga cycles where an IOP is on
    reg[3:0] iopclrcount;               // count fpga cycles where no IOP is on
    reg[31:00] memcycctr;

    // arm interface wires;
    reg        arm_iACCLEAR;
    reg        arm_iBRKGNTO;
    reg        arm_iBRKRQST;
    reg        arm_iBRKWRM;
    reg        arm_iCAINC;
    reg        arm_iCYCLE3;
    reg[2:0]   arm_iDMAFLD;
    reg[11:00] arm_iINBUS;
    reg        arm_iINTRQST;
    reg        arm_iIOSKIP;
    reg        arm_iPAUSE;
    reg        arm_swCONT;
    reg        arm_swDEP;
    reg[2:0]   arm_swDFLD;
    reg        arm_swEXAM;
    reg[2:0]   arm_swIFLD;
    reg        arm_swLDAD;
    reg        arm_swSINST;
    reg        arm_swSSTEP;
    reg        arm_swSTOP;
    reg        arm_swSTART;
    reg[11:00] arm_swSR;

    reg arm_hizmembus, dev_hizmembus;
    wire hizmembus;

    // shadow interface wires
    wire[31:00] shardata;

    // tty interface wires
    wire[31:00] ttardata;
    wire[11:00] ttibus;
    wire ttacclr, ttintrq, ttioskp;

    // dc02 interface wires
    wire[31:00] dcardata;
    wire[11:00] dcibus;
    wire dcacclr, dcintrq, dcioskp;

    // disk interface wires
    wire[31:00] rkardata;
    wire[11:00] rkibus;
    wire rkacclr, rkintrq, rkioskp;

    // front panel i2c interface
    wire[31:00] fpi2crdata;

    // extended memory interface wires
    wire[31:00] xmardata;
    wire[11:00] xmibus;
    wire[11:00] xmmem;
    wire[2:0] xmfield;
    wire xm_intinh, xm_mrdone, xm_mwdone, xm_ea;

    // core memory interface wires
    wire[31:00] cmardata;
    wire cmbrkrqst, cmbrkwrite, cmbrk3cycl, cmbrkcainc;
    wire[11:00] cmbrkaddr, cmbrkwdat;
    wire[2:0] cmbrkema;

    // tape interface wires
    wire[31:00] tcardata;
    wire[11:00] tcibus;
    wire tcacclr, tcintrq, tcioskp;

    // paper tape reader interface wires
    wire[31:00] prardata;
    wire[11:00] pribus;
    wire pracclr, printrq, prioskp;

    // paper tape punch interface wires
    wire[31:00] ppardata;
    wire ppintrq, ppioskp;

    // video interface wires
    wire[31:00] vcardata;
    wire[11:00] vcibus;
    wire vcacclr, vcintrq, vcioskp;

    // pulsebit interface wires
    wire[31:00] pbardata;
    wire[11:00] pbibus;
    wire pbacclr, pbioskp;
    wire pulsebit;

    // bus values that are constants
    assign saxi_BRESP = 0;  // A3.4.4/A10.3 transfer OK
    assign saxi_RRESP = 0;  // A3.4.4/A10.3 transfer OK

    reg[14:00] ilaarray[4095:0], ilardata;
    reg[11:00] ilaafter, ilaindex;
    reg ilaarmed;

    // some arm program is resetting or zynq is powering up
    // - resets devices
    wire pwronreset = fpgareset | ~ RESET_N;

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
        (readaddr        == 10'b0000001010) ? regctlj    :
        (readaddr        == 10'b0000001011) ? regctlk    :
        (readaddr        == 10'b0000001110) ? memcycctr  :
        (readaddr        == 10'b0000010001) ? { ilaarmed, 3'b0, ilaafter, 4'b0, ilaindex } :
        (readaddr        == 10'b0000010010) ? { 17'b0, ilardata[14:00] } :
        (readaddr        == 10'b0000010011) ? { 32'b0                  } :
        (readaddr[11:05] ==  7'b0000100)    ? rkardata   :
        (readaddr[11:05] ==  7'b0000101)    ? vcardata   :
        (readaddr[11:05] ==  7'b0000110)    ? fpi2crdata :
        (readaddr[11:05] ==  7'b0000111)    ? pbardata   :
        (readaddr[11:05] ==  7'b0001000)    ? xmardata   :
        (readaddr[11:05] ==  7'b0001001)    ? shardata   :
        (readaddr[11:05] ==  7'b0001010)    ? dcardata   :
        (readaddr[11:04] ==  8'b00010110)   ? cmardata   :
        (readaddr[11:04] ==  8'b00010111)   ? ttardata   :
        (readaddr[11:03] ==  9'b000110000)  ? prardata   :
        (readaddr[11:03] ==  9'b000110001)  ? ppardata   :
        (readaddr[11:03] ==  9'b000110010)  ? tcardata   :
        32'hDEADBEEF;

    wire armwrite   = saxi_WREADY & saxi_WVALID;    // arm is writing a register (single fpga clock cycle)
    wire rkawrite   = armwrite & writeaddr[11:05] == 7'b0000100;
    wire vcawrite   = armwrite & writeaddr[11:05] == 7'b0000101;
    wire fpi2cwrite = armwrite & writeaddr[11:05] == 7'b0000110;
    wire pbawrite   = armwrite & writeaddr[11:05] == 7'b0000111;
    wire xmawrite   = armwrite & writeaddr[11:05] == 7'b0001000;
    wire shawrite   = armwrite & writeaddr[11:05] == 7'b0001001;
    wire dcawrite   = armwrite & writeaddr[11:05] == 7'b0001010;
    wire cmawrite   = armwrite & writeaddr[11:04] == 8'b00010110;
    wire ttawrite   = armwrite & writeaddr[11:04] == 8'b00010111;
    wire prawrite   = armwrite & writeaddr[11:03] == 9'b000110000;
    wire ppawrite   = armwrite & writeaddr[11:03] == 9'b000110001;
    wire tcawrite   = armwrite & writeaddr[11:03] == 9'b000110010;

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

            simit       <= 0;                           // assume want to access real PDP-8/I by default
            fpgareset   <= 0;                           // we are resetting FPGA, don't do infinite reset loop
            nanocontin  <= 1;                           // turn on 100MHz FPGA clocking
            bareit      <= 0;                           // normal signals by default (not manual override)

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
                        arm_iACCLEAR <= saxi_WDATA[00];
                        arm_iBRKGNTO <= saxi_WDATA[01];
                        arm_iBRKRQST <= saxi_WDATA[02];
                        arm_iBRKWRM  <= saxi_WDATA[03];
                        arm_iCAINC   <= saxi_WDATA[04];
                        arm_iCYCLE3  <= saxi_WDATA[05];
                        arm_iDMAFLD  <= saxi_WDATA[08:06];
                        arm_iINBUS   <= saxi_WDATA[20:09];
                        arm_iINTRQST <= saxi_WDATA[21];
                        arm_iIOSKIP  <= saxi_WDATA[22];
                        arm_iPAUSE   <= saxi_WDATA[23];
                    end

                    10'b0000000010: begin
                        arm_swCONT   <= saxi_WDATA[00];
                        arm_swDEP    <= saxi_WDATA[01];
                        arm_swDFLD   <= saxi_WDATA[04:02];
                        arm_swEXAM   <= saxi_WDATA[05];
                        arm_swIFLD   <= saxi_WDATA[08:06];
                        arm_swLDAD   <= saxi_WDATA[09];
                        arm_swSINST  <= saxi_WDATA[10];
                        arm_swSSTEP  <= saxi_WDATA[11];
                        arm_swSTOP   <= saxi_WDATA[12];
                        arm_swSTART  <= saxi_WDATA[13];
                        arm_swSR     <= saxi_WDATA[25:14];
                    end

                    10'b0000000101: begin
                        simit        <= saxi_WDATA[00];
                        fpgareset    <= saxi_WDATA[01];
                        nanocontin   <= saxi_WDATA[02];
                        bareit       <= saxi_WDATA[06];
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

        if (~ armwrite & pwronreset) begin
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
            arm_iPAUSE   <= 0;
            arm_swCONT   <= 0;
            arm_swDEP    <= 0;
            arm_swDFLD   <= 0;
            arm_swEXAM   <= 0;
            arm_swIFLD   <= 0;
            arm_swLDAD   <= 0;
            arm_swSINST  <= 0;
            arm_swSSTEP  <= 0;
            arm_swSTOP   <= 0;
            arm_swSTART  <= 0;
            arm_swSR     <= 0;
        end
    end

    /////////////////////////////////////////////////
    //  synchronize signals output by the PDP-8/I  //
    /////////////////////////////////////////////////

    wire hsy_oBRKGNTI, hsy_oBRKRQST, hsy_oBUSINI, hsy_oCLOCK, hsy_oIOP, hsy_oRESET, hsy_oTP1;
    wire hsy_oTP2,     hsy_oTP3,     hsy_oTP4,    hsy_oTS1,   hsy_oTS2, hsy_oTS3,   hsy_oTS4;

    synk synkbg (CLOCK, hsy_oBRKGNTI, hdw_oBRKGNTI);
    synk synkbr (CLOCK, hsy_oBRKRQST, hdw_oBRKRQST);
    synk synkbi (CLOCK, hsy_oBUSINI,  hdw_oBUSINI);
    synk synkcl (CLOCK, hsy_oCLOCK,   hdw_oCLOCK);
    synk synkip (CLOCK, hsy_oIOP,     hdw_oIOP);
    synk synkrs (CLOCK, hsy_oRESET,   hdw_oRESET);
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
    assign sim_iBRKGNTO = simit ? dev_iBRKGNTO : 0;
    assign sim_iBRKRQST = simit ? dev_iBRKRQST : 0;
    assign sim_iBRKWRM  = simit ? dev_iBRKWRM  : 0;
    assign sim_iCAINC   = simit ? dev_iCAINC   : 0;
    assign sim_iCYCLE3  = simit ? dev_iCYCLE3  : 0;
    assign sim_iDMAFLD  = simit ? dev_iDMAFLD  : 0;
    assign sim_iINBUS   = simit ? dev_iINBUS   : 0;
    assign sim_iINTRQST = simit ? dev_iINTRQST : 0;
    assign sim_iIOSKIP  = simit ? dev_iIOSKIP  : 0;
    assign sim_iPAUSE   = simit ? dev_iPAUSE   : 0;

    assign hdw_iACCLEAR = simit ? 0 : dev_iACCLEAR;
    assign hdw_iBRKGNTO = simit ? hdw_oBRKGNTI : dev_iBRKGNTO;
    assign hdw_iBRKRQST = simit ? 0 : dev_iBRKRQST;
    assign hdw_iBRKWRM  = simit ? 0 : dev_iBRKWRM;
    assign hdw_iCAINC   = simit ? 0 : dev_iCAINC;
    assign hdw_iCYCLE3  = simit ? 0 : dev_iCYCLE3;
    assign hdw_iDMAFLD  = simit ? 0 : dev_iDMAFLD;
    assign hdw_iINBUS   = simit ? 0 : dev_iINBUS;
    assign hdw_iINTRQST = simit ? 0 : dev_iINTRQST;
    assign hdw_iIOSKIP  = simit ? 0 : dev_iIOSKIP;
    assign hdw_iPAUSE   = simit ? 0 : dev_iPAUSE;

    // when simulating, send signals from the simulated PDP-8/I on to the devices
    // when not simming, send signals from the hardware PDP-8/I on to the devices

    assign dev_oACUM    = simit ? sim_oACUM    : hdw_oACUM;
    assign dev_oBRKCYC  = simit ? sim_oBRKCYC  : hdw_oBRKCYC;
    assign dev_oBRKGNTI = simit ? sim_oBRKGNTI : hsy_oBRKGNTI;
    assign dev_oBRKRQST = simit ? sim_oBRKRQST : hsy_oBRKRQST;
    assign dev_oBUSINI  = simit ? sim_oBUSINI  : hsy_oBUSINI;
    assign dev_oBWCOV   = simit ? sim_oBWCOV   : hdw_oBWCOV;
    assign dev_oCLOCK   = simit ? sim_oCLOCK   : hsy_oCLOCK;
    assign dev_oIOP     = simit ? sim_oIOP     : hsy_oIOP;
    assign dev_oMBUF    = simit ? sim_oMBUF    : hdw_oMBUF;
    assign dev_oRESET   = simit ? sim_oRESET   : hsy_oRESET;
    assign dev_oTP1     = simit ? sim_oTP1     : hsy_oTP1;
    assign dev_oTP2     = simit ? sim_oTP2     : hsy_oTP2;
    assign dev_oTP3     = simit ? sim_oTP3     : hsy_oTP3;
    assign dev_oTP4     = simit ? sim_oTP4     : hsy_oTP4;
    assign dev_oTS1     = simit ? sim_oTS1     : hsy_oTS1;
    assign dev_oTS2     = simit ? sim_oTS2     : hsy_oTS2;
    assign dev_oTS3     = simit ? sim_oTS3     : hsy_oTS3;
    assign dev_oTS4     = simit ? sim_oTS4     : hsy_oTS4;

    // reading arm registers gets device bus signals
    //  for 'i' signals: wired-or of all devices and what was written to arm registers
    //  for 'o' signals: selected signal from simulated PDP-8/I or real PDP-8/I

    assign regctla[00]    = dev_iACCLEAR;
    assign regctla[01]    = dev_iBRKGNTO;
    assign regctla[02]    = dev_iBRKRQST;
    assign regctla[03]    = dev_iBRKWRM;
    assign regctla[04]    = dev_iCAINC;
    assign regctla[05]    = dev_iCYCLE3;
    assign regctla[08:06] = dev_iDMAFLD;
    assign regctla[20:09] = dev_iINBUS;
    assign regctla[21]    = dev_iINTRQST;
    assign regctla[22]    = dev_iIOSKIP;
    assign regctla[23]    = dev_iPAUSE;
    assign regctla[31:24] = 0;

    assign regctlb[00]    = arm_swCONT;
    assign regctlb[01]    = arm_swDEP;
    assign regctlb[04:02] = arm_swDFLD;
    assign regctlb[05]    = arm_swEXAM;
    assign regctlb[08:06] = arm_swIFLD;
    assign regctlb[09]    = arm_swLDAD;
    assign regctlb[10]    = arm_swSINST;
    assign regctlb[11]    = arm_swSSTEP;
    assign regctlb[12]    = arm_swSTOP;
    assign regctlb[13]    = arm_swSTART;
    assign regctlb[25:14] = arm_swSR;
    assign regctlb[31:26] = 0;

    assign regctlc[15:00] = 0;
    assign regctlc[31:16] = 0;
    assign regctld[11:00] = dev_oMBUF;
    assign regctld[31:12] = 0;

    assign regctle[00]    = simit;
    assign regctle[01]    = fpgareset;
    assign regctle[02]    = nanocontin;
    assign regctle[03]    = nanotrigger;
    assign regctle[04]    = nanocstep;
    assign regctle[05]    = 0;
    assign regctle[06]    = bareit;
    assign regctle[31:07] = 0;

    assign regctlf[11:00] = dev_oACUM;
    assign regctlf[12]    = dev_oBRKCYC;
    assign regctlf[13]    = dev_oBRKGNTI;
    assign regctlf[14]    = dev_oBRKRQST;
    assign regctlf[15]    = dev_oBUSINI;
    assign regctlf[16]    = dev_oBWCOV;
    assign regctlf[17]    = dev_oCLOCK;
    assign regctlf[18]    = dev_oIOP;
    assign regctlf[19]    = dev_oRESET;
    assign regctlf[20]    = dev_oTP1;
    assign regctlf[21]    = dev_oTP2;
    assign regctlf[22]    = dev_oTP3;
    assign regctlf[23]    = dev_oTP4;
    assign regctlf[24]    = dev_oTS1;
    assign regctlf[25]    = dev_oTS2;
    assign regctlf[26]    = dev_oTS3;
    assign regctlf[27]    = dev_oTS4;
    assign regctlf[31:28] = 0;

    assign regctlg[00]    = sim_lbBRK;
    assign regctlg[01]    = sim_lbCA;
    assign regctlg[02]    = sim_lbDEF;
    assign regctlg[03]    = sim_lbEA;
    assign regctlg[04]    = sim_lbEXE;
    assign regctlg[05]    = sim_lbFET;
    assign regctlg[06]    = sim_lbION;
    assign regctlg[07]    = sim_lbLINK;
    assign regctlg[08]    = sim_lbRUN;
    assign regctlg[09]    = sim_lbWC;
    assign regctlg[10]    = debounced;
    assign regctlg[11]    = lastswLDAD;
    assign regctlg[12]    = lastswSTART;
    assign regctlg[13]    = simmemen;
    assign regctlg[14]    = 0;
    assign regctlg[15]    = 0;
    assign regctlg[27:16] = { sim_lbIR, 9'b000000000 };
    assign regctlg[31:28] = 0;

    assign regctlh[15:00] = 0;
    assign regctlh[31:16] = 0;
    assign regctli[15:00] = 0;
    assign regctli[31:16] = { 4'b0, sim_lbAC };
    assign regctlj[15:00] = { 4'b0, sim_lbMA };
    assign regctlj[31:16] = { 4'b0, sim_lbMB };

    // count memory cycles
    // dectape uses it for timing in z8ltc08.cc
    always @(posedge CLOCK) begin
        if (~ RESET_N) begin
            memcycctr <= 0;
        end else if (~ lastts3 & dev_oTS3) begin
            memcycctr <= memcycctr + 1;
        end
    end

    // see if PDP is doing stuff with the busses
    // everything the PDP does begins with a MEMSTART pulse and lasts less than 5uS
    // so we start a counter at 1023 at memstart and count it down to 0 (taking 10.23uS)
    // ...restarting whenever we see memstart
    // this is kind of like RUN, but takes into account cycles initiated by the console
    always @(posedge CLOCK) begin
        if (pwronreset) begin
            meminprog <= 0;
        end else if (nanocstep) begin
            if (dev_oTS1) begin
                meminprog <= 1023;
            end else if (meminprog != 0) begin
                meminprog <= meminprog - 1;
            end
        end
    end

    // internal pio busses - wire-ored(active high)/-anded(active low) from device to processor
    // block device outputs if bareit so pins can be directly controlled by arm
    wire[2:0]   barei3 = {  3 { bareit } };
    wire[11:00] bare12 = { 12 { bareit } };
    assign dev_iACCLEAR = arm_iACCLEAR | bareit & (ttacclr | rkacclr | vcacclr | tcacclr | pracclr | pbacclr | dcacclr);
    assign dev_iBRKRQST = arm_iBRKRQST | bareit & cmbrkrqst;
    assign dev_iBRKWRM  = arm_iBRKWRM  | bareit & cmbrkwrite;
    assign dev_iCAINC   = arm_iCAINC   | bareit & cmbrkcainc;
    assign dev_iCYCLE3  = arm_iCYCLE3  | bareit & cmbrk3cycl;
    assign dev_iDMAFLD  = arm_iDMAFLD  | barei3 & cmbrkema;
    assign dev_iINBUS   = arm_iINBUS   | bare12 & (ttibus  | rkibus | vcibus | xmibus | tcibus | pribus | pbibus | dcibus);
    assign dev_iINTRQST = arm_iINTRQST | bareit & (ttintrq | rkintrq | vcintrq | tcintrq | printrq | ppintrq | dcintrq);
    assign dev_iIOSKIP  = arm_iIOSKIP  | bareit & (ttioskp | rkioskp | vcioskp | tcioskp | prioskp | ppioskp | pbioskp | dcioskp);
    assign dev_iPAUSE   = arm_iPAUSE   | bareit & xm_mwdone;

    ///////////////////////////////////
    //  simulated PDP-8/I processor  //
    ///////////////////////////////////

    // when nanocontin is set to 1 by the arm,
    //   this continuously shifts 1s into nanotrigger and nanoctep and everything runs normally
    // when nanocontin is set to 0 by the arm,
    //   it continuously shifts 0s into nanotrigger and nanocstep and everything stops
    //   but then when a 1 is written to nanotrigger by the arm,
    //     it shifts a 1 into nanocstep for 1 cycle and so everyting steps exactly one cycle
    //     then it resumes shifting 0s into nanotrigger and nanocstep so everything stops
    //     thus cstep lasts for a single cycle separate from an arm write
    always @(posedge CLOCK) begin
        if (~ RESET_N) begin
            nanotrigger <= 0;
            nanocstep   <= 0;
        end else begin
            // we can shift nanotrigger only when it is not being written by the arm
            nanotrigger <= (armwrite & (writeaddr == 10'b0000000101)) ? saxi_WDATA[03] : nanocontin;
            // nanocstep is read-only to the arm so can always be shifted other than reset
            nanocstep   <= nanotrigger;
        end
    end

    assign LEDoutR = simit;
    assign LEDoutG = ~ (dev_oTS1 | dev_oTS2 | dev_oTS3 | dev_oTS4);
    assign LEDoutB = 1;
/***
    pdp8isim siminst (
        .CLOCK          (CLOCK),
        .CSTEP          (nanocstep),
        .RESET          (pwronreset | ~ simit),

        .iACCLEAR       (sim_iACCLEAR),
        .iBRKGNTO       (sim_iBRKGNTO),
        .iBRKRQST       (sim_iBRKRQST),
        .iBRKWRM        (sim_iBRKWRM),
        .iCAINC         (sim_iCAINC),
        .iCYCLE3        (sim_iCYCLE3),
        .iDMAFLD        (sim_iDMAFLD),
        .iINBUS         (sim_iINBUS),
        .iINTRQST       (sim_iINTRQST),
        .iIOSKIP        (sim_iIOSKIP),
        .iPAUSE         (sim_iPAUSE),

        .oACUM          (sim_oACUM),
        .oBRKCYC        (sim_oBRKCYC),
        .oBRKGNTI       (sim_oBRKGNTI),
        .oBRKRQST       (sim_oBRKRQST),
        .oBUSINI        (sim_oBUSINI),
        .oBWCOV         (sim_oBWCOV),
        .oCLOCK         (sim_oCLOCK),
        .oIOP           (sim_oIOP),
        .oMBUF          (sim_oMBUF),
        .oRESET         (sim_oRESET),
        .oTP1           (sim_oTP1),
        .oTP2           (sim_oTP2),
        .oTP3           (sim_oTP3),
        .oTP4           (sim_oTP4),
        .oTS1           (sim_oTS1),
        .oTS2           (sim_oTS2),
        .oTS3           (sim_oTS3),
        .oTS4           (sim_oTS4),

        .lbAC           (sim_lbAC),
        .lbBRK          (sim_lbBRK),
        .lbCA           (sim_lbCA),
        .lbDEF          (sim_lbDEF),
        .lbEA           (sim_lbEA),
        .lbEXE          (sim_lbEXE),
        .lbFET          (sim_lbFET),
        .lbION          (sim_lbION),
        .lbIR           (sim_lbIR),
        .lbLINK         (sim_lbLINK),
        .lbMA           (sim_lbMA),
        .lbMB           (sim_lbMB),
        .lbRUN          (sim_lbRUN),
        .lbWC           (sim_lbWC),

        .swCONT         (arm_swCONT),
        .swDEP          (arm_swDEP),
        .swDFLD         (arm_swDFLD),
        .swEXAM         (arm_swEXAM),
        .swIFLD         (arm_swIFLD),
        .swLDAD         (arm_swLDAD),
        .swSINST        (arm_swSINST),
        .swSSTEP        (arm_swSSTEP),
        .swSTOP         (arm_swSTOP),
        .swSR           (arm_swSR),
        .swSTART        (arm_swSTART),

        .majstate       (regctlk[03:00]),
        .timedelay      (regctlk[09:04]),
        .timestate      (regctlk[14:10]),
        .cyclectr       (regctlk[24:15]),
        .nextmajst      (regctlk[28:25]),
        .debounced      (debounced),
        .lastswLDAD     (lastswLDAD),
        .lastswSTART    (lastswSTART),
        .memen          (simmemen)
    );
***/
    assign regctlk[31:29] = 0;

    ///////////////////////
    //  DMA grant chain  //
    ///////////////////////

    assign dev_iBRKGNTO = dev_oBRKGNTI;

    ////////////////////////////////
    //  shadow PDP-8/I processor  //
    ////////////////////////////////

    wire shad_error, shad_freeze;
    wire[3:0] shad_tstate;
    wire[3:0] shad_tdelay;
/***
    pdp8ishad shadinst (
        .CLOCK (CLOCK),
        .CSTEP (nanocstep),
        .RESET (pwronreset),

        .armwrite (shawrite),
        .armraddr (readaddr[4:2]),
        .armwaddr (writeaddr[4:2]),
        .armwdata (saxi_WDATA),
        .armrdata (shardata),

        .iACCLEAR       (dev_iACCLEAR),
        .iBRKGNTO       (dev_iBRKGNTO),
        .iBRKRQST       (dev_iBRKRQST),
        .iBRKWRM        (dev_iBRKWRM),
        .iCAINC         (dev_iCAINC),
        .iCYCLE3        (dev_iCYCLE3),
        .iDMAFLD        (dev_iDMAFLD),
        .iINBUS         (dev_iINBUS),
        .iINTRQST       (dev_iINTRQST),
        .iIOSKIP        (dev_iIOSKIP),
        .iPAUSE         (dev_iPAUSE),

        .oACUM          (dev_oACUM),
        .oBRKCYC        (dev_oBRKCYC),
        .oBRKGNTI       (dev_oBRKGNTI),
        .oBRKRQST       (dev_oBRKRQST),
        .oBUSINI        (dev_oBUSINI),
        .oBWCOV         (dev_oBWCOV),
        .oCLOCK         (dev_oCLOCK),
        .oIOP           (dev_oIOP),
        .oMBUF          (dev_oMBUF),
        .oRESET         (dev_oRESET),
        .oTP1           (dev_oTP1),
        .oTP2           (dev_oTP2),
        .oTP3           (dev_oTP3),
        .oTP4           (dev_oTP4),
        .oTS1           (dev_oTS1),
        .oTS2           (dev_oTS2),
        .oTS3           (dev_oTS3),
        .oTS4           (dev_oTS4),

        .timestate      (shad_tstate),
        .timedelay      (shad_tdelay),
        .error          (shad_error),
        .freeze         (shad_freeze)
    );
***/
    /////////////////////
    //  io interfaces  //
    /////////////////////

    wire iobusreset = pwronreset | dev_oBUSINI;     // power on reset or start switch

    // generate iopstart pulse for an io instruction followed by iopstop
    //  iopstart is pulsed at beginning of TP2, long after the dev_oACUM and dev_oMBUF bits are valid
    //   also gives plenty of time for reply data to make it back to the processor
    //  iopstop happens when the processor no longer wants the reply data

    reg iopstart, lasttp2;
    always @(posedge CLOCK) begin
        if (armwrite) begin
            iopstart <= ~ lasttp2 & dev_oTS3 & dev_oIOP;
            lastts3  <= dev_oTP2;
        end else begin
            iopstart <= 0;
        end
        
    end

    wire iopstop = ~ dev_oIOP;

    // teletype interface

    pdp8ltty ttinst (
        .CLOCK (CLOCK),
        .CSTEP (nanocstep),
        .RESET (pwronreset),
        .BINIT (iobusreset),

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
        .INT_RQST (ttintrq)
    );

    // terminal multiplexor

    pdp8ldc02 dcinst (
        .CLOCK (CLOCK),
        .CSTEP (nanocstep),
        .RESET (pwronreset),
        .BINIT (iobusreset),

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
        .INT_RQST (dcintrq)
    );

    // disk interface

    pdp8lrk8je rkinst (
        .CLOCK (CLOCK),
        .CSTEP (nanocstep),
        .RESET (pwronreset),
        .BINIT (iobusreset),

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
        .INT_RQST (rkintrq)
    );

    // core memory interface
    // gives arm access to the pdp's 4K core memory via pdp's dma interface
    // can also access the upper 28K via dma for testing
    // pdp must be running for this to work
    // does not process any pdp io instructions

    wire cmnobrkopt;
    wire[4:0] cmbusyonarm;

    pdp8lcmem cminst (
        .CLOCK (CLOCK),
        .CSTEP (nanocstep),
        .RESET (pwronreset),

        .armwrite (cmawrite),                   //< arm writing to backside register
        .armraddr (readaddr[3:2]),              //< arm reading from backside register
        .armwaddr (writeaddr[3:2]),             //< arm writing to backside register
        .armwdata (saxi_WDATA),                 //< data to write to backside register
        .armrdata (cmardata),                   //> data being read from backside register

        .brkrqst  (cmbrkrqst),                  //> dma cycle being requested
        .brkwrite (cmbrkwrite),                 //> dma cycle wants to write memory
        .brk3cycl (cmbrk3cycl),                 //> dma 3-cycle
        .brkcainc (cmbrkcainc),                 //> increment current address in 3-cycle
        .brkema   (cmbrkema),                   //> upper address bits
        .brkaddr  (cmbrkaddr),                  //> lower address bits
        .brkwdat  (cmbrkwdat),                  //> data to write to memory
        .brkrdat  (dev_oMBUF),                  //< data read from memory
        .brkcycle (dev_oBRKCYC),                //< this is the BREAK cycle
        .brkts1   (dev_oTS1),                   //< TS1 of memory cycle (memory read occurring)
        .brkts3   (dev_oTS3),                   //< TS3 of memory cycle (memory writeback occurring)
        .brkwcovf (dev_oBWCOV),                 //< wordcount overflow for 3-cycle

        .busyonarm (cmbusyonarm)
    );

    // tape interface

    pdp8ltc08 tcinst (
        .CLOCK (CLOCK),
        .CSTEP (nanocstep),
        .RESET (pwronreset),
        .BINIT (iobusreset),

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
        .INT_RQST (tcintrq)
    );

    // video interface
/***
    pdp8lvc8 vcinst (
        .CLOCK (CLOCK),
        .CSTEP (nanocstep),
        .RESET (pwronreset),
        .BINIT (iobusreset),

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

        .vidaddra (vidaddra),
        .vidaddrb (vidaddrb),
        .viddataa (viddataa),
        .videnaba (videnaba),
        .vidwrena (vidwrena),
        .videnabb (videnabb),
        .viddatab (viddatab)
    );
***/
    // real PDP-8/I front panel i2c interface
    // connects to pipan8l/pcb board i2c interface
    wire[2:0] i2cstate;
    wire[14:00] i2ccount;
    wire[63:00] i2cstatus;
    pdp8lfpi2c fpi2cinst (
        .CLOCK (CLOCK),
        .RESET (~ RESET_N),

        .armwrite (fpi2cwrite),
        .armraddr (readaddr[4:2]),
        .armwaddr (writeaddr[4:2]),
        .armwdata (saxi_WDATA),
        .armrdata (fpi2crdata),

        .i2cclo (fpi2c_clock),
        .i2ccli (fpi2c_clock),
        .i2cdao (fpi2c_datao),
        .i2cdai (fpi2c_datai),

        .i2cstate (i2cstate),
        .i2ccount (i2ccount),
        .status (i2cstatus),
        .comand ()
    );

    // paper tape reader interface
    pdp8lptr prinst (
        .CLOCK (CLOCK),
        .CSTEP (nanocstep),
        .RESET (pwronreset),
        .BINIT (iobusreset),

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
        .INT_RQST (printrq)
    );

    // pulse bit interface
    pdp8lpbit pbinst (
        .CLOCK (CLOCK),
        .CSTEP (nanocstep),
        .RESET (pwronreset),

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

        .pulse (pulsebit)
    );

    // paper tape punch interface
    pdp8lptp ppinst (
        .CLOCK (CLOCK),
        .CSTEP (nanocstep),
        .RESET (pwronreset),
        .BINIT (iobusreset),

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
        .INT_RQST (ppintrq)
    );

    // integrated logic analyzer
    //  ilaarmed = 0: trigger condition satisfied
    //             1: waiting for trigger condition
    //  ilaafter = number of cycles to record after trigger condition satisfied
    //  ilaindex = next entry in ilaarray to write

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
                        sim_iDMAFLD,
                        sim_iINBUS
                    };

                    ilaindex <= ilaindex + 1;
                    if (~ ilaarmed) ilaafter <= ilaafter - 1;
                end

                // check trigger condition
                // - disk controller requesting dma cycle
                if (sim_iDMAFLD != 0) begin
                    ilaarmed <= 0;
                end
            end
        end
    end
endmodule
