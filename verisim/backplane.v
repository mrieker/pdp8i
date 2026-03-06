
module backplane (
    input clok2,                    // 10MHz clock
    input reset,                    // power-on reset

    input[27:04] gpin,              // gpio connector
    output[27:04] gpout,

    input i3CYCLE,                  // do 3-cycle break
    input iACCLEAR,                 // io pulse clears AC
    input iBRKRQST,                 // requesting break
    input iBRKWRM,                  // break cycle writes memory
    input iCAINC,                   // curad cycle increments address word
    input iHOLD,                    // hold internal clocking (stretch cycle)
    input iINTRQST,                 // request interrupt
    input iIOSKIP,                  // increment PC at end of IO pulse
    input iLNKTOG,                  // toggle link register
    input[14:00] iDMAADDR,          // device sending address for DMA
    input[11:00] iINBUS,            // device sending data for PIO or DMA
    output oBREAK,                  // currently doing BREAK (DMA) cycle
    output oBUSINI,                 // initialize bus devices
    output oBWCOV,                  // 3-cycle DMA wordcount overflowed
    output oIOP,                    // io instruction pulse
    output oLINK,                   // link register
    output oRUN,
    output oTP1, oTP2, oTP3, oTP4, oTS1, oTS2, oTS3, oTS4,
    output[11:00] oMADR, oMBUF, oACUM,

    output[11:00] mulq, pctr,
    output[2:0] memfield,
    output[3:0] majst,
    output[4:0] sctr,
    output swstart, swldad, swdepos, swexam,
    output swcont, swstop, swsstep, swsinst
);

    wire[11:09] ireg;
    wire intenabd, paused;
    wire[2:0] dfield, ifield;

    wire[11:00] swreg;
    wire[2:0] swdfld, swifld;

    wire[11:00] memINBUS;
    wire oEXEFET, oINTACK, oJMPJMS;
    wire[1:0] oFLDSEL;

    console coninst (
        .clok2 (clok2),
        .reset (reset),

        .gpin  (gpin),
        .gpout (gpout),

        .lbpctr (pctr),
        .lbmadr (oMADR),
        .lbmbuf (oMBUF),
        .lbacum (oACUM),
        .lbmulq (mulq),
        .lbireg (ireg),
        .lbmajst (majst),
        .lbion (intenabd),
        .lbpause (paused),
        .lbrun (oRUN),
        .lbsc (sctr),
        .lbdf (dfield),
        .lbif (ifield),
        .lblink (oLINK),

        .swreg (swreg),         //toggle switch register
        .swdfld (swdfld),       //toggle data field
        .swifld (swifld),       //toggle inst field
        .swstart (swstart),     //button start (debounced)
        .swldad (swldad),       //button load address
        .swdepos (swdepos),     //button deposit (debounced)
        .swexam (swexam),       //button examine (debounced)
        .swcont (swcont),       //button continue (debounced)
        .swstop (swstop),       //button stop
        .swsstep (swsstep),     //toggle single cycle
        .swsinst (swsinst)      //toggle single instruction
    );

    wire eaeACCLEAR, eaeHOLD, eaeIOSKIP, eaeLNKTOG;
    wire[11:00] eaeINBUS;

    extarith eaeinst (
        .clok2 (clok2),
        .reset (reset),

        .iACCLEAR (eaeACCLEAR),
        .iHOLD (eaeHOLD),
        .iIOSKIP (eaeIOSKIP),
        .iLNKTOG (eaeLNKTOG),
        .iINBUS (eaeINBUS),

        .iMEMBUS (memINBUS),
        .oLINK (oLINK),
        .oTP1 (oTP1),
        .oTP2 (oTP2),
        .oTP3 (oTP3),
        .oTP4 (oTP4),
        .oACUM (oACUM),
        .oMBUF (oMBUF),

        .lbMAJST (majst),

        .mulq (mulq),
        .sctr (sctr)
    );

    wire iINTINH;
    wire[11:00] mexINBUS;

    memext mexinst (
        .clok2 (clok2),
        .reset (reset),

        .businit (oBUSINI),
        .iop (oIOP),
        .ldaddrsw (swldad),
        .tp3 (oTP3),
        .tp4 (oTP4),
        .exefet (oEXEFET),
        .intack (oINTACK),
        .jmpjms (oJMPJMS),

        .dmafield (iDMAADDR[14:12]),
        .dfldsw (swdfld),
        .ifldsw (swifld),
        .fldsel (oFLDSEL),
        .acum (oACUM),
        .mbuf (oMBUF),

        .intinh (iINTINH),
        .field (memfield),
        .inbus (mexINBUS)
    );

    memory meminst (
        .clok2 (clok2),

        .ts1  (oTS1),
        .ts3  (oTS3),
        .xadr ({ memfield, oMADR }),
        .mbuf (oMBUF),
        .mbus (memINBUS)
    );

    wire readsr;
    wire acclear = iACCLEAR | eaeACCLEAR;
    wire hold = iHOLD | eaeHOLD;
    wire[11:00] inbus = iINBUS | eaeINBUS | memINBUS | mexINBUS | (readsr ? swreg : 12'b0);
    wire ioskip = iIOSKIP | eaeIOSKIP;
    wire lnktog = iLNKTOG | eaeLNKTOG;
    wire[3:0] nxtms;

    processor procboard (
          .ACCLEAR  (acclear)
        , .ACUM_0   (oACUM[00])
        , .ACUM_1   (oACUM[01])
        , .ACUM_10  (oACUM[10])
        , .ACUM_11  (oACUM[11])
        , .ACUM_2   (oACUM[02])
        , .ACUM_3   (oACUM[03])
        , .ACUM_4   (oACUM[04])
        , .ACUM_5   (oACUM[05])
        , .ACUM_6   (oACUM[06])
        , .ACUM_7   (oACUM[07])
        , .ACUM_8   (oACUM[08])
        , .ACUM_9   (oACUM[09])
        , .BRKRQST  (iBRKRQST)
        , .BRKWRM   (iBRKWRM)
        , .BUSINI   (oBUSINI)
        , .BWCOV    (oBWCOV)
        , .CAINC    (iCAINC)
        , .CLOK2    (clok2)
        , .CYCLE3   (i3CYCLE)
        , .DMADR_0  (iDMAADDR[00])
        , .DMADR_1  (iDMAADDR[01])
        , .DMADR_10 (iDMAADDR[10])
        , .DMADR_11 (iDMAADDR[11])
        , .DMADR_12 (iDMAADDR[12])
        , .DMADR_13 (iDMAADDR[13])
        , .DMADR_14 (iDMAADDR[14])
        , .DMADR_2  (iDMAADDR[02])
        , .DMADR_3  (iDMAADDR[03])
        , .DMADR_4  (iDMAADDR[04])
        , .DMADR_5  (iDMAADDR[05])
        , .DMADR_6  (iDMAADDR[06])
        , .DMADR_7  (iDMAADDR[07])
        , .DMADR_8  (iDMAADDR[08])
        , .DMADR_9  (iDMAADDR[09])
        , .EXEFET   (oEXEFET)
        , .GND      (1'b0)
        , .HOLD     (hold)
        , .INBUS_0  (inbus[00])
        , .INBUS_1  (inbus[01])
        , .INBUS_10 (inbus[10])
        , .INBUS_11 (inbus[11])
        , .INBUS_2  (inbus[02])
        , .INBUS_3  (inbus[03])
        , .INBUS_4  (inbus[04])
        , .INBUS_5  (inbus[05])
        , .INBUS_6  (inbus[06])
        , .INBUS_7  (inbus[07])
        , .INBUS_8  (inbus[08])
        , .INBUS_9  (inbus[09])
        , .INTINH   (iINTINH)
        , .INTRQST  (iINTRQST)
        , .IOSKIP   (ioskip)
        , .IREG_10  (ireg[10])
        , .IREG_11  (ireg[11])
        , .IREG_9   (ireg[09])
        , .LINK     (oLINK)
        , .LNKTOG   (lnktog)
        , .MADR_0   (oMADR[00])
        , .MADR_1   (oMADR[01])
        , .MADR_10  (oMADR[10])
        , .MADR_11  (oMADR[11])
        , .MADR_2   (oMADR[02])
        , .MADR_3   (oMADR[03])
        , .MADR_4   (oMADR[04])
        , .MADR_5   (oMADR[05])
        , .MADR_6   (oMADR[06])
        , .MADR_7   (oMADR[07])
        , .MADR_8   (oMADR[08])
        , .MADR_9   (oMADR[09])
        , .MBUF_0   (oMBUF[00])
        , .MBUF_1   (oMBUF[01])
        , .MBUF_10  (oMBUF[10])
        , .MBUF_11  (oMBUF[11])
        , .MBUF_2   (oMBUF[02])
        , .MBUF_3   (oMBUF[03])
        , .MBUF_4   (oMBUF[04])
        , .MBUF_5   (oMBUF[05])
        , .MBUF_6   (oMBUF[06])
        , .MBUF_7   (oMBUF[07])
        , .MBUF_8   (oMBUF[08])
        , .MBUF_9   (oMBUF[09])
        , .MQUO_0   ()
        , .MQUO_1   ()
        , .MQUO_10  ()
        , .MQUO_11  ()
        , .MQUO_2   ()
        , .MQUO_3   ()
        , .MQUO_4   ()
        , .MQUO_5   ()
        , .MQUO_6   ()
        , .MQUO_7   ()
        , .MQUO_8   ()
        , .MQUO_9   ()
        , .PCTR_0   (pctr[00])
        , .PCTR_1   (pctr[01])
        , .PCTR_10  (pctr[10])
        , .PCTR_11  (pctr[11])
        , .PCTR_2   (pctr[02])
        , .PCTR_3   (pctr[03])
        , .PCTR_4   (pctr[04])
        , .PCTR_5   (pctr[05])
        , .PCTR_6   (pctr[06])
        , .PCTR_7   (pctr[07])
        , .PCTR_8   (pctr[08])
        , .PCTR_9   (pctr[09])
        , .RESET    (reset)
        , .SCTR_0   ()
        , .SCTR_1   ()
        , .SCTR_2   ()
        , .SCTR_3   ()
        , .SCTR_4   ()
        , .VCC      (1'b1)
        , .swCONT   (swcont)
        , .swDEPOS  (swdepos)
        , .swEXAM   (swexam)
        , .swLDAD   (swldad)
        , .swSINST  (swsinst)
        , .swSSTEP  (swsstep)
        , .swSTART  (swstart)
        , .swSTOP   (swstop)

        , .FLDSEL_0 (oFLDSEL[0])
        , .FLDSEL_1 (oFLDSEL[1])
        , .IOP      (oIOP)
        , .MAJST_0  (majst[0])
        , .MAJST_1  (majst[1])
        , .MAJST_2  (majst[2])
        , .MAJST_3  (majst[3])
        , .NXTMS_0  (nxtms[0])
        , .NXTMS_1  (nxtms[1])
        , .NXTMS_2  (nxtms[2])
        , .NXTMS_3  (nxtms[3])
        , .NXTMSBRK ()
        , .NXTMSIAK ()
        , .RUN      (oRUN)
        , .TP1      (oTP1)
        , .TP2      (oTP2)
        , .TP3      (oTP3)
        , .TP4      (oTP4)
        , .TS1      (oTS1)
        , .TS2      (oTS2)
        , .TS3      (oTS3)
        , .TS4      (oTS4)
    );

    registers regsboard (
          .ACCLEAR  (acclear)
        , .BRKRQST  (iBRKRQST)
        , .BRKWRM   (iBRKWRM)
        , .BUSINI   (oBUSINI)
        , .BWCOV    (oBWCOV)
        , .CAINC    (iCAINC)
        , .CLOK2    (clok2)
        , .CYCLE3   (i3CYCLE)
        , .DMADR_0  (iDMAADDR[00])
        , .DMADR_1  (iDMAADDR[01])
        , .DMADR_10 (iDMAADDR[10])
        , .DMADR_11 (iDMAADDR[11])
        , .DMADR_12 (iDMAADDR[12])
        , .DMADR_13 (iDMAADDR[13])
        , .DMADR_14 (iDMAADDR[14])
        , .DMADR_2  (iDMAADDR[02])
        , .DMADR_3  (iDMAADDR[03])
        , .DMADR_4  (iDMAADDR[04])
        , .DMADR_5  (iDMAADDR[05])
        , .DMADR_6  (iDMAADDR[06])
        , .DMADR_7  (iDMAADDR[07])
        , .DMADR_8  (iDMAADDR[08])
        , .DMADR_9  (iDMAADDR[09])
        , .EXEFET   ()
        , .FLDSEL_0 (oFLDSEL[0])
        , .FLDSEL_1 (oFLDSEL[1])
        , .GND      (1'b0)
        , .HOLD     ()
        , .INBUS_0  (inbus[00])
        , .INBUS_1  (inbus[01])
        , .INBUS_10 (inbus[10])
        , .INBUS_11 (inbus[11])
        , .INBUS_2  (inbus[02])
        , .INBUS_3  (inbus[03])
        , .INBUS_4  (inbus[04])
        , .INBUS_5  (inbus[05])
        , .INBUS_6  (inbus[06])
        , .INBUS_7  (inbus[07])
        , .INBUS_8  (inbus[08])
        , .INBUS_9  (inbus[09])
        , .INTAK    ()
        , .INTINH   (iINTINH)
        , .INTRQST  (iINTRQST)
        , .IOP      (oIOP)
        , .IOSKIP   (ioskip)
        , .LNKTOG   (lnktog)
        , .MAJST_0  (majst[0])
        , .MAJST_1  (majst[1])
        , .MAJST_2  (majst[2])
        , .MAJST_3  (majst[3])
        , .NXTMS_0  (nxtms[0])
        , .NXTMS_1  (nxtms[1])
        , .NXTMS_2  (nxtms[2])
        , .NXTMS_3  (nxtms[3])
        , .MQUO_0   ()
        , .MQUO_1   ()
        , .MQUO_10  ()
        , .MQUO_11  ()
        , .MQUO_2   ()
        , .MQUO_3   ()
        , .MQUO_4   ()
        , .MQUO_5   ()
        , .MQUO_6   ()
        , .MQUO_7   ()
        , .MQUO_8   ()
        , .MQUO_9   ()
        , .NXTMSBRK (oBREAK)
        , .READSR   (readsr)
        , .RESET    (reset)
        , .RUN      (oRUN)
        , .SCTR_0   ()
        , .SCTR_1   ()
        , .SCTR_2   ()
        , .SCTR_3   ()
        , .SCTR_4   ()
        , .TP1      (oTP1)
        , .TP2      (oTP2)
        , .TP3      (oTP3)
        , .TP4      (oTP4)
        , .TS1      (oTS1)
        , .TS2      (oTS2)
        , .TS3      (oTS3)
        , .TS4      (oTS4)
        , .VCC      (1'b1)
        , .swCONT   (swcont)
        , .swDEPOS  (swdepos)
        , .swEXAM   (swexam)
        , .swLDAD   (swldad)
        , .swSINST  (swsinst)
        , .swSSTEP  (swsstep)
        , .swSTART  (swstart)
        , .swSTOP   (swstop)

        , .ACUM_0   (oACUM[00])
        , .ACUM_1   (oACUM[01])
        , .ACUM_10  (oACUM[10])
        , .ACUM_11  (oACUM[11])
        , .ACUM_2   (oACUM[02])
        , .ACUM_3   (oACUM[03])
        , .ACUM_4   (oACUM[04])
        , .ACUM_5   (oACUM[05])
        , .ACUM_6   (oACUM[06])
        , .ACUM_7   (oACUM[07])
        , .ACUM_8   (oACUM[08])
        , .ACUM_9   (oACUM[09])
        , .IREG_10  (ireg[10])
        , .IREG_11  (ireg[11])
        , .IREG_9   (ireg[09])
        , .LINK     (oLINK)
        , .MADR_0   (oMADR[00])
        , .MADR_1   (oMADR[01])
        , .MADR_10  (oMADR[10])
        , .MADR_11  (oMADR[11])
        , .MADR_2   (oMADR[02])
        , .MADR_3   (oMADR[03])
        , .MADR_4   (oMADR[04])
        , .MADR_5   (oMADR[05])
        , .MADR_6   (oMADR[06])
        , .MADR_7   (oMADR[07])
        , .MADR_8   (oMADR[08])
        , .MADR_9   (oMADR[09])
        , .MBUF_0   (oMBUF[00])
        , .MBUF_1   (oMBUF[01])
        , .MBUF_10  (oMBUF[10])
        , .MBUF_11  (oMBUF[11])
        , .MBUF_2   (oMBUF[02])
        , .MBUF_3   (oMBUF[03])
        , .MBUF_4   (oMBUF[04])
        , .MBUF_5   (oMBUF[05])
        , .MBUF_6   (oMBUF[06])
        , .MBUF_7   (oMBUF[07])
        , .MBUF_8   (oMBUF[08])
        , .MBUF_9   (oMBUF[09])
        , .PCTR_0   (pctr[00])
        , .PCTR_1   (pctr[01])
        , .PCTR_10  (pctr[10])
        , .PCTR_11  (pctr[11])
        , .PCTR_2   (pctr[02])
        , .PCTR_3   (pctr[03])
        , .PCTR_4   (pctr[04])
        , .PCTR_5   (pctr[05])
        , .PCTR_6   (pctr[06])
        , .PCTR_7   (pctr[07])
        , .PCTR_8   (pctr[08])
        , .PCTR_9   (pctr[09])
    );

endmodule
