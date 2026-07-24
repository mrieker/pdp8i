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

// PDP-8/I processor, including console, extended arithmetic, memory extension and 32KW memory

module pdp8isim (
    input CLOCK,                    // zynq 100MHz clock
    input RESET,                    // zynq power-on reset

    input iACCLEAR,                 // io pulse clears AC
    input iBRKRQST,                 // requesting break
    input iBRKWRM,                  // break cycle writes memory
    input iCAINC,                   // curad cycle increments address word
    input iCLOCK,                   // 10MHz
    input iCYCLE3,                  // do 3-cycle break
    input[2:0] iDMAFLD,             // device sending address for DMA
    input[11:00] iINBUS,            // device sending data for PIO or DMA
    input iINTRQST,                 // request interrupt
    input iIOSKIP,                  // increment PC at end of IO pulse
    input iMEMDIS,                  // disable internal memory
    input iPAUSE,                   // pause processor clocking (stretch cycle)
    input iRESET,                   // zynq power-on reset + arm-commanded hard reset

    output[11:00] oACUM,
    output oBRKCYC,                 // break cycle
    output oBRKGNTO,                // chained break grant
    output oBUSINI,                 // initialize bus devices
    output oBWCOV,                  // 3-cycle DMA wordcount overflowed
    output oIOP,                    // io instruction pulse
    output oLINK,
    output[11:00] oMADR,
    output[11:00] oMBUF,
    output[2:0] oMEAD,
    output[3:0] oMAJST,
    output oRUN,
    output oTP1, oTP2, oTP3, oTP4,
    output oTS1, oTS2, oTS3, oTS4,

    input  iCONSCK,                 // console I2C
    input  iCONSDA,
    output oCONSDA

    ,output[3:0] majst              // debug
    ,output run
    ,output swldad
    ,output swdepos
    ,output swexam
    ,output swstart
    ,output swcont
);

    wire zclock = CLOCK;
    wire zreset = RESET;

    // combined bus signals
    wire _busION, _busLINK, _busPAUSE, _busREADSR, _busRUN, _busBRKRQST,
        _busBRKWRM, _busCAINC, _busCYCLE3, _busINTRQST, _busBUSINI, _busACCLEAR,
        _busIOSKIP, _busLNKTOG, _busIOP, _busINTINH, _busBWCOV, _busBRKCYC;
    wire _busSWCONT, _busSWDEPOS, _busSWEXAM, _busSWLDAD, _busSWSINST, _busSWSSTEP, _busSWSTART;
    wire _busTP1, _busTP2, _busTP3, _busTP4, _busTS1, _busTS2, _busTS3, _busTS4;
    wire[2:0] _busDFLD, _busIFLD, _busDMAFLD, _busMEAD;
    wire[3:0] _busMAJST;
    wire[4:0] _busSCTR;
    wire[11:00] _busACUM, _busMADR, _busMBUF, _busMQUO, _busPCTR, _busINBUS;
    wire[11:09] _busIREG;

    // 10MHz clock
    wire _busCLOCK = ~ iCLOCK;

    // disable internal memory
    // arm must provide read data on INBUS during TS1
    //  and can capture write data from MBUF during TS3
    wire _busMEMDIS = ~ iMEMDIS;

    // power-on reset (zynq power-on reset + arm-commanded hard reset)
    wire _busRESET = ~ iRESET;

    // OS/8 does a 'ISZ x ; JMP .-1' loop as a delay during printing
    // zap it out by pretending 'x' contains 7777 on entry to the loop
    reg lasttp1, lastts1;
    reg[1:0] os8zapstate;
    reg[14:00] os8zapiszdata, os8zapjmpaddr;
    wire[14:00] os8zapaddress = ~ { _busMEAD, _busMADR };
    wire[14:00] os8zapiszaddr = os8zapjmpaddr - 1;
    wire os8zap = (os8zapstate == 3);
    wire aa = (_busMAJST == 14);
    wire bb = (~ _busINBUS[11:07] == 5'b10101);
    wire cc = ({ 1'b0, ~ _busINBUS[06:00] } == { 1'b0, ~ _busMADR[06:00] } - 8'b1);
    wire dd = (_busMAJST == 12);
    wire ee = (os8zapaddress == os8zapiszdata);
    wire ff = (os8zapaddress == os8zapiszaddr);
    wire gg = (~ _busINBUS[11:07] == 5'b01001);

    always @(posedge zclock) begin
        if (iRESET) begin
            os8zapstate <= 0;
        end else begin
            case (os8zapstate)

                // looking for 'JMP .-1' at posedge TP1 of FETCH cycle
                0: begin
                    if (~ lasttp1 & ~ _busTP1) begin        // inbus from memory is now valid
                        if (aa & bb & cc) begin
                            os8zapjmpaddr <= os8zapaddress;
                            os8zapstate   <= 1;
                        end
                    end
                end

                // the following cycle (at posedge TP1) must be an 'ISZ x' on same page
                1: begin
                    if (~ lasttp1 & ~ _busTP1) begin        // inbus from memory is now valid
                        if (aa & ff & gg) begin
                            os8zapiszdata <= ~ { _busMEAD, _busMADR[11:07], _busINBUS[06:00] };
                            os8zapstate   <= 2;
                        end else begin
                            os8zapstate   <= 0;
                        end
                    end
                end

                // the following cycle (at posedge TS1) must be an EXEC cycle that accesses location 'x'
                // setting os8zapstate <= 3 will jam the value to 7777 which will increment to 0000
                2: begin
                    if (~ lastts1 & ~ _busTS1) begin        // majst, mead, madr from processor are valid
                        if (dd & ee) begin
                            os8zapstate <= 3;               // jam the read to 7777
                        end else begin
                            os8zapstate <= 0;
                        end
                    end
                end

                // wait for end of the TS1 that reads the 'x' from memory that we are jamming to 7777
                3: begin
                    if (_busTS1) begin                      // wait for memory read to complete
                        os8zapstate <= 0;                   // stop jamming it to 7777
                    end
                end
            endcase
        end
        lastts1 <= ~ _busTS1;
        lasttp1 <= ~ _busTP1;
    end

    ///////////////
    //  CONSOLE  //
    ///////////////

    wire[2:0] _conDFLD, _conIFLD;
    wire[11:00] _conINBUS;
    wire lttime, swtime;

    wire[27:04] gpout;
    wire[15:04] gpin = (gpout[18:16] == 7) ? 12'o7777 : // light select hi-Z value from panel (or it jams mcp23017 from sensing lights)
                                             12'o0000;  // switches all zeroes (gpio buttons all need to be off or they jam mcp23017 buttons)

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

        .CONSCK   (iCONSCK),
        .CONSDA   (iCONSDA),
        .CONSDA_o (oCONSDA),

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
        ._SWSINST_o (_busSWSINST)     //toggle single instruction
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

        ._BUSINI    (_busBUSINI),
        ._CLOCK     (_busCLOCK),

        ._DMAFLD_0  (_busDMAFLD[0]),
        ._DMAFLD_1  (_busDMAFLD[1]),
        ._DMAFLD_2  (_busDMAFLD[2]),

        ._IOP       (_busIOP),

        ._IREG_9    (_busIREG[9]),
        ._IREG_10   (_busIREG[10]),
        ._IREG_11   (_busIREG[11]),

        ._MADR_0     (_busMADR[0]),
        ._MADR_1     (_busMADR[1]),
        ._MADR_2     (_busMADR[2]),
        ._MADR_3     (_busMADR[3]),
        ._MADR_4     (_busMADR[4]),
        ._MADR_5     (_busMADR[5]),
        ._MADR_6     (_busMADR[6]),
        ._MADR_7     (_busMADR[7]),
        ._MADR_8     (_busMADR[8]),
        ._MADR_9     (_busMADR[9]),
        ._MADR_10    (_busMADR[10]),
        ._MADR_11    (_busMADR[11]),

        ._MAJST_0    (_busMAJST[0]),
        ._MAJST_1    (_busMAJST[1]),
        ._MAJST_2    (_busMAJST[2]),
        ._MAJST_3    (_busMAJST[3]),

        ._MBUF_0     (_busMBUF[0]),
        ._MBUF_1     (_busMBUF[1]),
        ._MBUF_2     (_busMBUF[2]),
        ._MBUF_3     (_busMBUF[3]),
        ._MBUF_4     (_busMBUF[4]),
        ._MBUF_5     (_busMBUF[5]),
        ._MBUF_6     (_busMBUF[6]),
        ._MBUF_7     (_busMBUF[7]),
        ._MBUF_8     (_busMBUF[8]),
        ._MBUF_9     (_busMBUF[9]),
        ._MBUF_10    (_busMBUF[10]),
        ._MBUF_11    (_busMBUF[11]),

        ._MEMDIS     (_busMEMDIS),
        ._RESET      (_busRESET),
        ._SWLDAD     (_busSWLDAD),

        ._TP1        (_busTP1),
        ._TP2        (_busTP2),
        ._TP3        (_busTP3),
        ._TP4        (_busTP4),
        ._TS1        (_busTS1),
        ._TS3        (_busTS3),
        ._TS4        (_busTS4),

        ._DFLD_0     (_busDFLD[0]),
        ._DFLD_1     (_busDFLD[1]),
        ._DFLD_2     (_busDFLD[2]),
        ._IFLD_0     (_busIFLD[0]),
        ._IFLD_1     (_busIFLD[1]),
        ._IFLD_2     (_busIFLD[2]),

        ._DFLD_0_o   (_memDFLD[0]),      // dfld/ifld registers
        ._DFLD_1_o   (_memDFLD[1]),      // ...when LDAD released
        ._DFLD_2_o   (_memDFLD[2]),      // ...else hi-Z
        ._IFLD_0_o   (_memIFLD[0]),
        ._IFLD_1_o   (_memIFLD[1]),
        ._IFLD_2_o   (_memIFLD[2]),

        ._MEAD_0     (_busMEAD[0]),      // field currently in use
        ._MEAD_1     (_busMEAD[1]),
        ._MEAD_2     (_busMEAD[2]),
        ._MEAD_0_o   (_busMEAD[0]),
        ._MEAD_1_o   (_busMEAD[1]),
        ._MEAD_2_o   (_busMEAD[2]),

        ._INBUS_0    (_busINBUS[0]),
        ._INBUS_1    (_busINBUS[1]),
        ._INBUS_2    (_busINBUS[2]),
        ._INBUS_3    (_busINBUS[3]),
        ._INBUS_4    (_busINBUS[4]),
        ._INBUS_5    (_busINBUS[5]),
        ._INBUS_6    (_busINBUS[6]),
        ._INBUS_7    (_busINBUS[7]),
        ._INBUS_8    (_busINBUS[8]),
        ._INBUS_9    (_busINBUS[9]),
        ._INBUS_10   (_busINBUS[10]),
        ._INBUS_11   (_busINBUS[11]),

        ._INBUS_0_o  (_memINBUS[0]),
        ._INBUS_1_o  (_memINBUS[1]),
        ._INBUS_2_o  (_memINBUS[2]),
        ._INBUS_3_o  (_memINBUS[3]),
        ._INBUS_4_o  (_memINBUS[4]),
        ._INBUS_5_o  (_memINBUS[5]),
        ._INBUS_6_o  (_memINBUS[6]),
        ._INBUS_7_o  (_memINBUS[7]),
        ._INBUS_8_o  (_memINBUS[8]),
        ._INBUS_9_o  (_memINBUS[9]),
        ._INBUS_10_o (_memINBUS[10]),
        ._INBUS_11_o (_memINBUS[11]),

        ._INTINH     (_busINTINH),
        ._INTINH_o   (_busINTINH)
    );

    /////////////////
    //  PROCESSOR  //
    /////////////////

    wire _cpuBRKGNTO, _cpuPAUSE;

    wire[11:00] aluq;
    wire cout, memacsw, nxtms_0, nxtms_1, nxtms_2, nxtms_3;

    wire[11:00] _os8zappedinbus = os8zap ? 12'o0000 : _busINBUS;

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

        ._INBUS_0   (_os8zappedinbus[0]),
        ._INBUS_1   (_os8zappedinbus[1]),
        ._INBUS_2   (_os8zappedinbus[2]),
        ._INBUS_3   (_os8zappedinbus[3]),
        ._INBUS_4   (_os8zappedinbus[4]),
        ._INBUS_5   (_os8zappedinbus[5]),
        ._INBUS_6   (_os8zappedinbus[6]),
        ._INBUS_7   (_os8zappedinbus[7]),
        ._INBUS_8   (_os8zappedinbus[8]),
        ._INBUS_9   (_os8zappedinbus[9]),
        ._INBUS_10  (_os8zappedinbus[10]),
        ._INBUS_11  (_os8zappedinbus[11]),

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

        ._wfidisab (1'b1),
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
        ._PAUSE_o   (_cpuPAUSE),
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

    /////////////////////////////
    //  COMBINING BUS SIGNALS  //
    /////////////////////////////

    assign majst   = ~ _busMAJST;
    assign run     = ~ _busRUN;
    assign swldad  = ~ _busSWLDAD;
    assign swdepos = ~ _busSWDEPOS;
    assign swexam  = ~ _busSWEXAM;
    assign swstart = ~ _busSWSTART;
    assign swcont  = ~ _busSWCONT;

    // active low signals getting wire-anded on the backplane
    assign _busACCLEAR = _eaeACCLEAR  & ~ iACCLEAR;
    assign _busBRKRQST =                ~ iBRKRQST;
    assign _busBRKWRM  =                ~ iBRKWRM;
    assign _busCAINC   =                ~ iCAINC;
    assign _busCYCLE3  =                ~ iCYCLE3;
    assign _busDFLD    =                              _memDFLD  & _conDFLD;
    assign _busDMAFLD  =                ~ iDMAFLD;
    assign _busIFLD    =                              _memIFLD  & _conIFLD;
    assign _busINBUS   = _eaeINBUS    & ~ iINBUS    & _memINBUS & _conINBUS;
    assign _busINTRQST =                ~ iINTRQST;
    assign _busIOSKIP  = _eaeIOSKIP   & ~ iIOSKIP;
    assign _busPAUSE   = _eaePAUSE    & ~ iPAUSE    & _cpuPAUSE;

    // bus outputs
    assign oACUM    = ~ _busACUM;
    assign oBRKCYC  = ~ _busBRKCYC;
    assign oBRKGNTO = ~ _cpuBRKGNTO;
    assign oBUSINI  = ~ _busBUSINI;
    assign oBWCOV   = ~ _busBWCOV;
    assign oIOP     = ~ _busIOP;
    assign oLINK    = ~ _busLINK;
    assign oMADR    = ~ _busMADR;
    assign oMBUF    = ~ _busMBUF;
    assign oMEAD    = ~ _busMEAD;
    assign oMAJST   = ~ _busMAJST;
    assign oRUN     = ~ _busRUN;
    assign oTP1     = ~ _busTP1;
    assign oTP2     = ~ _busTP2;
    assign oTP3     = ~ _busTP3;
    assign oTP4     = ~ _busTP4;
    assign oTS1     = ~ _busTS1;
    assign oTS2     = ~ _busTS2;
    assign oTS3     = ~ _busTS3;
    assign oTS4     = ~ _busTS4;

endmodule
