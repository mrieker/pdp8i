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

//////////////////////////////////////////////
//  zturn board with zturn plugged into it  //
//////////////////////////////////////////////

module zturnbundle (input yclock, zclock, zreset

    , output _running, _shadfrz, _simming
    , output[31:00] regarmintreq
    , input directread

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

    ,output hdw_iCONSCK
    ,output hdw_iCONSDA
    ,input  hdw_oCONSDA

    , input  _ACUM_0
    , input  _ACUM_1
    , input  _ACUM_2
    , input  _ACUM_3
    , input  _ACUM_4
    , input  _ACUM_5
    , input  _ACUM_6
    , input  _ACUM_7
    , input  _ACUM_8
    , input  _ACUM_9
    , input  _ACUM_10
    , input  _ACUM_11
    , input  _BRKCYC
    , input  _BRKGNTI
    , input  _BUSINI
    , input  _BWCOV
    , input  _IOP
    , input  _LINK
    , input  _MADR_0
    , input  _MADR_1
    , input  _MADR_2
    , input  _MADR_3
    , input  _MADR_4
    , input  _MADR_5
    , input  _MADR_6
    , input  _MADR_7
    , input  _MADR_8
    , input  _MADR_9
    , input  _MADR_10
    , input  _MADR_11
    , input  _MAJST_0
    , input  _MAJST_1
    , input  _MAJST_2
    , input  _MAJST_3
    , input  _MBUF_0
    , input  _MBUF_1
    , input  _MBUF_2
    , input  _MBUF_3
    , input  _MBUF_4
    , input  _MBUF_5
    , input  _MBUF_6
    , input  _MBUF_7
    , input  _MBUF_8
    , input  _MBUF_9
    , input  _MBUF_10
    , input  _MBUF_11
    , input  _MEAD_0
    , input  _MEAD_1
    , input  _MEAD_2
    , input  _RUN
    , input  _TP1
    , input  _TP2
    , input  _TP3
    , input  _TP4
    , input  _TS1
    , input  _TS2
    , input  _TS3
    , input  _TS4
    , input  _ACCLEAR
    , output _ACCLEAR_o
    , input  _BRKGNTO
    , output _BRKGNTO_o
    , input  _BRKRQST
    , output _BRKRQST_o
    , input  _BRKWRM
    , output _BRKWRM_o
    , input  _CAINC
    , output _CAINC_o
    , input  _CLOCK
    , output _CLOCK_o
    , input  _CYCLE3
    , output _CYCLE3_o
    , input  _DMAFLD_0
    , output _DMAFLD_0_o
    , input  _DMAFLD_1
    , output _DMAFLD_1_o
    , input  _DMAFLD_2
    , output _DMAFLD_2_o
    , input  _INBUS_0
    , output _INBUS_0_o
    , input  _INBUS_1
    , output _INBUS_1_o
    , input  _INBUS_2
    , output _INBUS_2_o
    , input  _INBUS_3
    , output _INBUS_3_o
    , input  _INBUS_4
    , output _INBUS_4_o
    , input  _INBUS_5
    , output _INBUS_5_o
    , input  _INBUS_6
    , output _INBUS_6_o
    , input  _INBUS_7
    , output _INBUS_7_o
    , input  _INBUS_8
    , output _INBUS_8_o
    , input  _INBUS_9
    , output _INBUS_9_o
    , input  _INBUS_10
    , output _INBUS_10_o
    , input  _INBUS_11
    , output _INBUS_11_o
    , input  _INTRQST
    , output _INTRQST_o
    , input  _IOSKIP
    , output _IOSKIP_o
    , input  _MEMDIS
    , output _MEMDIS_o
    , input  _PAUSE
    , output _PAUSE_o
    , input  _RESET
    , output _RESET_o
);

    wire hdw_dmagntd_n, hdw_iACCLEAR, hdw_iBRKGNTO, hdw_iBRKRQST, hdw_iBRKWRM, hdw_iCAINC, hdw_iCLOCK;
    wire hdw_iCYCLE3;
    wire hdw_iINTRQST, hdw_iIOSKIP, hdw_iMEMDIS, hdw_iPAUSE, hdw_iRESET, hdw_ioenabd_n;
    wire hdw_oBRKCYC, hdw_oBRKGNTI, hdw_oBRKRQST, hdw_oBUSINI, hdw_oBWCOV, hdw_oIOP, hdw_oLINK;
    wire hdw_oRUN, hdw_oTP1, hdw_oTP2, hdw_oTP3, hdw_oTP4, hdw_oTS1, hdw_oTS2;
    wire hdw_oTS3, hdw_oTS4, hdw_poweron_n;
    wire[11:00] hdw_iINBUS, hdw_oACUM, hdw_oMADR, hdw_oMBUF;
    wire[2:0] hdw_iDMAFLD, hdw_oMEAD;
    wire[3:0] hdw_oMAJST;

    // zturn board without zturn
    // contains 74AHC540 and 74AHCT540 chips
    zturn bareboard (
        .zclock (zclock),
        .zreset (zreset),
        .GND    (0),
        .V5ZYNQ (1),
        .VCC    (1),
        ._3V3   (1),
        .spare1 (0),
        .spare2 (0),
        .spare3 (0),

        // J1..J4 edge connectors
        // pass directly as-is to our module pins
        ._ACUM_0    (_ACUM_0),
        ._ACUM_1    (_ACUM_1),
        ._ACUM_2    (_ACUM_2),
        ._ACUM_3    (_ACUM_3),
        ._ACUM_4    (_ACUM_4),
        ._ACUM_5    (_ACUM_5),
        ._ACUM_6    (_ACUM_6),
        ._ACUM_7    (_ACUM_7),
        ._ACUM_8    (_ACUM_8),
        ._ACUM_9    (_ACUM_9),
        ._ACUM_10   (_ACUM_10),
        ._ACUM_11   (_ACUM_11),
        ._BRKCYC    (_BRKCYC),
        ._BRKGNTI   (_BRKGNTI),
        ._BUSINI    (_BUSINI),
        ._BWCOV     (_BWCOV),
        ._IOP       (_IOP),
        ._LINK      (_LINK),
        ._MADR_0    (_MADR_0),
        ._MADR_1    (_MADR_1),
        ._MADR_2    (_MADR_2),
        ._MADR_3    (_MADR_3),
        ._MADR_4    (_MADR_4),
        ._MADR_5    (_MADR_5),
        ._MADR_6    (_MADR_6),
        ._MADR_7    (_MADR_7),
        ._MADR_8    (_MADR_8),
        ._MADR_9    (_MADR_9),
        ._MADR_10   (_MADR_10),
        ._MADR_11   (_MADR_11),
        ._MAJST_0   (_MAJST_0),
        ._MAJST_1   (_MAJST_1),
        ._MAJST_2   (_MAJST_2),
        ._MAJST_3   (_MAJST_3),
        ._MBUF_0    (_MBUF_0),
        ._MBUF_1    (_MBUF_1),
        ._MBUF_2    (_MBUF_2),
        ._MBUF_3    (_MBUF_3),
        ._MBUF_4    (_MBUF_4),
        ._MBUF_5    (_MBUF_5),
        ._MBUF_6    (_MBUF_6),
        ._MBUF_7    (_MBUF_7),
        ._MBUF_8    (_MBUF_8),
        ._MBUF_9    (_MBUF_9),
        ._MBUF_10   (_MBUF_10),
        ._MBUF_11   (_MBUF_11),
        ._MEAD_0    (_MEAD_0),
        ._MEAD_1    (_MEAD_1),
        ._MEAD_2    (_MEAD_2),
        ._RUN       (_RUN),
        ._TP1       (_TP1),
        ._TP2       (_TP2),
        ._TP3       (_TP3),
        ._TP4       (_TP4),
        ._TS1       (_TS1),
        ._TS2       (_TS2),
        ._TS3       (_TS3),
        ._TS4       (_TS4),

        ._ACCLEAR   (_ACCLEAR),
        ._BRKGNTO   (_BRKGNTO),
        ._BRKRQST   (_BRKRQST),
        ._BRKWRM    (_BRKWRM),
        ._CAINC     (_CAINC),
        ._CLOCK     (_CLOCK),
        ._CYCLE3    (_CYCLE3),
        ._DMAFLD_0  (_DMAFLD_0),
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
        ._INTRQST    (_INTRQST),
        ._IOSKIP     (_IOSKIP),
        ._MEMDIS     (_MEMDIS),
        ._PAUSE      (_PAUSE),
        ._RESET      (_RESET),

        ._ACCLEAR_o (_ACCLEAR_o),
        ._BRKGNTO_o (_BRKGNTO_o),
        ._BRKRQST_o (_BRKRQST_o),
        ._BRKWRM_o  (_BRKWRM_o),
        ._CAINC_o   (_CAINC_o),
        ._CLOCK_o   (_CLOCK_o),
        ._CYCLE3_o  (_CYCLE3_o),
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
        ._INTRQST_o  (_INTRQST_o),
        ._IOSKIP_o   (_IOSKIP_o),
        ._MEMDIS_o   (_MEMDIS_o),
        ._PAUSE_o    (_PAUSE_o),
        ._RESET_o    (_RESET_o),

        // J11,J12 signals go to zturn itself
        // - signals zturn sends out to bus
        .hdw_bCONSDA    (),
        .hdw_dmagntd_n  (hdw_dmagntd_n),
        .hdw_iACCLEAR   (hdw_iACCLEAR),
        .hdw_iBRKGNTO   (hdw_iBRKGNTO),
        .hdw_iBRKRQST   (hdw_iBRKRQST),
        .hdw_iBRKWRM    (hdw_iBRKWRM),
        .hdw_iCAINC     (hdw_iCAINC),
        .hdw_iCLOCK     (hdw_iCLOCK),
        .hdw_iCONSCK    (hdw_iCONSCK),
        .hdw_iCYCLE3    (hdw_iCYCLE3),
        .hdw_iDMAFLD_0  (hdw_iDMAFLD[0]),
        .hdw_iDMAFLD_1  (hdw_iDMAFLD[1]),
        .hdw_iDMAFLD_2  (hdw_iDMAFLD[2]),
        .hdw_iINBUS_0   (hdw_iINBUS[0]),
        .hdw_iINBUS_1   (hdw_iINBUS[1]),
        .hdw_iINBUS_2   (hdw_iINBUS[2]),
        .hdw_iINBUS_3   (hdw_iINBUS[3]),
        .hdw_iINBUS_4   (hdw_iINBUS[4]),
        .hdw_iINBUS_5   (hdw_iINBUS[5]),
        .hdw_iINBUS_6   (hdw_iINBUS[6]),
        .hdw_iINBUS_7   (hdw_iINBUS[7]),
        .hdw_iINBUS_8   (hdw_iINBUS[8]),
        .hdw_iINBUS_9   (hdw_iINBUS[9]),
        .hdw_iINBUS_10  (hdw_iINBUS[10]),
        .hdw_iINBUS_11  (hdw_iINBUS[11]),
        .hdw_iINTRQST   (hdw_iINTRQST),
        .hdw_iIOSKIP    (hdw_iIOSKIP),
        .hdw_iMEMDIS    (hdw_iMEMDIS),
        .hdw_iPAUSE     (hdw_iPAUSE),
        .hdw_iRESET     (hdw_iRESET),
        .hdw_ioenabd_n  (hdw_ioenabd_n),
        .hdw_poweron_n  (hdw_poweron_n),

        // - signals zturn receives in from bus
        .hdw_oACUM_0    (hdw_oACUM[0]),
        .hdw_oACUM_1    (hdw_oACUM[1]),
        .hdw_oACUM_2    (hdw_oACUM[2]),
        .hdw_oACUM_3    (hdw_oACUM[3]),
        .hdw_oACUM_4    (hdw_oACUM[4]),
        .hdw_oACUM_5    (hdw_oACUM[5]),
        .hdw_oACUM_6    (hdw_oACUM[6]),
        .hdw_oACUM_7    (hdw_oACUM[7]),
        .hdw_oACUM_8    (hdw_oACUM[8]),
        .hdw_oACUM_9    (hdw_oACUM[9]),
        .hdw_oACUM_10   (hdw_oACUM[10]),
        .hdw_oACUM_11   (hdw_oACUM[11]),
        .hdw_oBRKCYC    (hdw_oBRKCYC),
        .hdw_oBRKGNTI   (hdw_oBRKGNTI),
        .hdw_oBRKRQST   (hdw_oBRKRQST),
        .hdw_oBUSINI    (hdw_oBUSINI),
        .hdw_oBWCOV     (hdw_oBWCOV),
        .hdw_oIOP       (hdw_oIOP),
        .hdw_oLINK      (hdw_oLINK),
        .hdw_oMADR_0    (hdw_oMADR[0]),
        .hdw_oMADR_1    (hdw_oMADR[1]),
        .hdw_oMADR_2    (hdw_oMADR[2]),
        .hdw_oMADR_3    (hdw_oMADR[3]),
        .hdw_oMADR_4    (hdw_oMADR[4]),
        .hdw_oMADR_5    (hdw_oMADR[5]),
        .hdw_oMADR_6    (hdw_oMADR[6]),
        .hdw_oMADR_7    (hdw_oMADR[7]),
        .hdw_oMADR_8    (hdw_oMADR[8]),
        .hdw_oMADR_9    (hdw_oMADR[9]),
        .hdw_oMADR_10   (hdw_oMADR[10]),
        .hdw_oMADR_11   (hdw_oMADR[11]),
        .hdw_oMAJST_0   (hdw_oMAJST[0]),
        .hdw_oMAJST_1   (hdw_oMAJST[1]),
        .hdw_oMAJST_2   (hdw_oMAJST[2]),
        .hdw_oMAJST_3   (hdw_oMAJST[3]),
        .hdw_oMBUF_0    (hdw_oMBUF[0]),
        .hdw_oMBUF_1    (hdw_oMBUF[1]),
        .hdw_oMBUF_2    (hdw_oMBUF[2]),
        .hdw_oMBUF_3    (hdw_oMBUF[3]),
        .hdw_oMBUF_4    (hdw_oMBUF[4]),
        .hdw_oMBUF_5    (hdw_oMBUF[5]),
        .hdw_oMBUF_6    (hdw_oMBUF[6]),
        .hdw_oMBUF_7    (hdw_oMBUF[7]),
        .hdw_oMBUF_8    (hdw_oMBUF[8]),
        .hdw_oMBUF_9    (hdw_oMBUF[9]),
        .hdw_oMBUF_10   (hdw_oMBUF[10]),
        .hdw_oMBUF_11   (hdw_oMBUF[11]),
        .hdw_oMEAD_0    (hdw_oMEAD[0]),
        .hdw_oMEAD_1    (hdw_oMEAD[1]),
        .hdw_oMEAD_2    (hdw_oMEAD[2]),
        .hdw_oRUN       (hdw_oRUN),
        .hdw_oTP1       (hdw_oTP1),
        .hdw_oTP2       (hdw_oTP2),
        .hdw_oTP3       (hdw_oTP3),
        .hdw_oTP4       (hdw_oTP4),
        .hdw_oTS1       (hdw_oTS1),
        .hdw_oTS2       (hdw_oTS2),
        .hdw_oTS3       (hdw_oTS3),
        .hdw_oTS4       (hdw_oTS4),

        .hdw_oACUM_0_o  (hdw_oACUM[0]),
        .hdw_oACUM_1_o  (hdw_oACUM[1]),
        .hdw_oACUM_2_o  (hdw_oACUM[2]),
        .hdw_oACUM_3_o  (hdw_oACUM[3]),
        .hdw_oACUM_4_o  (hdw_oACUM[4]),
        .hdw_oACUM_5_o  (hdw_oACUM[5]),
        .hdw_oACUM_6_o  (hdw_oACUM[6]),
        .hdw_oACUM_7_o  (hdw_oACUM[7]),
        .hdw_oACUM_8_o  (hdw_oACUM[8]),
        .hdw_oACUM_9_o  (hdw_oACUM[9]),
        .hdw_oACUM_10_o (hdw_oACUM[10]),
        .hdw_oACUM_11_o (hdw_oACUM[11]),
        .hdw_oBRKCYC_o  (hdw_oBRKCYC),
        .hdw_oBRKGNTI_o (hdw_oBRKGNTI),
        .hdw_oBRKRQST_o (hdw_oBRKRQST),
        .hdw_oBUSINI_o  (hdw_oBUSINI),
        .hdw_oBWCOV_o   (hdw_oBWCOV),
        .hdw_oIOP_o     (hdw_oIOP),
        .hdw_oLINK_o    (hdw_oLINK),
        .hdw_oMADR_0_o  (hdw_oMADR[0]),
        .hdw_oMADR_1_o  (hdw_oMADR[1]),
        .hdw_oMADR_2_o  (hdw_oMADR[2]),
        .hdw_oMADR_3_o  (hdw_oMADR[3]),
        .hdw_oMADR_4_o  (hdw_oMADR[4]),
        .hdw_oMADR_5_o  (hdw_oMADR[5]),
        .hdw_oMADR_6_o  (hdw_oMADR[6]),
        .hdw_oMADR_7_o  (hdw_oMADR[7]),
        .hdw_oMADR_8_o  (hdw_oMADR[8]),
        .hdw_oMADR_9_o  (hdw_oMADR[9]),
        .hdw_oMADR_10_o (hdw_oMADR[10]),
        .hdw_oMADR_11_o (hdw_oMADR[11]),
        .hdw_oMAJST_0_o (hdw_oMAJST[0]),
        .hdw_oMAJST_1_o (hdw_oMAJST[1]),
        .hdw_oMAJST_2_o (hdw_oMAJST[2]),
        .hdw_oMAJST_3_o (hdw_oMAJST[3]),
        .hdw_oMBUF_0_o  (hdw_oMBUF[0]),
        .hdw_oMBUF_1_o  (hdw_oMBUF[1]),
        .hdw_oMBUF_2_o  (hdw_oMBUF[2]),
        .hdw_oMBUF_3_o  (hdw_oMBUF[3]),
        .hdw_oMBUF_4_o  (hdw_oMBUF[4]),
        .hdw_oMBUF_5_o  (hdw_oMBUF[5]),
        .hdw_oMBUF_6_o  (hdw_oMBUF[6]),
        .hdw_oMBUF_7_o  (hdw_oMBUF[7]),
        .hdw_oMBUF_8_o  (hdw_oMBUF[8]),
        .hdw_oMBUF_9_o  (hdw_oMBUF[9]),
        .hdw_oMBUF_10_o (hdw_oMBUF[10]),
        .hdw_oMBUF_11_o (hdw_oMBUF[11]),
        .hdw_oMEAD_0_o  (hdw_oMEAD[0]),
        .hdw_oMEAD_1_o  (hdw_oMEAD[1]),
        .hdw_oMEAD_2_o  (hdw_oMEAD[2]),
        .hdw_oRUN_o     (hdw_oRUN),
        .hdw_oTP1_o     (hdw_oTP1),
        .hdw_oTP2_o     (hdw_oTP2),
        .hdw_oTP3_o     (hdw_oTP3),
        .hdw_oTP4_o     (hdw_oTP4),
        .hdw_oTS1_o     (hdw_oTS1),
        .hdw_oTS2_o     (hdw_oTS2),
        .hdw_oTS3_o     (hdw_oTS3),
        .hdw_oTS4_o     (hdw_oTS4)
    );

    // ZTurn PL itself
    Zynq #(.BIDIRCONSDA (0)) zynqinst (
        .CLOCK      (yclock),
        .RESET_N    (~ zreset),
        .LEDoutR_N  (_shadfrz),
        .LEDoutG_N  (_running),
        .LEDoutB_N  (_simming),
        .armintreq  (),
        .zgintflags (regarmintreq),
        .directread (directread),
        .ground     (),

        // io bus connections
        .hdw_oACUM    (hdw_oACUM),
        .hdw_oBRKCYC  (hdw_oBRKCYC),
        .hdw_oBRKGNTI (hdw_oBRKGNTI),
        .hdw_oBRKRQST (hdw_oBRKRQST),
        .hdw_oBUSINI  (hdw_oBUSINI),
        .hdw_oBWCOV   (hdw_oBWCOV),
        .hdw_oIOP     (hdw_oIOP),
        .hdw_oLINK    (hdw_oLINK),
        .hdw_oMADR    (hdw_oMADR),
        .hdw_oMBUF    (hdw_oMBUF),
        .hdw_oMEAD    (hdw_oMEAD),
        .hdw_oMAJST   (hdw_oMAJST),
        .hdw_oRUN     (hdw_oRUN),
        .hdw_oTP1     (hdw_oTP1),
        .hdw_oTP2     (hdw_oTP2),
        .hdw_oTP3     (hdw_oTP3),
        .hdw_oTP4     (hdw_oTP4),
        .hdw_oTS1     (hdw_oTS1),
        .hdw_oTS2     (hdw_oTS2),
        .hdw_oTS3     (hdw_oTS3),
        .hdw_oTS4     (hdw_oTS4),

        .hdw_iACCLEAR (hdw_iACCLEAR),
        .hdw_iBRKGNTO (hdw_iBRKGNTO),
        .hdw_iBRKRQST (hdw_iBRKRQST),
        .hdw_iBRKWRM  (hdw_iBRKWRM),
        .hdw_iCAINC   (hdw_iCAINC),
        .hdw_iCLOCK   (hdw_iCLOCK),       // zynq.v generates 10MHz clock
        .hdw_iCYCLE3  (hdw_iCYCLE3),
        .hdw_iDMAFLD  (hdw_iDMAFLD),
        .hdw_iINBUS   (hdw_iINBUS),
        .hdw_iINTRQST (hdw_iINTRQST),
        .hdw_iIOSKIP  (hdw_iIOSKIP),
        .hdw_iMEMDIS  (hdw_iMEMDIS),
        .hdw_iPAUSE   (hdw_iPAUSE),
        .hdw_iRESET   (hdw_iRESET),       // zreset + arm regctle<fpgareset>

        // output driver enables
        .hdw_dmagntd_n (hdw_dmagntd_n),
        .hdw_ioenabd_n (hdw_ioenabd_n),
        .hdw_poweron_n (hdw_poweron_n),

        // i2c interface to hardware front panel
        .hdw_iCONSCK  (hdw_iCONSCK),
        .hdw_bCONSDA  (),
        .hdw_iCONSDA  (hdw_iCONSDA),
        .hdw_oCONSDA  (hdw_oCONSDA),

        // spares
        .spare1 (1'b0),
        .spare2 (1'b0),
        .spare3 (1'b0),

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

endmodule
