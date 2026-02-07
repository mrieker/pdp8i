
module processor (
    input zclock,               // fpga 100MHz clock
    input zreset,               // fpga reset

    // bus signals
    input i3CYCLE,              // do 3-cycle break
    input iACCLEAR,             // io pulse clears AC
    input iBRKRQST,             // requesting break
    input iBRKWRM,              // break cycle writes memory
    input iCAINC,               // curad cycle increments address word
    input iHOLD,                // hold internal clocking (stretch cycle)
    input iINTINH,              // inhibit interrupt processing
    input iINTRQST,             // request interrupt
    input iIOSKIP,              // increment PC at end of IO pulse
    input[11:00] iDMAADDR,      // break cycle address
    input[11:00] iDMADATA,      // break cycle write data
    input[11:00] iINBUS,        // IO data being read from device
    input[11:00] iMEMBUS,       // data being read from memory
    output oBREAK,              // doing BREAK cycle
    output reg oBWCOV,          // break wordcount overflowed
    output oEXEFET,             // about to do EXEC or FETCH cycle
    output oINTACK,             // about to do INTACK cycle
    output oIOP1,               // IO pulses
    output oIOP2,               // ...400nS each
    output oIOP4,               // ...300nS spacing
    output oJMPJMS,             // JMP/JMS instruction in instruction register
    output oRUN,                // processing instructions
    output oTP1,                // time pulses, 200nS each
    output oTP2,                // ...starting so as to overlap last 100nS of corresponding TSn
    output oTP3,                // ...usually overlapping first 100nS of subsequent TS(n+1)
    output oTP4,
    output oTS1,                // time states
    output oTS2,                // ...400nS each
    output oTS3,                // ...no spacing
                                // ...except when IO pulses wedged in here
    output oTS4,
    output reg[1:0] oFLDSEL,    // field select (0=inst; 1=data; 2=zero; 3=break)
    output[11:00] oACUM,        // IO data being written to device
    output[11:00] oMADR,        // memory address being accessed
    output[11:00] oMBUF,        // data being written to memory

    // lights
    output[11:00] lbPCTR,
    output[11:09] lbIREG,
    output[3:0] lbMAJST,
    output lbION,
    output lbPAUSE,
    output lbLINK,

    // switches
    input swLDAD,               // button (idempotent)
    input swEXAM,               // button (debounced)
    input swDEP,                // button (debounced)
    input swCONT,               // button (debounced)
    input swSTOP,               // button (idempotent)
    input swSTART,              // button (debounced)
    input swSINST,              // toggle
    input swSSTEP,              // toggle
    input[11:00] swREG          // toggle
);

    localparam[1:0] FS_INST  = 0;
    localparam[1:0] FS_DATA  = 1;
    localparam[1:0] FS_ZERO  = 2;
    localparam[1:0] FS_BREAK = 3;

    localparam[3:0] MS_FETCH = 1;   // memory cycle is fetching instruction
    localparam[3:0] MS_DEFER = 2;   // memory cycle is reading pointer
    localparam[3:0] MS_EXEC  = 3;   // memory cycle is for executing instruction
    localparam[3:0] MS_WRDCT = 4;   // memory cycle is for incrementing dma word count
    localparam[3:0] MS_CURAD = 5;   // memory cycle is for reading dma address
    localparam[3:0] MS_BREAK = 6;   // memory cycle is for dma data word transfer
    localparam[3:0] MS_INTAK = 7;   // memory cycle is for interrupt acknowledge
    localparam[3:0] MS_DEPOS = 8;   // memory cycle is for deposit switch
    localparam[3:0] MS_EXAM  = 9;   // memory cycle is for examine switch

    reg[11:00] acum, madr, mbuf, pctr;
    reg[11:09] ireg;
    reg[3:0] majstate, nxtmajst;
    reg intdelayed, intenabled, link;
    reg lastswcont, lastswdep, lastswexam, lastswldad, lastswstart;

    ///////////////////
    //  TIME STATES  //
    ///////////////////

    reg[3:0] zdiv;
    reg[1:0] tsct;
    reg hgnt, ts1, ts2, ts3, iop1, iop2, iop4, ts4;
    reg tp1, tp2, tp3, iog1, iog2, iog4, ioge, tp4;
    reg hreq;
    wire ioinst = (ireg[11:09] == 6) & (majstate == MS_FETCH);

    wire newhgnt = (ts4 | hgnt) & hreq;

    always @(posedge zclock) begin
        if (zreset) begin
            hgnt <= 1;
            hreq <= 1;
            tsct <= 0;
            zdiv <= 0;
        end else begin
            if (zdiv != 9) begin
                zdiv <= zdiv + 1;
            end else begin
                zdiv <= 0;

                // runs every 100nS

                // IOG1,2,4,E get 300nS
                // all others get 400nS
                if (tsct[1] & (tsct[0] | iog1 | iog2 | iog4 | ioge)) begin
                    tsct <= 0;
                    hgnt <= newhgnt;                // if end of TS4 or already halted and halt requested, halt
                    ts1  <= (ts4 | hgnt) & ~ hreq;  // if end of TS4 or halted and halt not requested, start TS1
                    ts2  <= ts1;                    // start TS2 at end of TS1
                    ts3  <= ts2;                    // start TS3 at end of TS2
                    iog1 <= ts3 &   ioinst;         // start IOG1 at end of TS3 with ioinst (gap bewteen TS3 and IOP1)
                    iop1 <= iog1;                   // start IOP1 at end of IOG1
                    iog2 <= iop1;                   // start IOG2 at end of IOP1 (gap between IOP1 and IOP2)
                    iop2 <= iog2;                   // start IOP2 at end of IOG2
                    iog4 <= iop2;                   // start IOG4 at end of IOP2 (gap between IOP2 and IOP4)
                    iop4 <= iog4;                   // start IOP4 at end of IOG4
                    ioge <= iop4;                   // start IOGE at end of IOP4 (gap between IOP4 and TS4)
                    ts4  <= ts3 & ~ ioinst | ioge;  // start TS4 at end of IOGE or end of TS3 with no ioinst
                end else begin
                    tsct <= tsct + 1;
                end

                // TPn start in last 100nS of corresponding TSn and continue for 200nS
                tp1 <= ts1 & tsct[1];
                tp2 <= ts2 & tsct[1];
                tp3 <= ts3 & tsct[1];
                tp4 <= ts4 & tsct[1];
            end
        end
    end

    ///////////////////
    //  BUS SIGNALS  //
    ///////////////////

    assign oIOP1 = iop1 & mbuf[00];
    assign oIOP2 = iop2 & mbuf[01];
    assign oIOP4 = iop4 & mbuf[02];

    /////////////////////////////////
    //  INTERMEDIATE COMPUTATIONS  //
    /////////////////////////////////

    // calculate effective address for memory reference instructions
    // valid in fetch cycle after ts2
    wire[11:00] effaddr = { (mbuf[07] ? madr[11:07] : 5'b0), mbuf[06:00] };

    // calculate accumulator and link for tad instruction
    wire[11:00] tadacum;
    wire tadlink;
    assign { tadlink, tadacum } = { link, acum } + { 1'b0, mbuf };

    // calculate accumulator and link for group 1 instruction
    reg[11:00] g1acum, g1acumraw;
    reg g1link, g1linkraw;

    always @(*) begin
        // handle cla, cll, cma, cll, iac bits
        { g1linkraw, g1acumraw } = { (mbuf[06] ? 1'b0 : link) ^ mbuf[04], (mbuf[07] ? 12'b0 : acum) ^ (mbuf[05] ? 12'o7777 : 12'o0000) } + { 12'b0, mbuf[00] };
        // handle rotate bits
        case (mbuf[03:01])
            2: { g1link, g1acum } = { g1acumraw, g1linkraw };                           // rol 1
            3: { g1link, g1acum } = { g1acumraw[10:00], g1linkraw, g1acumraw[11] };     // rol 2
            4: { g1link, g1acum } = { g1acumraw[00], g1linkraw, g1acumraw[11:01] };     // ror 1
            5: { g1link, g1acum } = { g1acumraw[01:00], g1linkraw, g1acumraw[11:02] };  // ror 2
            default: { g1link, g1acum } = { g1linkraw, g1acumraw };                     // all else, nop
        endcase
    end

    // calculate skip condition for group 2 instruction
    wire g2skip = ((mbuf[06] & acum[11]) |    // SMA
                   (mbuf[05] & (acum == 0)) | // SZA
                   (mbuf[04] & link)) ^       // SNL
                    mbuf[03];                 // reverse

    // calculate accumulator for group 2 instruction
    wire[11:00] g2acum = (mbuf[07] ? 12'd0 : acum) | (mbuf[02] ? swREG : 12'd0);

    // major state following last cycle of current instruction
    // this is used at posedge TP3, before any possible IOPs of current instruction
    wire[3:0] brkintfet =

        // if there is a dma request pending, start doing the dma
        iBRKRQST ? (i3CYCLE ? MS_WRDCT : MS_BREAK) :

        // if interrupt requested, interrupts are enabled via 6001 (ION),
        // and they aren't inhibited via 62x2/62x3 (CIF), next is int ack
        (iINTRQST &                                                     // some device is requesting an interrupt
                    intenabled &                                        // 6001 was executed at least one instruction ago
                    ~ ((ireg == 6) & (mbuf[08:00] == 9'o002)) &         // not blocked by current 6002 (IOF) instruction
                    (~ iINTINH | oJMPJMS) &                             // not blocked by prior 62x2/62x3 until jump or currently jumping
                    ~ ((ireg == 6) & ((mbuf[08:00] & 9'o706) == 9'o202))) ? // not blocked by 62x2/62x3 currently executing
            MS_INTAK :

        // otherwise, fetch next instruction
        MS_FETCH;

    ////////////////////
    //  MAJOR STATES  //
    ////////////////////

    reg lasthgnt, lastts1, lastts2, lastts3, lastiop1, lastiop2, lastiop4, lastts4;
    reg lasttp1, lasttp2, lasttp3, lastiog1, lastiog2, lastiog4, lastioge, lasttp4;

    always @(posedge zclock) begin
        if (zreset) begin
            majstate <= MS_EXAM;
            nxtmajst <= MS_EXAM;
        end else begin

            ///////////////////////////////////////////
            //  if halted, process console switches  //
            ///////////////////////////////////////////

            if (hgnt) begin

                // if freshly halted, registers (mbuf, majstare, etc) will be set for next cycle
                // ...so pressing swCONT will pick up where it left off
                // doing an intervening ldad/exam/dep will wipe that state
                // ...so pressing swCONT in that case assumes FETCH should be next

                // generally, registers are set when switch is pressed
                //  then TS1 is started when switch is released

                // only swCONT, swDEP, swEXAM, swSTART are debounced
                // the other functions are idempotent so don't need debouncing

                // load address - get address from switches then read memory location
                if (~ lastswldad & swLDAD) begin
                    madr     <= swREG;
                    oFLDSEL  <= FS_INST;
                    majstate <= MS_EXAM;
                end
                // start a memory cycle
                // processor will halt with majstate still set to MS_EXAM
                if (lastswldad & ~ swLDAD) begin
                    hreq <= 0;
                end

                // examine - read next location
                if (~ lastswexam & swEXAM) begin
                    if (majstate == MS_EXAM) madr <= madr + 1;
                    oFLDSEL  <= FS_INST;
                    majstate <= MS_EXAM;
                end
                // start a memory cycle
                // processor will halt with majstate still set to MS_EXAM
                if (lastswexam & ~ swEXAM) begin
                    hreq <= 0;
                end

                // deposit - write next location
                if (~ lastswdep & swDEP) begin
                    if (majstate == MS_DEPOS) madr <= madr + 1;
                    oFLDSEL  <= FS_INST;
                    majstate <= MS_DEPOS;
                end
                // start a memory cycle
                // processor will halt with majstate still set to MS_DEPOS
                if (lastswdep & ~ swDEP) begin
                    hreq <= 0;
                end

                // continue - resume execution where left off
                // if did ldad/exam/depos since halt, assume fetch is next
                if (~ lastswcont & swCONT) begin
                    if ((majstate == MS_EXAM) || (majstate == MS_DEPOS)) begin
                        oFLDSEL  <= FS_INST;
                        majstate <= MS_FETCH;
                    end
                end
                // start a memory cycle
                // processor will keep going until halted again
                if (lastswcont & ~ swCONT) begin
                    hreq <= 0;
                end

                // start - begin execution at current address
                // external circuit (backplane) is asserting businit while switch is pressed
                if (~ lastswstart & swSTART) begin
                    oFLDSEL  <= FS_INST;
                    majstate <= MS_FETCH;
                end
                // start a memory cycle
                // processor will keep going until halted again
                if (lastswstart & ~ swSTART) begin
                    hreq <= 0;
                end
            end

            ///////////////////////////////////////////////////
            //  TS1: read memory from address EA,MA into MB  //
            ///////////////////////////////////////////////////

            // memory starts reading location at beginning of TS1
            // TP1 happens 300nS later

            // clock in memory data on posedge TP1
            if (~ lasttp1 & tp1) begin
                mbuf <= iMEMBUS;
            end

            ///////////////////////////////////////////////
            //  TS2: modify MB according to major state  //
            ///////////////////////////////////////////////

            // give the increments and whatnot from posedge TS2 to
            // posedge TP3 (300nS) to soak through circuits

            if (~ lasttp2 & tp2) begin
                case (majstate)
                    MS_FETCH: begin
                        intenabled <= intdelayed;
                        ireg       <= mbuf[11:09];
                        pctr       <= madr + 1;
                    end
                    MS_DEFER: if (madr[11:03] == 1) mbuf <= mbuf + 1;
                    MS_EXEC, MS_INTAK: case (ireg)
                        2: mbuf <= mbuf + 1;    // isz
                        3: mbuf <= acum;        // dca
                        4: mbuf <= pctr;        // jms
                    endcase
                    MS_WRDCT: begin
                        // middle of wc with count just read, detect count overflow
                        oBWCOV <= (mbuf == 12'o7777);
                        mbuf <= mbuf + 1;
                    end
                    MS_CURAD: if (iCAINC) begin
                        mbuf <= mbuf + 1;
                    end
                    MS_BREAK: if (iBRKWRM) begin
                        // data must be ready in time for TS3 so it can be written to memory
                        mbuf <= iDMADATA;
                    end
                    MS_DEPOS: begin
                        mbuf <= swREG;
                    end
                    default: begin end
                endcase
            end

            /////////////////////////////////////////////
            //  TS3: write MB back to memory location  //
            /////////////////////////////////////////////

            if (~ lasttp3 & tp3) begin

                case (majstate)

                    // end of FETCH cycle
                    MS_FETCH: begin
                        case (ireg)

                            // add, tad, isz, dca, jms
                            0, 1, 2, 3, 4: nxtmajst <= mbuf[08] ? MS_DEFER : MS_EXEC;

                            // jmp
                            5: begin
                                if (~ mbuf[08]) pctr <= effaddr;
                                nxtmajst <= mbuf[08] ? MS_DEFER : brkintfet;
                            end

                            // iot
                            6: nxtmajst <= brkintfet;

                            // opr - perform operation
                            7: begin
                                if (~ mbuf[08]) begin
                                    acum <= g1acum;
                                    link <= g1link;
                                end else if (~ mbuf[00]) begin
                                    acum <= g2acum;
                                    if (g2skip) pctr <= pctr + 1;
                                    if (mbuf[01]) hreq <= 1;
                                end
                                nxtmajst <= brkintfet;
                            end
                        endcase
                    end

                    // end of DEFER cycle
                    MS_DEFER: begin
                        if (ireg == 5) pctr <= mbuf;
                        nxtmajst <= (ireg == 5) ? brkintfet : MS_EXEC;
                    end

                    // end of EXEC cycle
                    MS_EXEC, MS_INTAK: begin
                        case (ireg)
                            0: acum <= acum & mbuf;                         // and
                            1: begin link <= tadlink; acum <= tadacum; end  // tad
                            2: if (mbuf == 0) pctr <= pctr + 1;             // isz
                            3: acum <= 0;                                   // dca
                            4: pctr <= madr + 1;                            // jms
                        endcase
                        nxtmajst <= brkintfet;
                    end

                    // nearing end of wordcount
                    MS_WRDCT: nxtmajst <= MS_CURAD;

                    // nearing end of currentaddress
                    MS_CURAD: nxtmajst <= MS_BREAK;

                    // nearing end of break
                    MS_BREAK: nxtmajst <= brkintfet;

                    // something else, halt next
                    default: hreq <= 1;
                endcase
            end

            ////////////////////////////////////////
            //  update AC,PC at end of IO pulses  //
            ////////////////////////////////////////

            if (lastiop1 & ~ iop1 | lastiop2 & ~ iop2 | lastiop4 & ~ iop4) begin
                if (mbuf[08:00] == 1) begin     // 06001 = ION
                    intdelayed <= 1;
                end
                if (mbuf[08:00] == 2) begin     // 06002 = IOF
                    intdelayed <= 0;
                    intenabled <= 0;
                end
                acum <= (iACCLEAR ? 0 : acum) | iINBUS;
                if (iIOSKIP) pctr <= pctr + 1;
            end

            /////////////////////////////
            //  TS4: final processing  //
            /////////////////////////////

            if (~ lasttp4 & tp4) begin

                // maybe single-stepping or single-cycling or stopping
                if (swSINST & (nxtmajst == MS_FETCH) | swSSTEP | swSTOP) hreq <= 1;

                // set up address for next cycle
                // note: memext is updating field registers now too
                case (nxtmajst)

                    // FETCH next: use PC for next memory address, instruction space
                    MS_FETCH: begin
                        madr    <= pctr;
                        oFLDSEL <= FS_INST;
                    end

                    // DEFER next: use effective address for next address, instruction space
                    MS_DEFER: begin
                        madr    <= effaddr;
                        oFLDSEL <= FS_INST;
                    end

                    // EXEC next: if currently DEFER, use indirect address from data space
                    //                  else FETCH, use effective address from instr space
                    MS_EXEC: begin
                        madr    <= (majstate == MS_DEFER) ? mbuf : effaddr;
                        oFLDSEL <= (majstate == MS_DEFER) & ~ ireg[11] ? FS_DATA : FS_INST;
                    end

                    // wordcount/current address: read values from page 0
                    MS_WRDCT: begin madr <= iDMAADDR; oFLDSEL <= FS_ZERO; end
                    MS_CURAD: begin madr <= madr + 1; oFLDSEL <= FS_ZERO; end

                    // BREAK next:
                    //  if in CURAD, address comes from MB (the incremented pointer of a 3-cycle DMA)
                    //  otherwise, it is a single-cycle DMA so get address from the device
                    MS_BREAK: begin
                        madr    <= (majstate == MS_CURAD) ? mbuf : iDMAADDR;
                        oFLDSEL <= FS_BREAK;
                    end

                    // INTAK next: write return address to address 0 of instr space
                    //             memory extension is clearing to page 0
                    MS_INTAK: begin
                        intdelayed <= 0;
                        intenabled <= 0;
                        ireg       <= 4;
                        madr       <= 0;
                        oFLDSEL    <= FS_INST;
                    end

                    // EXAM, DEPOS or unknown, halt
                    default: hreq <= 1;
                endcase

                // update to next state
                majstate <= nxtmajst;
            end
        end

        // edge detection
        lasthgnt <= hgnt;
        lastts1  <= ts1;
        lasttp1  <= tp1;
        lastts2  <= ts2;
        lasttp2  <= tp2;
        lastts3  <= ts3;
        lasttp3  <= tp3;
        lastiog1 <= iog1;
        lastiop1 <= iop1;
        lastiog2 <= iog2;
        lastiop2 <= iop2;
        lastiog4 <= iog4;
        lastiop4 <= iop4;
        lastioge <= ioge;
        lastts4  <= ts4;
        lasttp4  <= tp4;

        lastswstart <= swSTART;
        lastswldad  <= swLDAD;
        lastswdep   <= swDEP;
        lastswexam  <= swEXAM;
        lastswcont  <= swCONT;
    end

    //////////////////////////
    //  output connections  //
    //////////////////////////

    assign oBREAK  = (majstate == MS_BREAK);
    assign oEXEFET = (nxtmajst == MS_EXEC) | (nxtmajst == MS_FETCH);
    assign oINTACK = (nxtmajst == MS_INTAK);    // valid from just after posedge TS3 of INTACK cycle to posedge TS3 of INTACK cycle
    assign oIOP1 = iop1;
    assign oIOP2 = iop2;
    assign oIOP4 = iop4;
    assign oJMPJMS = (ireg[11:10] == 2);
    assign oRUN = ~ hgnt;
    assign oTP1 = tp1;
    assign oTP2 = tp2;
    assign oTP3 = tp3;
    assign oTP4 = tp4;
    assign oTS1 = ts1;
    assign oTS2 = ts2;
    assign oTS3 = ts3;
    assign oTS4 = ts4;
    assign oACUM = acum;
    assign oMADR = madr;
    assign oMBUF = mbuf;

    assign lbPCTR  = pctr;
    assign lbIREG  = ireg;
    assign lbMAJST = majstate;
    assign lbION   = intenabled;
    assign lbPAUSE = 0;
    assign lbLINK  = link;

endmodule
