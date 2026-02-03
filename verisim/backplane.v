
module backplane (
    input zclock,       // fpga 100MHz clock
    input zreset,       // fpga reset

    input[27:04] gpin,  // gpio connector
    output[27:04] gpout
);

    wire[11:00] pctr, madr, mbuf, acum, mquo;
    wire[11:09] ireg;
    wire[3:0] majst;
    wire intenabd, link, paused, running;
    wire[4:0] shcnt;
    wire[2:0] dfield, ifield;

    wire[11:00] swreg;
    wire[2:0] swdfld, swifld;
    wire swstart, swldad, swdep, swexam;
    wire swcont, swstop, swsstep, swsinst;

    wire[11:00] membus;

    wire oBREAK, oBWCOV, oINTACK, oIOP1, oIOP2, oIOP4, oJMPJMS;
    wire oTP1, oTP2, oTP3, oTP4, oTS1, oTS2, oTS3, oTS4;
    wire[1:0] oFLDSEL;

    console coninst (
        .zclock (zclock),
        .zreset (zreset),

        .gpin  (gpin),
        .gpout (gpout),

        .lbpctr (pctr),
        .lbmadr (madr),
        .lbmbuf (mbuf),
        .lbacum (acum),
        .lbmquo (mquo),
        .lbireg (ireg),
        .lbmajst (majst),
        .lbion (intenabd),
        .lbpause (paused),
        .lbrun (running),
        .lbsc (shcnt),
        .lbdf (dfield),
        .lbif (ifield),
        .lblink (link),

        .swreg (swreg),
        .swdfld (swdfld),
        .swifld (swifld),
        .swstart (swstart),
        .swldad (swldad),
        .swdep (swdep),
        .swexam (swexam),
        .swcont (swcont),
        .swstop (swstop),
        .swsstep (swsstep),
        .swsinst (swsinst)
    );

    memory meminst (
        .zclock (zclock),
        .zreset (zreset),

        .ts1  (oTS1),
        .ts3  (oTS3),
        .xadr ({ 3'b0, madr }),
        .mbuf (mbuf),
        .mbus (membus)
    );

    processor procinst (
        .zclock (zclock),
        .zreset (zreset),

        // bus signals
        .i3CYCLE (0),           // do 3-cycle break
        .iACCLEAR (0),          // io pulse clears AC
        .iBRKRQST (0),          // requesting break
        .iBRKWRM (0),           // break cycle writes memory
        .iCAINC (0),            // curad cycle increments address word
        .iHOLD (0),             // hold internal clocking (stretch cycle)
        .iINTINHIB (0),         // inhibit interrupt processing
        .iINTRQST (0),          // request interrupt
        .iIOSKIP (0),           // increment PC at end of IO pulse
        .iDMAADDR (0),          // break cycle address
        .iDMADATA (0),          // break cycle write data
        .iINBUS (0),            // IO data being read from device
        .iMEMBUS (membus),      // data being read from memory
        .oBREAK (oBREAK),       // doing BREAK cycle
        .oBWCOV (oBWCOV),       // break wordcount overflowed
        .oINTACK (oINTACK),     // doing INTACK cycle
        .oIOP1 (oIOP1),         // IO pulses
        .oIOP2 (oIOP2),         // ...400nS each
        .oIOP4 (oIOP4),         // ...300nS spacing
        .oJMPJMS (oJMPJMS),     // JMP/JMS instruction in instruction register
        .oRUN (running),        // processing instructions
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
        .oACUM (acum),          // IO data being written to device
        .oMADR (madr),          // memory address being accessed
        .oMBUF (mbuf),          // data being written to memory

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
        .swDEP (swdep),         // button (debounced)
        .swCONT (swcont),       // button (debounced)
        .swSTOP (swstop),       // button (idempotent)
        .swSTART (swstart),     // button (debounced)
        .swSINST (swsinst),     // toggle
        .swSSTEP (swsstep),     // toggle
        .swREG (swreg)          // toggle
    );

endmodule
