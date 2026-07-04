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

// backplane model connects the circuit boards together for testing
// top-level module for verimain

module backplane (
    input yclock,                   // 100MHz clock for FPGA
    input zclock,                   // 200MHz clock for gate delays
    input zreset,                   // power-on reset

    input[15:04] gpin,              // switches from verimain.cc
    output[27:04] gpout,            // light bulbs to verimain.cc
                                    // - also has row selectors

    input iACCLEAR,                 // io pulse clears AC
    input iBRKGNTI,                 // chained break grant
    input iBRKRQST,                 // requesting break
    input iBRKWRM,                  // break cycle writes memory
    input iCAINC,                   // curad cycle increments address word
    input iCYCLE3,                  // do 3-cycle break
    input iINTRQST,                 // request interrupt
    input iIOSKIP,                  // increment PC at end of IO pulse
    input[2:0] iDMAFLD,             // device sending address for DMA
    input[11:00] iINBUS,            // device sending data for PIO or DMA
                                    // also memory read data if memdisab set
    input iPAUSE,                   // pause processor clocking (stretch cycle)
    output oBRKGNTO,                // chained break grant
    output oBRKCYC,                 // break cycle
    output oBUSINI,                 // initialize bus devices
    output oBWCOV,                  // 3-cycle DMA wordcount overflowed
    output oCLOCK,                  // 10MHz PDP clock
    output oION,                    // interrupts enabled
    output oIOP,                    // io instruction pulse
    output oLINK,                   // link register
    output oRUN,
    output oTP1, oTP2, oTP3, oTP4, oTS1, oTS2, oTS3, oTS4,
    output[11:00] oMADR, oMBUF, oACUM,

    input memdisab,                 // disable internal memory chip
    output[11:00] mquo, pctr,
    output[2:0] memfield,
    output[3:0] majst,
    output[4:0] sctr,
    output swstart, swldad, swdepos, swexam,
    output swcont, swsstep, swsinst,
    output[2:0] swdf, swif,
    output[11:00] swreg

    ,input[11:00]  saxi_ARADDR
    ,output reg    saxi_ARREADY
    ,input         saxi_ARVALID
    ,input[11:00]  saxi_AWADDR
    ,output reg    saxi_AWREADY
    ,input         saxi_AWVALID
    ,input         saxi_BREADY
    ,output[1:0]   saxi_BRESP
    ,output reg    saxi_BVALID
    ,output[31:00] saxi_RDATA
    ,input         saxi_RREADY
    ,output[1:0]   saxi_RRESP
    ,output reg    saxi_RVALID
    ,input[31:00]  saxi_WDATA
    ,output reg    saxi_WREADY
    ,input         saxi_WVALID
);

    // combined bus signals
    wire _busCLOCK, _busION, _busLINK, _busPAUSE, _busREADSR, _busRESET, _busRUN, _busBRKRQST,
        _busBRKWRM, _busCAINC, _busCYCLE3, _busINTRQST, _busBUSINI, _busACCLEAR,
        _busIOSKIP, _busLNKTOG, _busIOP, _busMEMDIS, _busINTINH, _busBWCOV, _busBRKCYC;
    wire _busSWCONT, _busSWDEPOS, _busSWEXAM, _busSWLDAD, _busSWSINST, _busSWSSTEP, _busSWSTART;
    wire _busTP1, _busTP2, _busTP3, _busTP4, _busTS1, _busTS2, _busTS3, _busTS4;
    wire[2:0] _busDFLD, _busIFLD, _busDMAFLD, _busMEAD;
    wire[3:0] _busMAJST;
    wire[4:0] _busSCTR;
    wire[11:00] _busACUM, _busMADR, _busMBUF, _busMQUO, _busPCTR, _busINBUS;
    wire[11:09] _busIREG;

    wire zynCONSCK, zynCONSDA, conCONSDA;

    // output some bus signals to simulator
    assign oACUM    = ~ _busACUM;
    assign oBRKCYC  = ~ _busBRKCYC;
    assign oBUSINI  = ~ _busBUSINI;
    assign oBWCOV   = ~ _busBWCOV;
    assign oCLOCK   = ~ _busCLOCK;
    assign oION     = ~ _busION;
    assign oIOP     = ~ _busIOP;
    assign oLINK    = ~ _busLINK;
    assign oMADR    = ~ _busMADR;
    assign oMBUF    = ~ _busMBUF;
    assign oRUN     = ~ _busRUN;
    assign oTP1     = ~ _busTP1;
    assign oTP2     = ~ _busTP2;
    assign oTP3     = ~ _busTP3;
    assign oTP4     = ~ _busTP4;
    assign oTS1     = ~ _busTS1;
    assign oTS2     = ~ _busTS2;
    assign oTS3     = ~ _busTS3;
    assign oTS4     = ~ _busTS4;
    assign majst    = ~ _busMAJST;
    assign memfield = ~ _busMEAD;
    assign mquo     = ~ _busMQUO;
    assign pctr     = ~ _busPCTR;
    assign sctr     = ~ _busSCTR;
    assign swcont   = ~ _busSWCONT;
    assign swdepos  = ~ _busSWDEPOS;
    assign swexam   = ~ _busSWEXAM;
    assign swldad   = ~ _busSWLDAD;
    assign swsinst  = ~ _busSWSINST;
    assign swsstep  = ~ _busSWSSTEP;
    assign swstart  = ~ _busSWSTART;

    ///////////////
    //  CONSOLE  //
    ///////////////

    wire[2:0] _conDFLD, _conIFLD;
    wire[11:00] _conINBUS;
    wire lttime, swtime;

    console conboard (
        .zclock (zclock),
        .zreset (zreset),
        .GND    (1'b0),
        .VCC    (1'b1),

        .lttime (lttime),   // light row display time
        .swtime (swtime),   // switch row sense time
        .div_11 (),         // 204.8uS
        .div_5  (lttime),   // 3.2uS
        .div_4  (),         // 1.6uS
        .div_2  (swtime),   // 0.4uS

        .CONSCK   (zynCONSCK),
        .CONSDA   (zynCONSDA),
        .CONSDA_o (conCONSDA),

        .bGPIO_4    (gpin[04] & gpout[04]),
        .bGPIO_5    (gpin[05] & gpout[05]),
        .bGPIO_6    (gpin[06] & gpout[06]),
        .bGPIO_7    (gpin[07] & gpout[07]),
        .bGPIO_8    (gpin[08] & gpout[08]),
        .bGPIO_9    (gpin[09] & gpout[09]),
        .bGPIO_10   (gpin[10] & gpout[10]),
        .bGPIO_11   (gpin[11] & gpout[11]),
        .bGPIO_12   (gpin[12] & gpout[12]),
        .bGPIO_13   (gpin[13] & gpout[13]),
        .bGPIO_14   (gpin[14] & gpout[14]),
        .bGPIO_15   (gpin[15] & gpout[15]),
        .bGPIO_4_o  (gpout[04]),
        .bGPIO_5_o  (gpout[05]),
        .bGPIO_6_o  (gpout[06]),
        .bGPIO_7_o  (gpout[07]),
        .bGPIO_8_o  (gpout[08]),
        .bGPIO_9_o  (gpout[09]),
        .bGPIO_10_o (gpout[10]),
        .bGPIO_11_o (gpout[11]),
        .bGPIO_12_o (gpout[12]),
        .bGPIO_13_o (gpout[13]),
        .bGPIO_14_o (gpout[14]),
        .bGPIO_15_o (gpout[15]),
        .oGPOUT_16  (gpout[16]),
        .oGPOUT_17  (gpout[17]),
        .oGPOUT_18  (gpout[18]),
        .oGPOUT_20  (gpout[20]),
        .oGPOUT_21  (gpout[21]),
        .oGPOUT_22  (gpout[22]),
        .oGPOUT_23  (gpout[23]),
        .oGPOUT_24  (gpout[24]),
        .oGPOUT_25  (gpout[25]),
        .oGPOUT_26  (gpout[26]),
        .oGPOUT_27  (gpout[27]),

        ._ACUM_0   (_busACUM[0]),
        ._ACUM_1   (_busACUM[1]),
        ._ACUM_2   (_busACUM[2]),
        ._ACUM_3   (_busACUM[3]),
        ._ACUM_4   (_busACUM[4]),
        ._ACUM_5   (_busACUM[5]),
        ._ACUM_6   (_busACUM[6]),
        ._ACUM_7   (_busACUM[7]),
        ._ACUM_8   (_busACUM[8]),
        ._ACUM_9   (_busACUM[9]),
        ._ACUM_10  (_busACUM[10]),
        ._ACUM_11  (_busACUM[11]),

        ._CLOCK    (_busCLOCK),
        ._ION      (_busION),

        ._IREG_9   (_busIREG[9]),
        ._IREG_10  (_busIREG[10]),
        ._IREG_11  (_busIREG[11]),

        ._LINK     (_busLINK),

        ._MADR_0   (_busMADR[0]),
        ._MADR_1   (_busMADR[1]),
        ._MADR_2   (_busMADR[2]),
        ._MADR_3   (_busMADR[3]),
        ._MADR_4   (_busMADR[4]),
        ._MADR_5   (_busMADR[5]),
        ._MADR_6   (_busMADR[6]),
        ._MADR_7   (_busMADR[7]),
        ._MADR_8   (_busMADR[8]),
        ._MADR_9   (_busMADR[9]),
        ._MADR_10  (_busMADR[10]),
        ._MADR_11  (_busMADR[11]),

        ._MAJST_0  (_busMAJST[0]),
        ._MAJST_1  (_busMAJST[1]),
        ._MAJST_2  (_busMAJST[2]),
        ._MAJST_3  (_busMAJST[3]),

        ._MBUF_0   (_busMBUF[0]),
        ._MBUF_1   (_busMBUF[1]),
        ._MBUF_2   (_busMBUF[2]),
        ._MBUF_3   (_busMBUF[3]),
        ._MBUF_4   (_busMBUF[4]),
        ._MBUF_5   (_busMBUF[5]),
        ._MBUF_6   (_busMBUF[6]),
        ._MBUF_7   (_busMBUF[7]),
        ._MBUF_8   (_busMBUF[8]),
        ._MBUF_9   (_busMBUF[9]),
        ._MBUF_10  (_busMBUF[10]),
        ._MBUF_11  (_busMBUF[11]),

        ._MQUO_0   (_busMQUO[0]),
        ._MQUO_1   (_busMQUO[1]),
        ._MQUO_2   (_busMQUO[2]),
        ._MQUO_3   (_busMQUO[3]),
        ._MQUO_4   (_busMQUO[4]),
        ._MQUO_5   (_busMQUO[5]),
        ._MQUO_6   (_busMQUO[6]),
        ._MQUO_7   (_busMQUO[7]),
        ._MQUO_8   (_busMQUO[8]),
        ._MQUO_9   (_busMQUO[9]),
        ._MQUO_10  (_busMQUO[10]),
        ._MQUO_11  (_busMQUO[11]),

        ._PAUSE    (_busPAUSE),

        ._PCTR_0   (_busPCTR[0]),
        ._PCTR_1   (_busPCTR[1]),
        ._PCTR_2   (_busPCTR[2]),
        ._PCTR_3   (_busPCTR[3]),
        ._PCTR_4   (_busPCTR[4]),
        ._PCTR_5   (_busPCTR[5]),
        ._PCTR_6   (_busPCTR[6]),
        ._PCTR_7   (_busPCTR[7]),
        ._PCTR_8   (_busPCTR[8]),
        ._PCTR_9   (_busPCTR[9]),
        ._PCTR_10  (_busPCTR[10]),
        ._PCTR_11  (_busPCTR[11]),

        ._READSR   (_busREADSR),
        ._RESET    (_busRESET),
        ._RUN      (_busRUN),

        ._SCTR_0   (_busSCTR[0]),
        ._SCTR_1   (_busSCTR[1]),
        ._SCTR_2   (_busSCTR[2]),
        ._SCTR_3   (_busSCTR[3]),
        ._SCTR_4   (_busSCTR[4]),

        ._DFLD_0   (_busDFLD[0]),
        ._DFLD_1   (_busDFLD[1]),
        ._DFLD_2   (_busDFLD[2]),
        ._IFLD_0   (_busIFLD[0]),
        ._IFLD_1   (_busIFLD[1]),
        ._IFLD_2   (_busIFLD[2]),

        ._DFLD_0_o  (_conDFLD[0]),      // dfld/ifld switches
        ._DFLD_1_o  (_conDFLD[1]),      // ...when LDAD pressed
        ._DFLD_2_o  (_conDFLD[2]),      // ...else hi-Z
        ._IFLD_0_o  (_conIFLD[0]),
        ._IFLD_1_o  (_conIFLD[1]),
        ._IFLD_2_o  (_conIFLD[2]),

        ._INBUS_0   (_busINBUS[0]),
        ._INBUS_1   (_busINBUS[1]),
        ._INBUS_2   (_busINBUS[2]),
        ._INBUS_3   (_busINBUS[3]),
        ._INBUS_4   (_busINBUS[4]),
        ._INBUS_5   (_busINBUS[5]),
        ._INBUS_6   (_busINBUS[6]),
        ._INBUS_7   (_busINBUS[7]),
        ._INBUS_8   (_busINBUS[8]),
        ._INBUS_9   (_busINBUS[9]),
        ._INBUS_10  (_busINBUS[10]),
        ._INBUS_11  (_busINBUS[11]),

        ._INBUS_0_o (_conINBUS[0]),     // SR{11:00] when READSR
        ._INBUS_1_o (_conINBUS[1]),     // ...else hi-Z
        ._INBUS_2_o (_conINBUS[2]),
        ._INBUS_3_o (_conINBUS[3]),
        ._INBUS_4_o (_conINBUS[4]),
        ._INBUS_5_o (_conINBUS[5]),
        ._INBUS_6_o (_conINBUS[6]),
        ._INBUS_7_o (_conINBUS[7]),
        ._INBUS_8_o (_conINBUS[8]),
        ._INBUS_9_o (_conINBUS[9]),
        ._INBUS_10_o(_conINBUS[10]),
        ._INBUS_11_o(_conINBUS[11]),

        ._SWSTART   (_busSWSTART),    //button start (debounced)
        ._SWLDAD    (_busSWLDAD),     //button load address
        ._SWDEPOS   (_busSWDEPOS),    //button deposit (debounced)
        ._SWEXAM    (_busSWEXAM),     //button examine (debounced)
        ._SWCONT    (_busSWCONT),     //button continue (debounced)
        ._SWSSTEP   (_busSWSSTEP),    //toggle single cycle
        ._SWSINST   (_busSWSINST),    //toggle single instruction

        ._SWSTART_o (_busSWSTART),    //button start (debounced)
        ._SWLDAD_o  (_busSWLDAD),     //button load address
        ._SWDEPOS_o (_busSWDEPOS),    //button deposit (debounced)
        ._SWEXAM_o  (_busSWEXAM),     //button examine (debounced)
        ._SWCONT_o  (_busSWCONT),     //button continue (debounced)
        ._SWSSTEP_o (_busSWSSTEP),    //toggle single cycle
        ._SWSINST_o (_busSWSINST),    //toggle single instruction

        .swreg_0  (swreg[00]),
        .swreg_1  (swreg[01]),
        .swreg_2  (swreg[02]),
        .swreg_3  (swreg[03]),
        .swreg_4  (swreg[04]),
        .swreg_5  (swreg[05]),
        .swreg_6  (swreg[06]),
        .swreg_7  (swreg[07]),
        .swreg_8  (swreg[08]),
        .swreg_9  (swreg[09]),
        .swreg_10 (swreg[10]),
        .swreg_11 (swreg[11]),
        .swdfld_0  (swdf[00]),
        .swdfld_1  (swdf[01]),
        .swdfld_2  (swdf[02]),
        .swifld_0  (swif[00]),
        .swifld_1  (swif[01]),
        .swifld_2  (swif[02])
    );

    ///////////////////////////
    //  EXTENDED ARITHMETIC  //
    ///////////////////////////

    wire _eaeACCLEAR, _eaeIOSKIP, _eaePAUSE, _extop_dvi, _extop_muy, _s3clk;
    wire dviover, extarex, majst_000x, sctr_5;
    wire[3:1] _extop;
    wire[4:1] extop;
    wire[11:00] _eaeINBUS, myac, myacstep2;

    extarctrl eaectlbd (
        .zclock (zclock),
        .zreset (zreset),
        .GND    (1'b0),
        .VCC    (1'b1),

        ._BUSINI    (_busBUSINI),
        ._CLOCK     (_busCLOCK),

        ._MAJST_0   (_busMAJST[0]),
        ._MAJST_1   (_busMAJST[1]),
        ._MAJST_2   (_busMAJST[2]),
        ._MAJST_3   (_busMAJST[3]),

        ._MBUF_0    (_busMBUF[0]),
        ._MBUF_1    (_busMBUF[1]),
        ._MBUF_2    (_busMBUF[2]),
        ._MBUF_3    (_busMBUF[3]),
        ._MBUF_4    (_busMBUF[4]),
        ._MBUF_5    (_busMBUF[5]),
        ._MBUF_6    (_busMBUF[6]),
        ._MBUF_7    (_busMBUF[7]),
        ._MBUF_8    (_busMBUF[8]),
        ._MBUF_9    (_busMBUF[9]),
        ._MBUF_10   (_busMBUF[10]),
        ._MBUF_11   (_busMBUF[11]),

        ._TP1       (_busTP1),
        ._TS2       (_busTS2),
        ._TS3       (_busTS3),

        .extop_1    (extop[1]),
        .extop_2    (extop[2]),
        .extop_3    (extop[3]),
        .extop_4    (extop[4]),

        .myac_0     (myac[0]),
        .myac_1     (myac[1]),
        .myac_2     (myac[2]),
        .myac_3     (myac[3]),
        .myac_4     (myac[4]),
        .myac_5     (myac[5]),
        .myac_6     (myac[6]),
        .myac_7     (myac[7]),
        .myac_8     (myac[8]),
        .myac_9     (myac[9]),
        .myac_10    (myac[10]),
        .myac_11    (myac[11]),

        .myacstep2_0  (myacstep2[0]),
        .myacstep2_1  (myacstep2[1]),
        .myacstep2_2  (myacstep2[2]),
        .myacstep2_3  (myacstep2[3]),
        .myacstep2_4  (myacstep2[4]),
        .myacstep2_5  (myacstep2[5]),
        .myacstep2_6  (myacstep2[6]),
        .myacstep2_7  (myacstep2[7]),
        .myacstep2_8  (myacstep2[8]),
        .myacstep2_9  (myacstep2[9]),
        .myacstep2_10 (myacstep2[10]),
        .myacstep2_11 (myacstep2[11]),

        .dviover    (dviover),
        .extarex    (extarex),
        .majst_000x (majst_000x),
        .sctr_5     (sctr_5),

        ._extop_1   (_extop[1]),
        ._extop_2   (_extop[2]),
        ._extop_3   (_extop[3]),

        ._extop_dvi (_extop_dvi),
        ._extop_muy (_extop_muy),
        ._s3clk     (_s3clk),

        ._INBUS_0   (_busINBUS[0]),
        ._INBUS_1   (_busINBUS[1]),
        ._INBUS_2   (_busINBUS[2]),
        ._INBUS_3   (_busINBUS[3]),
        ._INBUS_4   (_busINBUS[4]),
        ._INBUS_5   (_busINBUS[5]),
        ._INBUS_6   (_busINBUS[6]),
        ._INBUS_8   (_busINBUS[8]),
        ._INBUS_9   (_busINBUS[9]),
        ._INBUS_10  (_busINBUS[10]),
        ._INBUS_11  (_busINBUS[11]),

        ._MQUO_0    (_busMQUO[0]),
        ._MQUO_1    (_busMQUO[1]),
        ._MQUO_2    (_busMQUO[2]),
        ._MQUO_3    (_busMQUO[3]),
        ._MQUO_4    (_busMQUO[4]),
        ._MQUO_5    (_busMQUO[5]),
        ._MQUO_6    (_busMQUO[6]),
        ._MQUO_7    (_busMQUO[7]),
        ._MQUO_8    (_busMQUO[8]),
        ._MQUO_9    (_busMQUO[9]),
        ._MQUO_10   (_busMQUO[10]),
        ._MQUO_11   (_busMQUO[11]),

        ._PAUSE     (_busPAUSE),
        ._PAUSE_o   (_eaePAUSE),

        ._SCTR_0    (_busSCTR[0]),
        ._SCTR_1    (_busSCTR[1]),
        ._SCTR_2    (_busSCTR[2]),
        ._SCTR_3    (_busSCTR[3]),
        ._SCTR_4    (_busSCTR[4])
    );

    extardata eaedatbd (
        .zclock (zclock),
        .zreset (zreset),
        .GND    (1'b0),
        .VCC    (1'b1),


        ._ACUM_0    (_busACUM[0]),
        ._ACUM_1    (_busACUM[1]),
        ._ACUM_2    (_busACUM[2]),
        ._ACUM_3    (_busACUM[3]),
        ._ACUM_4    (_busACUM[4]),
        ._ACUM_5    (_busACUM[5]),
        ._ACUM_6    (_busACUM[6]),
        ._ACUM_7    (_busACUM[7]),
        ._ACUM_8    (_busACUM[8]),
        ._ACUM_9    (_busACUM[9]),
        ._ACUM_10   (_busACUM[10]),
        ._ACUM_11   (_busACUM[11]),

        ._BUSINI    (_busBUSINI),
        ._LINK      (_busLINK),

        ._MAJST_0   (_busMAJST[0]),

        ._MBUF_0    (_busMBUF[0]),
        ._MBUF_1    (_busMBUF[1]),
        ._MBUF_2    (_busMBUF[2]),
        ._MBUF_3    (_busMBUF[3]),
        ._MBUF_4    (_busMBUF[4]),
        ._MBUF_5    (_busMBUF[5]),
        ._MBUF_6    (_busMBUF[6]),
        ._MBUF_7    (_busMBUF[7]),
        ._MBUF_8    (_busMBUF[8]),
        ._MBUF_9    (_busMBUF[9]),
        ._MBUF_10   (_busMBUF[10]),
        ._MBUF_11   (_busMBUF[11]),

        ._TP1       (_busTP1),
        ._TP2       (_busTP2),
        ._TS1       (_busTS1),
        ._TS2       (_busTS2),
        ._TS3       (_busTS3),

        .extop_1    (extop[1]),
        .extop_2    (extop[2]),
        .extop_3    (extop[3]),
        .extop_4    (extop[4]),

        .myac_0     (myac[0]),
        .myac_1     (myac[1]),
        .myac_2     (myac[2]),
        .myac_3     (myac[3]),
        .myac_4     (myac[4]),
        .myac_5     (myac[5]),
        .myac_6     (myac[6]),
        .myac_7     (myac[7]),
        .myac_8     (myac[8]),
        .myac_9     (myac[9]),
        .myac_10    (myac[10]),
        .myac_11    (myac[11]),

        .myacstep2_0  (myacstep2[0]),
        .myacstep2_1  (myacstep2[1]),
        .myacstep2_2  (myacstep2[2]),
        .myacstep2_3  (myacstep2[3]),
        .myacstep2_4  (myacstep2[4]),
        .myacstep2_5  (myacstep2[5]),
        .myacstep2_6  (myacstep2[6]),
        .myacstep2_7  (myacstep2[7]),
        .myacstep2_8  (myacstep2[8]),
        .myacstep2_9  (myacstep2[9]),
        .myacstep2_10 (myacstep2[10]),
        .myacstep2_11 (myacstep2[11]),

        .dviover    (dviover),
        .extarex    (extarex),
        .majst_000x (majst_000x),
        .sctr_5     (sctr_5),

        ._extop_1   (_extop[1]),
        ._extop_2   (_extop[2]),
        ._extop_3   (_extop[3]),

        ._extop_dvi (_extop_dvi),
        ._extop_muy (_extop_muy),
        ._s3clk     (_s3clk),

        ._ACCLEAR   (_busACCLEAR),
        ._ACCLEAR_o (_eaeACCLEAR),

        ._INBUS_0   (_busINBUS[0]),
        ._INBUS_1   (_busINBUS[1]),
        ._INBUS_2   (_busINBUS[2]),
        ._INBUS_3   (_busINBUS[3]),
        ._INBUS_4   (_busINBUS[4]),
        ._INBUS_5   (_busINBUS[5]),
        ._INBUS_6   (_busINBUS[6]),
        ._INBUS_7   (_busINBUS[7]),
        ._INBUS_8   (_busINBUS[8]),
        ._INBUS_9   (_busINBUS[9]),
        ._INBUS_10  (_busINBUS[10]),
        ._INBUS_11  (_busINBUS[11]),

        ._INBUS_0_o (_eaeINBUS[0]),
        ._INBUS_1_o (_eaeINBUS[1]),
        ._INBUS_2_o (_eaeINBUS[2]),
        ._INBUS_3_o (_eaeINBUS[3]),
        ._INBUS_4_o (_eaeINBUS[4]),
        ._INBUS_5_o (_eaeINBUS[5]),
        ._INBUS_6_o (_eaeINBUS[6]),
        ._INBUS_7_o (_eaeINBUS[7]),
        ._INBUS_8_o (_eaeINBUS[8]),
        ._INBUS_9_o (_eaeINBUS[9]),
        ._INBUS_10_o(_eaeINBUS[10]),
        ._INBUS_11_o(_eaeINBUS[11]),

        ._IOSKIP    (_busIOSKIP),
        ._LNKTOG    (_busLNKTOG),
        ._IOSKIP_o  (_eaeIOSKIP),
        ._LNKTOG_o  (_busLNKTOG),

        ._MQUO_0    (_busMQUO[0]),
        ._MQUO_1    (_busMQUO[1]),
        ._MQUO_2    (_busMQUO[2]),
        ._MQUO_3    (_busMQUO[3]),
        ._MQUO_4    (_busMQUO[4]),
        ._MQUO_5    (_busMQUO[5]),
        ._MQUO_6    (_busMQUO[6]),
        ._MQUO_7    (_busMQUO[7]),
        ._MQUO_8    (_busMQUO[8]),
        ._MQUO_9    (_busMQUO[9]),
        ._MQUO_10   (_busMQUO[10]),
        ._MQUO_11   (_busMQUO[11]),

        ._MQUO_0_o  (_busMQUO[0]),
        ._MQUO_1_o  (_busMQUO[1]),
        ._MQUO_2_o  (_busMQUO[2]),
        ._MQUO_3_o  (_busMQUO[3]),
        ._MQUO_4_o  (_busMQUO[4]),
        ._MQUO_5_o  (_busMQUO[5]),
        ._MQUO_6_o  (_busMQUO[6]),
        ._MQUO_7_o  (_busMQUO[7]),
        ._MQUO_8_o  (_busMQUO[8]),
        ._MQUO_9_o  (_busMQUO[9]),
        ._MQUO_10_o (_busMQUO[10]),
        ._MQUO_11_o (_busMQUO[11]),

        ._SCTR_0    (_busSCTR[0]),
        ._SCTR_1    (_busSCTR[1]),
        ._SCTR_2    (_busSCTR[2]),
        ._SCTR_3    (_busSCTR[3]),
        ._SCTR_4    (_busSCTR[4]),

        ._SCTR_0_o  (_busSCTR[0]),
        ._SCTR_1_o  (_busSCTR[1]),
        ._SCTR_2_o  (_busSCTR[2]),
        ._SCTR_3_o  (_busSCTR[3]),
        ._SCTR_4_o  (_busSCTR[4])
    );

    ///////////////////////
    //  EXTENDED MEMORY  //
    ///////////////////////

    wire[11:00] _memINBUS;
    wire[2:0] _memDFLD, _memIFLD;

    extmemory meminst (
        .zclock (zclock),
        .zreset (zreset),
        .GND    (1'b0),
        .VCC    (1'b1),


        ._BUSINI   (_busBUSINI),
        ._CLOCK    (_busCLOCK),

        ._DMAFLD_0 (_busDMAFLD[0]),
        ._DMAFLD_1 (_busDMAFLD[1]),
        ._DMAFLD_2 (_busDMAFLD[2]),

        ._IOP      (_busIOP),

        ._IREG_9   (_busIREG[9]),
        ._IREG_10  (_busIREG[10]),
        ._IREG_11  (_busIREG[11]),

        ._MADR_0    (_busMADR[0]),
        ._MADR_1    (_busMADR[1]),
        ._MADR_2    (_busMADR[2]),
        ._MADR_3    (_busMADR[3]),
        ._MADR_4    (_busMADR[4]),
        ._MADR_5    (_busMADR[5]),
        ._MADR_6    (_busMADR[6]),
        ._MADR_7    (_busMADR[7]),
        ._MADR_8    (_busMADR[8]),
        ._MADR_9    (_busMADR[9]),
        ._MADR_10   (_busMADR[10]),
        ._MADR_11   (_busMADR[11]),

        ._MAJST_0   (_busMAJST[0]),
        ._MAJST_1   (_busMAJST[1]),
        ._MAJST_2   (_busMAJST[2]),
        ._MAJST_3   (_busMAJST[3]),

        ._MBUF_0    (_busMBUF[0]),
        ._MBUF_1    (_busMBUF[1]),
        ._MBUF_2    (_busMBUF[2]),
        ._MBUF_3    (_busMBUF[3]),
        ._MBUF_4    (_busMBUF[4]),
        ._MBUF_5    (_busMBUF[5]),
        ._MBUF_6    (_busMBUF[6]),
        ._MBUF_7    (_busMBUF[7]),
        ._MBUF_8    (_busMBUF[8]),
        ._MBUF_9    (_busMBUF[9]),
        ._MBUF_10   (_busMBUF[10]),
        ._MBUF_11   (_busMBUF[11]),

        ._MEMDIS    (_busMEMDIS),
        ._RESET     (_busRESET),
        ._SWLDAD    (_busSWLDAD),

        ._TP1       (_busTP1),
        ._TP2       (_busTP2),
        ._TP3       (_busTP3),
        ._TP4       (_busTP4),
        ._TS1       (_busTS1),
        ._TS3       (_busTS3),
        ._TS4       (_busTS4),

        ._DFLD_0    (_busDFLD[0]),
        ._DFLD_1    (_busDFLD[1]),
        ._DFLD_2    (_busDFLD[2]),
        ._IFLD_0    (_busIFLD[0]),
        ._IFLD_1    (_busIFLD[1]),
        ._IFLD_2    (_busIFLD[2]),

        ._DFLD_0_o  (_memDFLD[0]),      // dfld/ifld registers
        ._DFLD_1_o  (_memDFLD[1]),      // ...when LDAD released
        ._DFLD_2_o  (_memDFLD[2]),      // ...else hi-Z
        ._IFLD_0_o  (_memIFLD[0]),
        ._IFLD_1_o  (_memIFLD[1]),
        ._IFLD_2_o  (_memIFLD[2]),

        ._MEAD_0    (_busMEAD[0]),      // field currently in use
        ._MEAD_1    (_busMEAD[1]),
        ._MEAD_2    (_busMEAD[2]),
        ._MEAD_0_o  (_busMEAD[0]),
        ._MEAD_1_o  (_busMEAD[1]),
        ._MEAD_2_o  (_busMEAD[2]),

        ._INBUS_0   (_busINBUS[0]),
        ._INBUS_1   (_busINBUS[1]),
        ._INBUS_2   (_busINBUS[2]),
        ._INBUS_3   (_busINBUS[3]),
        ._INBUS_4   (_busINBUS[4]),
        ._INBUS_5   (_busINBUS[5]),
        ._INBUS_6   (_busINBUS[6]),
        ._INBUS_7   (_busINBUS[7]),
        ._INBUS_8   (_busINBUS[8]),
        ._INBUS_9   (_busINBUS[9]),
        ._INBUS_10  (_busINBUS[10]),
        ._INBUS_11  (_busINBUS[11]),

        ._INBUS_0_o (_memINBUS[0]),     // SR{11:00] when READSR
        ._INBUS_1_o (_memINBUS[1]),     // ...else hi-Z
        ._INBUS_2_o (_memINBUS[2]),
        ._INBUS_3_o (_memINBUS[3]),
        ._INBUS_4_o (_memINBUS[4]),
        ._INBUS_5_o (_memINBUS[5]),
        ._INBUS_6_o (_memINBUS[6]),
        ._INBUS_7_o (_memINBUS[7]),
        ._INBUS_8_o (_memINBUS[8]),
        ._INBUS_9_o (_memINBUS[9]),
        ._INBUS_10_o(_memINBUS[10]),
        ._INBUS_11_o(_memINBUS[11]),

        ._INTINH    (_busINTINH),
        ._INTINH_o  (_busINTINH)
    );

    /////////////////
    //  PROCESSOR  //
    /////////////////

    wire _cpuBRKGNTO;

    wire[11:00] aluq;
    wire cout, memacsw, nxtms_0, nxtms_1, nxtms_2, nxtms_3;

    procalu aluboard (
        .zclock (zclock),
        .zreset (zreset),
        .GND    (1'b0),
        .VCC    (1'b1),

        .nxtms_0 (nxtms_0),
        .nxtms_1 (nxtms_1),
        .nxtms_2 (nxtms_2),
        .nxtms_3 (nxtms_3),
//      .memacsw (memacsw),

        ._ACCLEAR   (_busACCLEAR),
        ._BRKWRM    (_busBRKWRM),
        ._CAINC     (_busCAINC),
        ._CYCLE3    (_busCYCLE3),

        ._INBUS_0   (_busINBUS[0]),
        ._INBUS_1   (_busINBUS[1]),
        ._INBUS_2   (_busINBUS[2]),
        ._INBUS_3   (_busINBUS[3]),
        ._INBUS_4   (_busINBUS[4]),
        ._INBUS_5   (_busINBUS[5]),
        ._INBUS_6   (_busINBUS[6]),
        ._INBUS_7   (_busINBUS[7]),
        ._INBUS_8   (_busINBUS[8]),
        ._INBUS_9   (_busINBUS[9]),
        ._INBUS_10  (_busINBUS[10]),
        ._INBUS_11  (_busINBUS[11]),

//      ._IOSKIP    (_busIOSKIP),
//      ._LNKTOG    (_busLNKTOG),
//      ._RESET     (_busRESET),
        ._SWCONT    (_busSWCONT),
        ._SWDEPOS   (_busSWDEPOS),
        ._SWEXAM    (_busSWEXAM),
        ._SWLDAD    (_busSWLDAD),
        ._SWSTART   (_busSWSTART),

        ._ACUM_0    (_busACUM[0]),
        ._ACUM_1    (_busACUM[1]),
        ._ACUM_2    (_busACUM[2]),
        ._ACUM_3    (_busACUM[3]),
        ._ACUM_4    (_busACUM[4]),
        ._ACUM_5    (_busACUM[5]),
        ._ACUM_6    (_busACUM[6]),
        ._ACUM_7    (_busACUM[7]),
        ._ACUM_8    (_busACUM[8]),
        ._ACUM_9    (_busACUM[9]),
        ._ACUM_10   (_busACUM[10]),
        ._ACUM_11   (_busACUM[11]),

//      ._BRKCYC    (_busBRKCYC),
//      ._BUSINI    (_busBUSINI),
//      ._BWCOV     (_busBWCOV),
//      ._CLOCK     (_busCLOCK),
//      ._ION       (_busION),
        ._IOP       (_busIOP),

        ._IREG_9    (_busIREG[9]),
        ._IREG_10   (_busIREG[10]),
        ._IREG_11   (_busIREG[11]),

        ._LINK      (_busLINK),

        ._MADR_0    (_busMADR[0]),
        ._MADR_1    (_busMADR[1]),
        ._MADR_2    (_busMADR[2]),
        ._MADR_3    (_busMADR[3]),
        ._MADR_4    (_busMADR[4]),
        ._MADR_5    (_busMADR[5]),
        ._MADR_6    (_busMADR[6]),
        ._MADR_7    (_busMADR[7]),
        ._MADR_8    (_busMADR[8]),
        ._MADR_9    (_busMADR[9]),
        ._MADR_10   (_busMADR[10]),
        ._MADR_11   (_busMADR[11]),

        ._MAJST_0   (_busMAJST[0]),
        ._MAJST_1   (_busMAJST[1]),
        ._MAJST_2   (_busMAJST[2]),
        ._MAJST_3   (_busMAJST[3]),

        ._MBUF_0    (_busMBUF[0]),
        ._MBUF_1    (_busMBUF[1]),
        ._MBUF_2    (_busMBUF[2]),
        ._MBUF_3    (_busMBUF[3]),
        ._MBUF_4    (_busMBUF[4]),
        ._MBUF_5    (_busMBUF[5]),
        ._MBUF_6    (_busMBUF[6]),
        ._MBUF_7    (_busMBUF[7]),
        ._MBUF_8    (_busMBUF[8]),
        ._MBUF_9    (_busMBUF[9]),
        ._MBUF_10   (_busMBUF[10]),
        ._MBUF_11   (_busMBUF[11]),

        ._PCTR_0    (_busPCTR[0]),
        ._PCTR_1    (_busPCTR[1]),
        ._PCTR_2    (_busPCTR[2]),
        ._PCTR_3    (_busPCTR[3]),
        ._PCTR_4    (_busPCTR[4]),
        ._PCTR_5    (_busPCTR[5]),
        ._PCTR_6    (_busPCTR[6]),
        ._PCTR_7    (_busPCTR[7]),
        ._PCTR_8    (_busPCTR[8]),
        ._PCTR_9    (_busPCTR[9]),
        ._PCTR_10   (_busPCTR[10]),
        ._PCTR_11   (_busPCTR[11]),

        ._READSR    (_busREADSR),
//      ._RUN       (_busRUN),

//      ._TP1       (_busTP1),
//      ._TP2       (_busTP2),
//      ._TP3       (_busTP3),
//      ._TP4       (_busTP4),
        ._TS1       (_busTS1),
        ._TS2       (_busTS2),
        ._TS3       (_busTS3),
        ._TS4       (_busTS4),

        .aluq_0    (aluq[0]),
        .aluq_1    (aluq[1]),
        .aluq_2    (aluq[2]),
        .aluq_3    (aluq[3]),
        .aluq_4    (aluq[4]),
        .aluq_5    (aluq[5]),
        .aluq_6    (aluq[6]),
        .aluq_7    (aluq[7]),
        .aluq_8    (aluq[8]),
        .aluq_9    (aluq[9]),
        .aluq_10   (aluq[10]),
        .aluq_11   (aluq[11]),
        .cout      (cout),

//      ._BRKCYC_o  (_busBRKCYC),
//      ._BWCOV_o   (_busBWCOV),

        ._READSR_o  (_busREADSR)
    );

    procreg regboard (
        .zclock (zclock),
        .zreset (zreset),
        .GND    (1'b0),
        .VCC    (1'b1),

        .aluq_0    (aluq[0]),
        .aluq_1    (aluq[1]),
        .aluq_2    (aluq[2]),
        .aluq_3    (aluq[3]),
        .aluq_4    (aluq[4]),
        .aluq_5    (aluq[5]),
        .aluq_6    (aluq[6]),
        .aluq_7    (aluq[7]),
        .aluq_8    (aluq[8]),
        .aluq_9    (aluq[9]),
        .aluq_10   (aluq[10]),
        .aluq_11   (aluq[11]),
        .cout      (cout),

        .memacsw (memacsw),
//      .nxtms_0 (nxtms_0),
//      .nxtms_1 (nxtms_1),
//      .nxtms_2 (nxtms_2),
//      .nxtms_3 (nxtms_3),

        ._BRKWRM    (_busBRKWRM),
        ._CAINC     (_busCAINC),
//      ._CYCLE3    (_busCYCLE3),

        ._INBUS_9   (_busINBUS[9]),
        ._INBUS_10  (_busINBUS[10]),
        ._INBUS_11  (_busINBUS[11]),

        ._IOSKIP    (_busIOSKIP),
        ._LNKTOG    (_busLNKTOG),
//      ._RESET     (_busRESET),
        ._SWCONT    (_busSWCONT),
        ._SWDEPOS   (_busSWDEPOS),
        ._SWEXAM    (_busSWEXAM),
        ._SWLDAD    (_busSWLDAD),
//      ._SWSTART   (_busSWSTART),

        ._ACUM_0    (_busACUM[0]),
        ._ACUM_1    (_busACUM[1]),
        ._ACUM_2    (_busACUM[2]),
        ._ACUM_3    (_busACUM[3]),
        ._ACUM_4    (_busACUM[4]),
        ._ACUM_5    (_busACUM[5]),
        ._ACUM_6    (_busACUM[6]),
        ._ACUM_7    (_busACUM[7]),
        ._ACUM_8    (_busACUM[8]),
        ._ACUM_9    (_busACUM[9]),
        ._ACUM_10   (_busACUM[10]),
        ._ACUM_11   (_busACUM[11]),

        ._BRKCYC    (_busBRKCYC),
        ._BUSINI    (_busBUSINI),
        ._BWCOV     (_busBWCOV),
//      ._CLOCK     (_busCLOCK),
//      ._ION       (_busION),
        ._IOP       (_busIOP),

        ._IREG_9    (_busIREG[9]),
        ._IREG_10   (_busIREG[10]),
        ._IREG_11   (_busIREG[11]),

        ._LINK      (_busLINK),

        ._MADR_0    (_busMADR[0]),
        ._MADR_1    (_busMADR[1]),
        ._MADR_2    (_busMADR[2]),
        ._MADR_3    (_busMADR[3]),
        ._MADR_4    (_busMADR[4]),
        ._MADR_5    (_busMADR[5]),
        ._MADR_6    (_busMADR[6]),
        ._MADR_7    (_busMADR[7]),
        ._MADR_8    (_busMADR[8]),
        ._MADR_9    (_busMADR[9]),
        ._MADR_10   (_busMADR[10]),
        ._MADR_11   (_busMADR[11]),

        ._MAJST_0   (_busMAJST[0]),
        ._MAJST_1   (_busMAJST[1]),
        ._MAJST_2   (_busMAJST[2]),
        ._MAJST_3   (_busMAJST[3]),

        ._MBUF_0    (_busMBUF[0]),
        ._MBUF_1    (_busMBUF[1]),
        ._MBUF_2    (_busMBUF[2]),
        ._MBUF_3    (_busMBUF[3]),
        ._MBUF_4    (_busMBUF[4]),
        ._MBUF_5    (_busMBUF[5]),
        ._MBUF_6    (_busMBUF[6]),
        ._MBUF_7    (_busMBUF[7]),
        ._MBUF_8    (_busMBUF[8]),
        ._MBUF_9    (_busMBUF[9]),
        ._MBUF_10   (_busMBUF[10]),
        ._MBUF_11   (_busMBUF[11]),

        ._PCTR_0    (_busPCTR[0]),
        ._PCTR_1    (_busPCTR[1]),
        ._PCTR_2    (_busPCTR[2]),
        ._PCTR_3    (_busPCTR[3]),
        ._PCTR_4    (_busPCTR[4]),
        ._PCTR_5    (_busPCTR[5]),
        ._PCTR_6    (_busPCTR[6]),
        ._PCTR_7    (_busPCTR[7]),
        ._PCTR_8    (_busPCTR[8]),
        ._PCTR_9    (_busPCTR[9]),
        ._PCTR_10   (_busPCTR[10]),
        ._PCTR_11   (_busPCTR[11]),

//      ._READSR    (_busREADSR),
        ._RUN       (_busRUN),

        ._TP1       (_busTP1),
        ._TP2       (_busTP2),
        ._TP3       (_busTP3),
        ._TP4       (_busTP4),
        ._TS1       (_busTS1),
        ._TS2       (_busTS2),
        ._TS3       (_busTS3),
        ._TS4       (_busTS4),

        ._ACUM_0_o  (_busACUM[0]),
        ._ACUM_1_o  (_busACUM[1]),
        ._ACUM_2_o  (_busACUM[2]),
        ._ACUM_3_o  (_busACUM[3]),
        ._ACUM_4_o  (_busACUM[4]),
        ._ACUM_5_o  (_busACUM[5]),
        ._ACUM_6_o  (_busACUM[6]),
        ._ACUM_7_o  (_busACUM[7]),
        ._ACUM_8_o  (_busACUM[8]),
        ._ACUM_9_o  (_busACUM[9]),
        ._ACUM_10_o (_busACUM[10]),
        ._ACUM_11_o (_busACUM[11]),

        ._BRKCYC_o  (_busBRKCYC),
        ._BWCOV_o   (_busBWCOV),

        ._IREG_9_o  (_busIREG[9]),
        ._IREG_10_o (_busIREG[10]),
        ._IREG_11_o (_busIREG[11]),

        ._LINK_o    (_busLINK),

        ._MADR_0_o  (_busMADR[0]),
        ._MADR_1_o  (_busMADR[1]),
        ._MADR_2_o  (_busMADR[2]),
        ._MADR_3_o  (_busMADR[3]),
        ._MADR_4_o  (_busMADR[4]),
        ._MADR_5_o  (_busMADR[5]),
        ._MADR_6_o  (_busMADR[6]),
        ._MADR_7_o  (_busMADR[7]),
        ._MADR_8_o  (_busMADR[8]),
        ._MADR_9_o  (_busMADR[9]),
        ._MADR_10_o (_busMADR[10]),
        ._MADR_11_o (_busMADR[11]),

        ._MBUF_0_o  (_busMBUF[0]),
        ._MBUF_1_o  (_busMBUF[1]),
        ._MBUF_2_o  (_busMBUF[2]),
        ._MBUF_3_o  (_busMBUF[3]),
        ._MBUF_4_o  (_busMBUF[4]),
        ._MBUF_5_o  (_busMBUF[5]),
        ._MBUF_6_o  (_busMBUF[6]),
        ._MBUF_7_o  (_busMBUF[7]),
        ._MBUF_8_o  (_busMBUF[8]),
        ._MBUF_9_o  (_busMBUF[9]),
        ._MBUF_10_o (_busMBUF[10]),
        ._MBUF_11_o (_busMBUF[11]),

        ._PCTR_0_o  (_busPCTR[0]),
        ._PCTR_1_o  (_busPCTR[1]),
        ._PCTR_2_o  (_busPCTR[2]),
        ._PCTR_3_o  (_busPCTR[3]),
        ._PCTR_4_o  (_busPCTR[4]),
        ._PCTR_5_o  (_busPCTR[5]),
        ._PCTR_6_o  (_busPCTR[6]),
        ._PCTR_7_o  (_busPCTR[7]),
        ._PCTR_8_o  (_busPCTR[8]),
        ._PCTR_9_o  (_busPCTR[9]),
        ._PCTR_10_o (_busPCTR[10]),
        ._PCTR_11_o (_busPCTR[11])

//      ._READSR_o  (_busREADSR)
    );

    procseq seqboard (
        .zclock (zclock),
        .zreset (zreset),
        .GND    (1'b0),
        .VCC    (1'b1),

        .nxtms_0 (nxtms_0),
        .nxtms_1 (nxtms_1),
        .nxtms_2 (nxtms_2),
        .nxtms_3 (nxtms_3),
        .memacsw (memacsw),

        ._BRKGNTO   (_cpuBRKGNTO),
        ._BRKGNTO_o (_cpuBRKGNTO),

        ._BRKRQST   (_busBRKRQST),
        ._CYCLE3    (_busCYCLE3),

        ._INTINH    (_busINTINH),
        ._INTRQST   (_busINTRQST),
        ._PAUSE     (_busPAUSE),
        ._RESET     (_busRESET),
        ._SWCONT    (_busSWCONT),
        ._SWDEPOS   (_busSWDEPOS),
        ._SWEXAM    (_busSWEXAM),
        ._SWLDAD    (_busSWLDAD),
        ._SWSINST   (_busSWSINST),
        ._SWSSTEP   (_busSWSSTEP),
        ._SWSTART   (_busSWSTART),

        ._BUSINI    (_busBUSINI),
        ._CLOCK     (_busCLOCK),
        ._ION       (_busION),
        ._IOP       (_busIOP),

        ._IREG_9    (_busIREG[9]),
        ._IREG_10   (_busIREG[10]),
        ._IREG_11   (_busIREG[11]),

        ._MAJST_0   (_busMAJST[0]),
        ._MAJST_1   (_busMAJST[1]),
        ._MAJST_2   (_busMAJST[2]),
        ._MAJST_3   (_busMAJST[3]),

        ._MBUF_0    (_busMBUF[0]),
        ._MBUF_1    (_busMBUF[1]),
        ._MBUF_2    (_busMBUF[2]),
        ._MBUF_3    (_busMBUF[3]),
        ._MBUF_4    (_busMBUF[4]),
        ._MBUF_5    (_busMBUF[5]),
        ._MBUF_6    (_busMBUF[6]),
        ._MBUF_7    (_busMBUF[7]),
        ._MBUF_8    (_busMBUF[8]),

        ._RUN       (_busRUN),

        ._TP1       (_busTP1),
        ._TP2       (_busTP2),
        ._TP3       (_busTP3),
        ._TP4       (_busTP4),
        ._TS1       (_busTS1),
        ._TS2       (_busTS2),
        ._TS3       (_busTS3),
        ._TS4       (_busTS4),

        ._BUSINI_o  (_busBUSINI),
        ._ION_o     (_busION),
        ._IOP_o     (_busIOP),

        ._MAJST_0_o (_busMAJST[0]),
        ._MAJST_1_o (_busMAJST[1]),
        ._MAJST_2_o (_busMAJST[2]),
        ._MAJST_3_o (_busMAJST[3]),

        ._RUN_o     (_busRUN),

        ._TP1_o     (_busTP1),
        ._TP2_o     (_busTP2),
        ._TP3_o     (_busTP3),
        ._TP4_o     (_busTP4),
        ._TS1_o     (_busTS1),
        ._TS2_o     (_busTS2),
        ._TS3_o     (_busTS3),
        ._TS4_o     (_busTS4)
    );

    //////////////////////////////////
    //  Zynq board has I/O devices  //
    //////////////////////////////////

    wire zynACCLEAR, zynBRKGNTI, zynBRKGNTO, zynBRKRQST, zynBRKWRM, zynCAINC;
    wire zynCLOCK, zynCYCLE3, zynINTRQST, zynIOSKIP, zynPAUSE, zynRESET;
    wire _zyndmagntd, _zynioenabd, _zynpoweron;
    wire[2:0] zynDMAFLD;
    wire[11:00] zynINBUS;

    Zynq #(.BIDIRCONSDA (0)) zynqinst (
        .CLOCK   (yclock),
        .RESET_N (~ zreset),
        .LEDoutR (),      // IO_B34_LN6 R14
        .LEDoutG (),      // IO_B34_LP7 Y16
        .LEDoutB (),      // IO_B34_LN7 Y17

        // io bus connections
        .hdw_oACUM    (~ _busACUM),
        .hdw_oBRKCYC  (~ _busBRKCYC),
        .hdw_oBRKGNTI (   zynBRKGNTI),
        .hdw_oBRKRQST (~ _busBRKRQST),
        .hdw_oBUSINI  (~ _busBUSINI),
        .hdw_oBWCOV   (~ _busBWCOV),
        .hdw_oIOP     (~ _busIOP),
        .hdw_oLINK    (~ _busLINK),
        .hdw_oMADR    (~ _busMADR),
        .hdw_oMBUF    (~ _busMBUF),
        .hdw_oMEAD    (~ _busMEAD),
        .hdw_oMAJST   (~ _busMAJST),
        .hdw_oRUN     (~ _busRUN),
        .hdw_oTP1     (~ _busTP1),
        .hdw_oTP2     (~ _busTP2),
        .hdw_oTP3     (~ _busTP3),
        .hdw_oTP4     (~ _busTP4),
        .hdw_oTS1     (~ _busTS1),
        .hdw_oTS2     (~ _busTS2),
        .hdw_oTS3     (~ _busTS3),
        .hdw_oTS4     (~ _busTS4),

        .hdw_iACCLEAR (zynACCLEAR),
        .hdw_iBRKGNTO (zynBRKGNTO),
        .hdw_iBRKRQST (zynBRKRQST),
        .hdw_iBRKWRM  (zynBRKWRM),
        .hdw_iCAINC   (zynCAINC),
        .hdw_iCLOCK   (zynCLOCK),       // zynq.v generates 10MHz clock
        .hdw_iCYCLE3  (zynCYCLE3),
        .hdw_iDMAFLD  (zynDMAFLD),
        .hdw_iINBUS   (zynINBUS),
        .hdw_iINTRQST (zynINTRQST),
        .hdw_iIOSKIP  (zynIOSKIP),
        .hdw_iPAUSE   (zynPAUSE),
        .hdw_iRESET   (zynRESET),       // zreset + arm regctle<fpgareset>

        // output driver enables
        .hdw_dmagntd_n (_zyndmagntd),
        .hdw_ioenabd_n (_zynioenabd),
        .hdw_poweron_n (_zynpoweron),

        // i2c interface to hardware front panel
        .hdw_iCONSCK  (zynCONSCK),
        .hdw_bCONSDA  (),
        .hdw_iCONSDA  (zynCONSDA),
        .hdw_oCONSDA  (conCONSDA),

        // spares
        .spare1 (1'b0),
        .spare2 (1'b0),
        .spare3 (1'b0),
        .spare4 (1'b0),

        // arm processor memory bus interface (AXI)
        // we are a slave for accessing the control registers (read and write)
        .saxi_ARADDR  (saxi_ARADDR),
        .saxi_ARREADY (saxi_ARREADY),
        .saxi_ARVALID (saxi_ARVALID),
        .saxi_AWADDR  (saxi_AWADDR),
        .saxi_AWREADY (saxi_AWREADY),
        .saxi_AWVALID (saxi_AWVALID),
        .saxi_BREADY  (saxi_BREADY),
        .saxi_BRESP   (saxi_BRESP),
        .saxi_BVALID  (saxi_BVALID),
        .saxi_RDATA   (saxi_RDATA),
        .saxi_RREADY  (saxi_RREADY),
        .saxi_RRESP   (saxi_RRESP),
        .saxi_RVALID  (saxi_RVALID),
        .saxi_WDATA   (saxi_WDATA),
        .saxi_WREADY  (saxi_WREADY),
        .saxi_WVALID  (saxi_WVALID)
    );

/***
    ////////////////
    //  TELETYPE  //
    ////////////////

    ,input armwrite
    ,input[31:00] armwdata
    ,input[11:02] armwaddr
    ,input[11:02] armraddr
    ,output[31:00] armrdata

    wire[31:00] ttyrdata;
    wire[11:00] ttyinbus;
    wire ttyacclr, ttyintrq, ttyioskp, ttywrite;

    pdp8itty ttyinst (
        .CLOCK (zclock),
        .RESET (zreset),

        .armwrite (ttywrite),
        .armraddr (armraddr[03:02]),
        .armwaddr (armwaddr[03:02]),
        .armwdata (armwdata),
        .armrdata (ttyrdata),

        .BINIT    (~ _busBUSINI),
        .iopulse  (~ _busIOP),
        .ioopcode (~ _busMBUF),
        .cputodev (~ _busACUM),
        .devtocpu (ttyinbus),
        .AC_CLEAR (ttyacclr),
        .IO_SKIP  (ttyioskp),
        .INT_RQST (ttyintrq)
    );

    wire _dmaBRKGNTI, _dmaBRKGNTO, _dmaBRKRQST, _dmaBRKWRM, _dmaCAINC, _dmaCYCLE3;
    wire dmawrite;
    wire[2:0] _dmaDMAFLD;
    wire[11:00] _dmaINBUS;
    wire[31:00] dmardata;

    dmatest testa (
        .seed   (1),
        .zclock (zclock),
        .zreset (zreset),

        .armwrite (dmawrite),
        .armraddr (armraddr[03:02]), 
        .armwaddr (armwaddr[03:02]),
        .armwdata (armwdata),
        .armrdata (dmardata),

        ._BRKGNTI    (_dmaBRKGNTI),
        ._BRKCYC     (_busBRKCYC),
        ._BUSINI     (_busBUSINI),
        ._BWCOV      (_busBWCOV),
        ._CLOCK      (_busCLOCK),
        ._MBUF_0     (_busMBUF[00]),
        ._MBUF_1     (_busMBUF[01]),
        ._MBUF_2     (_busMBUF[02]),
        ._MBUF_3     (_busMBUF[03]),
        ._MBUF_4     (_busMBUF[04]),
        ._MBUF_5     (_busMBUF[05]),
        ._MBUF_6     (_busMBUF[06]),
        ._MBUF_7     (_busMBUF[07]),
        ._MBUF_8     (_busMBUF[08]),
        ._MBUF_9     (_busMBUF[09]),
        ._MBUF_10    (_busMBUF[10]),
        ._MBUF_11    (_busMBUF[11]),
        ._RESET      (_busRESET),
        ._TP2        (_busTP2),
        ._TP3        (_busTP3),
        ._TS2        (_busTS2),
        ._TS3        (_busTS3),
        ._TS4        (_busTS4),
        ._BRKRQST    (_busBRKRQST),
        ._BRKWRM     (_busBRKWRM),
        ._CAINC      (_busCAINC),
        ._CYCLE3     (_busCYCLE3),
        ._DMAFLD_0   (_busDMAFLD[0]),
        ._DMAFLD_1   (_busDMAFLD[1]),
        ._DMAFLD_2   (_busDMAFLD[2]),
        ._INBUS_0    (_busINBUS[00]),
        ._INBUS_1    (_busINBUS[01]),
        ._INBUS_2    (_busINBUS[02]),
        ._INBUS_3    (_busINBUS[03]),
        ._INBUS_4    (_busINBUS[04]),
        ._INBUS_5    (_busINBUS[05]),
        ._INBUS_6    (_busINBUS[06]),
        ._INBUS_7    (_busINBUS[07]),
        ._INBUS_8    (_busINBUS[08]),
        ._INBUS_9    (_busINBUS[09]),
        ._INBUS_10   (_busINBUS[10]),
        ._INBUS_11   (_busINBUS[11]),

        ._BRKGNTO    (_dmaBRKGNTO),
        ._BRKGNTO_o  (_dmaBRKGNTO),
        ._BRKRQST_o  (_dmaBRKRQST),
        ._BRKWRM_o   (_dmaBRKWRM),
        ._CAINC_o    (_dmaCAINC),
        ._CYCLE3_o   (_dmaCYCLE3),
        ._DMAFLD_0_o (_dmaDMAFLD[0]),
        ._DMAFLD_1_o (_dmaDMAFLD[1]),
        ._DMAFLD_2_o (_dmaDMAFLD[2]),
        ._INBUS_0_o  (_dmaINBUS[00]),
        ._INBUS_1_o  (_dmaINBUS[01]),
        ._INBUS_2_o  (_dmaINBUS[02]),
        ._INBUS_3_o  (_dmaINBUS[03]),
        ._INBUS_4_o  (_dmaINBUS[04]),
        ._INBUS_5_o  (_dmaINBUS[05]),
        ._INBUS_6_o  (_dmaINBUS[06]),
        ._INBUS_7_o  (_dmaINBUS[07]),
        ._INBUS_8_o  (_dmaINBUS[08]),
        ._INBUS_9_o  (_dmaINBUS[09]),
        ._INBUS_10_o (_dmaINBUS[10]),
        ._INBUS_11_o (_dmaINBUS[11])
    );

    wire _dmbBRKGNTI, _dmbBRKGNTO, _dmbBRKRQST, _dmbBRKWRM, _dmbCAINC, _dmbCYCLE3;
    wire dmbwrite;
    wire[2:0] _dmbDMAFLD;
    wire[11:00] _dmbINBUS;
    wire[31:00] dmbrdata;

    assign _dmbBRKGNTO = ~ _dmbBRKGNTI;
    assign _dmbBRKRQST = 1;
    assign _dmbBRKWRM  = 1;
    assign _dmbCAINC   = 1;
    assign _dmbCYCLE3  = 1;
    assign _dmbDMAFLD  = 7;
    assign _dmbINBUS   = 12'o7777;
    assign dmbrdata    = 0;

    dmatest testb (
        .seed   (2),
        .zclock (zclock),
        .zreset (zreset),

        .armwrite (dmbwrite),
        .armraddr (armraddr[03:02]), 
        .armwaddr (armwaddr[03:02]),
        .armwdata (armwdata),
        .armrdata (dmbrdata),

        ._BRKGNTI    (_dmbBRKGNTI),
        ._BRKCYC     (_busBRKCYC),
        ._BUSINI     (_busBUSINI),
        ._BWCOV      (_busBWCOV),
        ._CLOCK      (_busCLOCK),
        ._MBUF_0     (_busMBUF[00]),
        ._MBUF_1     (_busMBUF[01]),
        ._MBUF_2     (_busMBUF[02]),
        ._MBUF_3     (_busMBUF[03]),
        ._MBUF_4     (_busMBUF[04]),
        ._MBUF_5     (_busMBUF[05]),
        ._MBUF_6     (_busMBUF[06]),
        ._MBUF_7     (_busMBUF[07]),
        ._MBUF_8     (_busMBUF[08]),
        ._MBUF_9     (_busMBUF[09]),
        ._MBUF_10    (_busMBUF[10]),
        ._MBUF_11    (_busMBUF[11]),
        ._RESET      (_busRESET),
        ._TP2        (_busTP2),
        ._TP3        (_busTP3),
        ._TS2        (_busTS2),
        ._TS3        (_busTS3),
        ._TS4        (_busTS4),
        ._BRKRQST    (_busBRKRQST),
        ._BRKWRM     (_busBRKWRM),
        ._CAINC      (_busCAINC),
        ._CYCLE3     (_busCYCLE3),
        ._DMAFLD_0   (_busDMAFLD[0]),
        ._DMAFLD_1   (_busDMAFLD[1]),
        ._DMAFLD_2   (_busDMAFLD[2]),
        ._INBUS_0    (_busINBUS[00]),
        ._INBUS_1    (_busINBUS[01]),
        ._INBUS_2    (_busINBUS[02]),
        ._INBUS_3    (_busINBUS[03]),
        ._INBUS_4    (_busINBUS[04]),
        ._INBUS_5    (_busINBUS[05]),
        ._INBUS_6    (_busINBUS[06]),
        ._INBUS_7    (_busINBUS[07]),
        ._INBUS_8    (_busINBUS[08]),
        ._INBUS_9    (_busINBUS[09]),
        ._INBUS_10   (_busINBUS[10]),
        ._INBUS_11   (_busINBUS[11]),

        ._BRKGNTO    (_dmbBRKGNTO),
        ._BRKGNTO_o  (_dmbBRKGNTO),
        ._BRKRQST_o  (_dmbBRKRQST),
        ._BRKWRM_o   (_dmbBRKWRM),
        ._CAINC_o    (_dmbCAINC),
        ._CYCLE3_o   (_dmbCYCLE3),
        ._DMAFLD_0_o (_dmbDMAFLD[0]),
        ._DMAFLD_1_o (_dmbDMAFLD[1]),
        ._DMAFLD_2_o (_dmbDMAFLD[2]),
        ._INBUS_0_o  (_dmbINBUS[00]),
        ._INBUS_1_o  (_dmbINBUS[01]),
        ._INBUS_2_o  (_dmbINBUS[02]),
        ._INBUS_3_o  (_dmbINBUS[03]),
        ._INBUS_4_o  (_dmbINBUS[04]),
        ._INBUS_5_o  (_dmbINBUS[05]),
        ._INBUS_6_o  (_dmbINBUS[06]),
        ._INBUS_7_o  (_dmbINBUS[07]),
        ._INBUS_8_o  (_dmbINBUS[08]),
        ._INBUS_9_o  (_dmbINBUS[09]),
        ._INBUS_10_o (_dmbINBUS[10]),
        ._INBUS_11_o (_dmbINBUS[11])
    );
***/

    /////////////////////////////
    //  COMBINING BUS SIGNALS  //
    /////////////////////////////

    // active low signals getting wire-anded on the backplane
    assign _busACCLEAR = _eaeACCLEAR  & ~ iACCLEAR   & (_zynioenabd | ~ zynACCLEAR);
    assign _busBRKRQST =   ~ iBRKRQST & (_zynpoweron | ~ zynBRKRQST);
    assign _busBRKWRM  =   ~ iBRKWRM  & (_zyndmagntd | ~ zynBRKWRM);
    assign _busCAINC   =  ~ iCAINC    & (_zyndmagntd | ~ zynCAINC);
    assign _busCLOCK   =                (_zynpoweron | ~ zynCLOCK);
    assign _busCYCLE3  =  ~ iCYCLE3   & (_zyndmagntd | ~ zynCYCLE3);
    assign _busDFLD    = _conDFLD     &  _memDFLD;
    assign _busDMAFLD  =  ~ iDMAFLD   & (_zyndmagntd ? 3'o7 : ~ zynDMAFLD);
    assign _busIFLD    = _conIFLD     &  _memIFLD;
    assign _busINBUS   = _conINBUS    &  _eaeINBUS & ~ iINBUS & _memINBUS & (_zynioenabd ? 12'o7777 : ~ zynINBUS);
    assign _busINTRQST = ~ iINTRQST   & (_zynpoweron | ~ zynINTRQST);
    assign _busIOSKIP  = _eaeIOSKIP   & ~ iIOSKIP  & (_zynioenabd | ~ zynIOSKIP);
    assign _busMEMDIS  = ~ memdisab;
    assign _busPAUSE   = _eaePAUSE    & ~ iPAUSE   & (_zynpoweron | ~ zynPAUSE);
    assign _busRESET   =                (_zynpoweron | ~ zynRESET);

    // break grant chain
    assign zynBRKGNTI = ~ _cpuBRKGNTO;
    assign   oBRKGNTO = ~ _zynpoweron & zynBRKGNTO;

endmodule
