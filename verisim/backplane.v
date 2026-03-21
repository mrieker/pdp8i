
module backplane (
    input zclock,
    input zreset,
    input clok2,                    // 10MHz clock
    input reset,                    // power-on reset

    input[15:04] gpin,              // switches from verimain.cc
    output[27:04] gpout,            // light bulbs to verimain.cc
                                    // - also has row selectors

    input i3CYCLE,                  // do 3-cycle break
    input iACCLEAR,                 // io pulse clears AC
    input iBRKRQST,                 // requesting break
    input iBRKWRM,                  // break cycle writes memory
    input iCAINC,                   // curad cycle increments address word
    input iINTRQST,                 // request interrupt
    input iIOSKIP,                  // increment PC at end of IO pulse
    input iLNKTOG,                  // toggle link register
    input[14:00] iDMAADDR,          // device sending address for DMA
    input[11:00] iINBUS,            // device sending data for PIO or DMA
    input iPAUSE,                   // pause processor clocking (stretch cycle)
    output oBREAK,                  // currently doing BREAK (DMA) cycle
    output oBUSINI,                 // initialize bus devices
    output oBWCOV,                  // 3-cycle DMA wordcount overflowed
    output oION,                    // interrupts enabled
    output oIOP,                    // io instruction pulse
    output oLINK,                   // link register
    output oRUN,
    output oTP1, oTP2, oTP3, oTP4, oTS1, oTS2, oTS3, oTS4,
    output[11:00] oMADR, oMBUF, oACUM,

    output[11:00] mulq, pctr,
    output[2:0] memfield,
    output[3:0] majst,
    output[4:0] sctr,
    output[11:00] swreg,
    output[2:0] swdfld, swifld,
    output swstart, swldad, swdepos, swexam,
    output swcont, swstop, swsstep, swsinst
);

    wire[11:09] ireg;
    wire[2:0] dfield, ifield;

    wire[11:00] memINBUS;
    wire oINTACK, oJMPJMS;

    wire[15:04] gpio = (gpout[18:16] == 7) ? 12'oZZZZ : gpin;
    assign gpout[15:04] = gpio[15:04];

    console coninst (
        .zclock (zclock),
        .zreset (zreset),
        .CLOK2 (clok2),
        .RESET (reset),

        .bGPIO_4   (gpio[04]),
        .bGPIO_5   (gpio[05]),
        .bGPIO_6   (gpio[06]),
        .bGPIO_7   (gpio[07]),
        .bGPIO_8   (gpio[08]),
        .bGPIO_9   (gpio[09]),
        .bGPIO_10  (gpio[10]),
        .bGPIO_11  (gpio[11]),
        .bGPIO_12  (gpio[12]),
        .bGPIO_13  (gpio[13]),
        .bGPIO_14  (gpio[14]),
        .bGPIO_15  (gpio[15]),
        .oGPOUT_16 (gpout[16]),
        .oGPOUT_17 (gpout[17]),
        .oGPOUT_18 (gpout[18]),
        .oGPOUT_20 (gpout[20]),
        .oGPOUT_21 (gpout[21]),
        .oGPOUT_22 (gpout[22]),
        .oGPOUT_23 (gpout[23]),
        .oGPOUT_24 (gpout[24]),
        .oGPOUT_25 (gpout[25]),
        .oGPOUT_26 (gpout[26]),
        .oGPOUT_27 (gpout[27]),

        .ACCLEAR (),
        .BRKRQST (),
        .BRKWRM  (),
        .BUSINI  (),
        .BWCOV   (),
        .CAINC   (),
        .CYCLE3  (),
        .DMADR_0  (),
        .DMADR_1  (),
        .DMADR_10 (),
        .DMADR_11 (),
        .DMADR_2  (),
        .DMADR_3  (),
        .DMADR_4  (),
        .DMADR_5  (),
        .DMADR_6  (),
        .DMADR_7  (),
        .DMADR_8  (),
        .DMADR_9  (),
        .DMADR_12 (),
        .DMADR_13 (),
        .DMADR_14 (),
        .FIELD_0 (),
        .FIELD_1 (),
        .FIELD_2 (),
        .GND     (1'b0),
        .INTINH  (),
        .INTRQST (),
        .IOP     (),
        .IOSKIP  (),
        .LNKTOG  (),

        .NXTMS_0 (nxtms[0]),
        .NXTMS_1 (nxtms[1]),
        .NXTMS_2 (nxtms[2]),
        .NXTMS_3 (nxtms[3]),
        .READSR  (readsr),
        .TP1     (oTP1),
        .TP2     (oTP2),
        .TP3     (oTP3),
        .TP4     (oTP4),
        .TS1     (oTS1),
        .TS2     (oTS2),
        .TS3     (oTS3),
        .TS4     (oTS4),
        .VCC     (1'b1)

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
        , .ACUM_0   (oACUM[0])
        , .ACUM_1   (oACUM[1])
        , .ACUM_2   (oACUM[2])
        , .ACUM_3   (oACUM[3])
        , .ACUM_4   (oACUM[4])
        , .ACUM_5   (oACUM[5])
        , .ACUM_6   (oACUM[6])
        , .ACUM_7   (oACUM[7])
        , .ACUM_8   (oACUM[8])
        , .ACUM_9   (oACUM[9])
        , .ACUM_10  (oACUM[10])
        , .ACUM_11  (oACUM[11])
        , .MQUO_0   (mulq[0])
        , .MQUO_1   (mulq[1])
        , .MQUO_2   (mulq[2])
        , .MQUO_3   (mulq[3])
        , .MQUO_4   (mulq[4])
        , .MQUO_5   (mulq[5])
        , .MQUO_6   (mulq[6])
        , .MQUO_7   (mulq[7])
        , .MQUO_8   (mulq[8])
        , .MQUO_9   (mulq[9])
        , .MQUO_10  (mulq[10])
        , .MQUO_11  (mulq[11])
        , .INBUS_0  (inbus[0])
        , .INBUS_1  (inbus[1])
        , .INBUS_2  (inbus[2])
        , .INBUS_3  (inbus[3])
        , .INBUS_4  (inbus[4])
        , .INBUS_5  (inbus[5])
        , .INBUS_6  (inbus[6])
        , .INBUS_7  (inbus[7])
        , .INBUS_8  (inbus[8])
        , .INBUS_9  (inbus[9])
        , .INBUS_10 (inbus[10])
        , .INBUS_11 (inbus[11])
        , .IREG_9   (ireg[9])
        , .IREG_10  (ireg[10])
        , .IREG_11  (ireg[11])
        , .MAJST_0  (majst[0])
        , .MAJST_1  (majst[1])
        , .MAJST_2  (majst[2])
        , .MAJST_3  (majst[3]),
        .ION (oION),
        .PAUSE (pause),
        .RUN (oRUN),
          .SCTR_0   (sctr[0])
        , .SCTR_1   (sctr[1])
        , .SCTR_2   (sctr[2])
        , .SCTR_3   (sctr[3])
        , .SCTR_4   (sctr[4])
        , .DFLD_0   (dfield[0])
        , .DFLD_1   (dfield[1])
        , .DFLD_2   (dfield[2])
        , .IFLD_0   (ifield[0])
        , .IFLD_1   (ifield[1])
        , .IFLD_2   (ifield[2]),
        .LINK (oLINK),

        .swDFLD_0 (swdfld[0]),  //toggle data field
        .swDFLD_1 (swdfld[1]),
        .swDFLD_2 (swdfld[2]),
        .swIFLD_0 (swifld[0]),  //toggle inst field
        .swIFLD_1 (swifld[1]),
        .swIFLD_2 (swifld[2]),
        .swSTART  (swstart),    //button start (debounced)
        .swLDAD   (swldad),     //button load address
        .swDEPOS  (swdepos),    //button deposit (debounced)
        .swEXAM   (swexam),     //button examine (debounced)
        .swCONT   (swcont),     //button continue (debounced)
        .swSTOP   (swstop),     //button stop
        .swSSTEP  (swsstep),    //toggle single cycle
        .swSINST  (swsinst)     //toggle single instruction
    );

    wire eaeACCLEAR, eaePAUSE, eaeIOSKIP, eaeLNKTOG;

    extarith eaeboard (
        .zclock (zclock),
        .zreset (zreset),
          .ACUM_0   (oACUM[0])
        , .ACUM_1   (oACUM[1])
        , .ACUM_2   (oACUM[2])
        , .ACUM_3   (oACUM[3])
        , .ACUM_4   (oACUM[4])
        , .ACUM_5   (oACUM[5])
        , .ACUM_6   (oACUM[6])
        , .ACUM_7   (oACUM[7])
        , .ACUM_8   (oACUM[8])
        , .ACUM_9   (oACUM[9])
        , .ACUM_10  (oACUM[10])
        , .ACUM_11  (oACUM[11])
        , .BRKRQST  ()
        , .BRKWRM   ()
        , .BUSINI   (oBUSINI)
        , .BWCOV    ()
        , .CAINC    ()
        , .CLOK2    (clok2)
        , .CYCLE3   ()
        , .DMADR_0  ()
        , .DMADR_1  ()
        , .DMADR_2  ()
        , .DMADR_3  ()
        , .DMADR_4  ()
        , .DMADR_5  ()
        , .DMADR_6  ()
        , .DMADR_7  ()
        , .DMADR_8  ()
        , .DMADR_9  ()
        , .DMADR_10 ()
        , .DMADR_11 ()
        , .DMADR_12 ()
        , .DMADR_13 ()
        , .DMADR_14 ()
        , .GND      (1'b0)
        , .INTINH   ()
        , .INTRQST  ()
        , .IOP      ()
        , .IREG_9   ()
        , .IREG_10  ()
        , .IREG_11  ()
        , .LINK     (oLINK)
        , .MADR_0   ()
        , .MADR_1   ()
        , .MADR_2   ()
        , .MADR_3   ()
        , .MADR_4   ()
        , .MADR_5   ()
        , .MADR_6   ()
        , .MADR_7   ()
        , .MADR_8   ()
        , .MADR_9   ()
        , .MADR_10  ()
        , .MADR_11  ()
        , .MAJST_0  (majst[0])
        , .MAJST_1  (majst[1])
        , .MAJST_2  (majst[2])
        , .MAJST_3  (majst[3])
        , .MBUF_0   (oMBUF[0])
        , .MBUF_1   (oMBUF[1])
        , .MBUF_2   (oMBUF[2])
        , .MBUF_3   (oMBUF[3])
        , .MBUF_4   (oMBUF[4])
        , .MBUF_5   (oMBUF[5])
        , .MBUF_6   (oMBUF[6])
        , .MBUF_7   (oMBUF[7])
        , .MBUF_8   (oMBUF[8])
        , .MBUF_9   (oMBUF[9])
        , .MBUF_10  (oMBUF[10])
        , .MBUF_11  (oMBUF[11])
        , .NXTMS_0  ()
        , .NXTMS_1  ()
        , .NXTMS_2  ()
        , .NXTMS_3  ()
        , .PCTR_0   ()
        , .PCTR_1   ()
        , .PCTR_2   ()
        , .PCTR_3   ()
        , .PCTR_4   ()
        , .PCTR_5   ()
        , .PCTR_6   ()
        , .PCTR_7   ()
        , .PCTR_8   ()
        , .PCTR_9   ()
        , .PCTR_10  ()
        , .PCTR_11  ()
        , .READSR   ()
        , .RESET    ()
        , .RUN      ()
        , .TP1      (oTP1)
        , .TP2      (oTP2)
        , .TP3      (oTP3)
        , .TP4      (oTP4)
        , .TS1      (oTS1)
        , .TS2      (oTS2)
        , .TS3      (oTS3)
        , .TS4      (oTS4)
        , .VCC      (1'b1)
        , .swCONT   ()
        , .swDEPOS  ()
        , .swEXAM   ()
        , .swLDAD   ()
        , .swSINST  ()
        , .swSSTEP  ()
        , .swSTART  ()
        , .swSTOP   ()

        , .ACCLEAR  (eaeACCLEAR)
        , .INBUS_0  (inbus[0])
        , .INBUS_1  (inbus[1])
        , .INBUS_2  (inbus[2])
        , .INBUS_3  (inbus[3])
        , .INBUS_4  (inbus[4])
        , .INBUS_5  (inbus[5])
        , .INBUS_6  (inbus[6])
        , .INBUS_7  (inbus[7])
        , .INBUS_8  (inbus[8])
        , .INBUS_9  (inbus[9])
        , .INBUS_10 (inbus[10])
        , .INBUS_11 (inbus[11])
        , .IOSKIP   (eaeIOSKIP)
        , .LNKTOG   (eaeLNKTOG)

        , .MQUO_0   (mulq[0])
        , .MQUO_1   (mulq[1])
        , .MQUO_2   (mulq[2])
        , .MQUO_3   (mulq[3])
        , .MQUO_4   (mulq[4])
        , .MQUO_5   (mulq[5])
        , .MQUO_6   (mulq[6])
        , .MQUO_7   (mulq[7])
        , .MQUO_8   (mulq[8])
        , .MQUO_9   (mulq[9])
        , .MQUO_10  (mulq[10])
        , .MQUO_11  (mulq[11])
        , .PAUSE    (eaePAUSE)
        , .SCTR_0   (sctr[0])
        , .SCTR_1   (sctr[1])
        , .SCTR_2   (sctr[2])
        , .SCTR_3   (sctr[3])
        , .SCTR_4   (sctr[4])
    );

    wire iINTINH;
    wire[11:00] mexINBUS;

    extmemory meminst (
        .zclock (zclock),
        .zreset (zreset),
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
        , .DFLD_0   (dfield[0])
        , .DFLD_1   (dfield[1])
        , .DFLD_2   (dfield[2])
        , .DMADR_0  (swldad ? swdfld[0] : iDMAADDR[00])
        , .DMADR_1  (swldad ? swdfld[1] : iDMAADDR[01])
        , .DMADR_2  (swldad ? swdfld[2] : iDMAADDR[02])
        , .DMADR_3  (swldad ? swifld[0] : iDMAADDR[03])
        , .DMADR_4  (swldad ? swifld[1] : iDMAADDR[04])
        , .DMADR_5  (swldad ? swifld[2] : iDMAADDR[05])
        , .DMADR_6  (iDMAADDR[06])
        , .DMADR_7  (iDMAADDR[07])
        , .DMADR_8  (iDMAADDR[08])
        , .DMADR_9  (iDMAADDR[09])
        , .DMADR_10 (iDMAADDR[10])
        , .DMADR_11 (iDMAADDR[11])
        , .DMADR_12 (iDMAADDR[12])
        , .DMADR_13 (iDMAADDR[13])
        , .DMADR_14 (iDMAADDR[14])
        , .FIELD_0  (memfield[0])
        , .FIELD_1  (memfield[1])
        , .FIELD_2  (memfield[2])
        , .GND      (1'b0)
        , .IFLD_0   (ifield[0])
        , .IFLD_1   (ifield[1])
        , .IFLD_2   (ifield[2])
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
        , .PAUSE    (pause)
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
        , .READSR   (readsr)
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

        , .IOP      (oIOP)
        , .MAJST_0  (majst[0])
        , .MAJST_1  (majst[1])
        , .MAJST_2  (majst[2])
        , .MAJST_3  (majst[3])
        , .NXTMS_0  (nxtms[0])
        , .NXTMS_1  (nxtms[1])
        , .NXTMS_2  (nxtms[2])
        , .NXTMS_3  (nxtms[3])
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

    wire readsr;
    wire acclear = iACCLEAR | eaeACCLEAR;
    wire pause = iPAUSE | eaePAUSE;
    wire[11:00] inbus = iINBUS | memINBUS | mexINBUS | (readsr ? swreg : 12'b0);
    wire ioskip = iIOSKIP | eaeIOSKIP;
    wire lnktog = iLNKTOG | eaeLNKTOG;
    wire[3:0] nxtms;

    processor procboard (
        .zclock (zclock),
        .zreset (zreset),
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
        , .GND      (1'b0)
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
        , .PAUSE    (pause)
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
        , .READSR   (readsr)
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

        , .ION      (oION)
        , .IOP      (oIOP)
        , .MAJST_0  (majst[0])
        , .MAJST_1  (majst[1])
        , .MAJST_2  (majst[2])
        , .MAJST_3  (majst[3])
        , .NXTMS_0  (nxtms[0])
        , .NXTMS_1  (nxtms[1])
        , .NXTMS_2  (nxtms[2])
        , .NXTMS_3  (nxtms[3])
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

endmodule
