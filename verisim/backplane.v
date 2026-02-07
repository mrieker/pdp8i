
module backplane (
    input zclock,                   // fpga 100MHz clock
    input zreset,                   // fpga reset

    input preset,                   // power-on reset

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
    input[14:00] iDMAADDR,          // device sending address for DMA
    input[11:00] iDMADATA,          // device sending write data for DMA
    input[11:00] iINBUS,            // device sending data for PIO
    output oBREAK,                  // currently doing BREAK (DMA) cycle
    output oBUSINI,                 // initialize bus devices
    output oBWCOV,                  // 3-cycle DMA wordcount overflowed
    output oIOP1, oIOP2, oIOP4,     // io instruction pulses
    output oRUN,
    output oTP1, oTP2, oTP3, oTP4, oTS1, oTS2, oTS3, oTS4,
    output[11:00] oMADR, oMBUF, oACUM,

    output[11:00] pctr,
    output[2:0] memfield,
    output[3:0] majst,
    output link
);

    wire[11:00] mquo;
    wire[11:09] ireg;
    wire intenabd, paused;
    wire[4:0] shcnt;
    wire[2:0] dfield, ifield;

    wire[11:00] swreg;
    wire[2:0] swdfld, swifld;
    wire swstart, swldad, swdepos, swexam;
    wire swcont, swstop, swsstep, swsinst;

    wire[11:00] membus;
    wire oEXEFET, oINTACK, oJMPJMS;
    wire[1:0] oFLDSEL;

    console coninst (
        .zclock (zclock),
        .zreset (zreset),

        .preset (preset),

        .gpin  (gpin),
        .gpout (gpout),

        .lbpctr (pctr),
        .lbmadr (oMADR),
        .lbmbuf (oMBUF),
        .lbacum (oACUM),
        .lbmquo (mquo),
        .lbireg (ireg),
        .lbmajst (majst),
        .lbion (intenabd),
        .lbpause (paused),
        .lbrun (oRUN),
        .lbsc (shcnt),
        .lbdf (dfield),
        .lbif (ifield),
        .lblink (link),

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

    wire iINTINH;
    wire[11:00] mexinbus;

    memext mexinst (
        .zclock (zclock),
        .zreset (zreset),

        .preset (preset),
        .businit (oBUSINI),
        .iop1 (oIOP1),
        .iop2 (oIOP2),
        .iop4 (oIOP4),
        .ldaddrsw (swldad),
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
        .inbus (mexinbus)
    );

    memory meminst (
        .zclock (zclock),
        .zreset (zreset),

        .ts1  (oTS1),
        .ts3  (oTS3),
        .xadr ({ memfield, oMADR }),
        .mbuf (oMBUF),
        .mbus (membus)
    );

    processor procinst (
        .zclock (zclock),
        .zreset (zreset),

        .preset (preset),

        // bus signals
        .i3CYCLE (i3CYCLE),     // do 3-cycle break
        .iACCLEAR (iACCLEAR),   // io pulse clears AC
        .iBRKRQST (iBRKRQST),   // requesting break
        .iBRKWRM (iBRKWRM),     // break cycle writes memory
        .iCAINC (iCAINC),       // curad cycle increments address word
        .iHOLD (iHOLD),         // hold internal clocking (stretch cycle)
        .iINTINH (iINTINH),     // inhibit interrupt processing
        .iINTRQST (iINTRQST),   // request interrupt
        .iIOSKIP (iIOSKIP),     // increment PC at end of IO pulse
        .iDMAADDR (iDMAADDR[11:00]),  // break cycle address
        .iDMADATA (iDMADATA),   // break cycle write data
        .iINBUS (iINBUS | mexinbus),  // IO data being read from device
        .iMEMBUS (membus),      // data being read from memory
        .oBREAK (oBREAK),       // doing BREAK cycle
        .oBUSINI (oBUSINI),     // initialize bus devices
        .oBWCOV (oBWCOV),       // break wordcount overflowed
        .oEXEFET (oEXEFET),     // doing EXEC or FETCH cycle
        .oINTACK (oINTACK),     // doing INTACK cycle
        .oIOP1 (oIOP1),         // IO pulses
        .oIOP2 (oIOP2),         // ...400nS each
        .oIOP4 (oIOP4),         // ...300nS spacing
        .oJMPJMS (oJMPJMS),     // JMP/JMS instruction in instruction register
        .oRUN (oRUN),           // processing instructions
        .oTP1 (oTP1),           // time pulses, 200nS each
        .oTP2 (oTP2),           // ...starting so as to overlap last 100nS of corresponding TSn
        .oTP3 (oTP3),           // ...usually overlapping first 100nS of subsequent TS(n+1)
        .oTP4 (oTP4),
        .oTS1 (oTS1),           // time states
        .oTS2 (oTS2),           // ...400nS each
        .oTS3 (oTS3),           // ...no spacing
                                // ...except when IO pulses wedged in here
        .oTS4 (oTS4),
        .oFLDSEL (oFLDSEL),     // field select (0=inst; 1=data; 2=zero; 3=break)
        .oACUM (oACUM),         // IO data being written to device
        .oMADR (oMADR),         // memory address being accessed
        .oMBUF (oMBUF),         // data being written to memory

        // lights
        .lbPCTR (pctr),
        .lbIREG (ireg),
        .lbMAJST (majst),
        .lbION (intenabd),
        .lbPAUSE (paused),
        .lbLINK (link),

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
