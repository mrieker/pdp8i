
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
    input[11:00] iDMADATA,          // device sending write data for DMA
    input[11:00] iINBUS,            // device sending data for PIO
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
    output[4:0] sctr
);

    wire[11:09] ireg;
    wire intenabd, paused;
    wire[2:0] dfield, ifield;

    wire[11:00] swreg;
    wire[2:0] swdfld, swifld;
    wire swstart, swldad, swdepos, swexam;
    wire swcont, swstop, swsstep, swsinst;

    wire[11:00] membus;
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

        .iMEMBUS (membus),
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
        .mbus (membus)
    );

    processor procinst (
        .clok2 (clok2),
        .reset (reset),

        // bus signals
        .i3CYCLE (i3CYCLE),
        .iACCLEAR (iACCLEAR | eaeACCLEAR),
        .iBRKRQST (iBRKRQST),
        .iBRKWRM (iBRKWRM),
        .iCAINC (iCAINC),
        .iHOLD (iHOLD | eaeHOLD),
        .iINTINH (iINTINH),
        .iINTRQST (iINTRQST),
        .iIOSKIP (iIOSKIP | eaeIOSKIP),
        .iDMAADDR (iDMAADDR[11:00]),
        .iDMADATA (iDMADATA),
        .iINBUS (iINBUS | eaeINBUS | mexINBUS),
        .iLNKTOG (iLNKTOG | eaeLNKTOG),
        .iMEMBUS (membus),

        .oBREAK (oBREAK),
        .oBUSINI (oBUSINI),
        .oBWCOV (oBWCOV),
        .oEXEFET (oEXEFET),
        .oINTACK (oINTACK),
        .oIOP (oIOP),
        .oJMPJMS (oJMPJMS),
        .oLINK (oLINK),
        .oRUN (oRUN),
        .oTP1 (oTP1),
        .oTP2 (oTP2),
        .oTP3 (oTP3),
        .oTP4 (oTP4),
        .oTS1 (oTS1),
        .oTS2 (oTS2),
        .oTS3 (oTS3),
        .oTS4 (oTS4),
        .oFLDSEL (oFLDSEL),
        .oACUM (oACUM),
        .oMADR (oMADR),
        .oMBUF (oMBUF),

        // lights
        .lbPCTR (pctr),
        .lbIREG (ireg),
        .lbMAJST (majst),
        .lbION (intenabd),
        .lbPAUSE (paused),

        // switches
        .swLDAD (swldad),       // button (idempotent)
        .swEXAM (swexam),       // button (debounced)
        .swDEPOS (swdepos),     // button (debounced)
        .swCONT (swcont),       // button (debounced)
        .swSTOP (swstop),       // button (idempotent)
        .swSTART (swstart),     // button (debounced)
        .swSINST (swsinst),     // toggle
        .swSSTEP (swsstep),     // toggle
        .swREG (swreg)          // toggle
    );

endmodule
