
module processor (
    input zclock,               // fpga 10MHz clock
    input zreset,               // fpga reset

    input preset,               // power-on reset

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
    input iLNKTOG,              // toggle link register
    input[11:00] iDMAADDR,      // break cycle address
    input[11:00] iDMADATA,      // break cycle write data
    input[11:00] iINBUS,        // IO data being read from device
    input[11:00] iMEMBUS,       // data being read from memory
    output oBREAK,              // doing BREAK cycle
    output oBUSINI,             // initialize devices
    output reg oBWCOV,          // break wordcount overflowed
    output oEXEFET,             // about to do EXEC or FETCH cycle
    output oINTACK,             // about to do INTACK cycle
    output oIOP1,               // IO pulses
    output oIOP2,               // ...400nS each
    output oIOP4,               // ...300nS spacing
    output oJMPJMS,             // JMP/JMS instruction in instruction register
    output oLINK,               // link register
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

    // switches
    input swLDAD,               // button (idempotent)
    input swEXAM,               // button (debounced)
    input swDEPOS,              // button (debounced)
    input swCONT,               // button (debounced)
    input swSTOP,               // button (idempotent)
    input swSTART,              // button (debounced)
    input swSINST,              // toggle
    input swSSTEP,              // toggle
    input[11:00] swREG          // toggle
);

`include "fsdef.v"
`include "msdef.v"

    reg[11:00] acum, madr, mbuf, pctr;
    reg[11:09] ireg;
    reg[3:0] brkintfet, majstate, nxtmajst;
    reg intdelayed, intenabled, link, syncbrkrq, syncintrq;
    reg lastswcont, lastswdepos, lastswexam, lastswldad, lastswstart;

    ///////////////////
    //  TIME STATES  //
    ///////////////////

    reg[1:0] tsct;
    reg hgnt, ts1, ts2, ts3, iop1, iop2, iop4, ts4;
    reg tp1, tp2, tp3, iog1, iog2, iog4, ioge, tp4;
    reg hreq;

    // indicate when to step on to next time state
    //  TS1,2,3,4,IOP1,2,4 - 400nS
    //  IOG1,2,4,E - 300nS
    wire clockts = tsct[1] & (tsct[0] | iog1 | iog2 | iog4 | ioge);

    // decide to halt at end of TS4
    // - halting: transitions to HGNT until HREQ released
    // - continuing: transitions to TS1
    wire newhgnt = (ts4 | hgnt) & hreq;

    // current cycle is an io instruction so includes io gaps and pulses
    wire ioinst  = (ireg[11:09] == 6) & (majstate == MS_FETCH);

    always @(posedge zclock) begin

        tsct <=
            preset  ? 0 :
            iHOLD   ? tsct :                            // stop counting while being held
            clockts ? 0 : tsct + 1;                     // count the 400nS or 300nS interval

        // ring counter for the time states
        hgnt <=
            preset ? 1 :
            clockts ? newhgnt :                         // if end of TS4 or already halted and halt requested, halt
            hgnt;
        ts1  <= clockts ? (ts4 | hgnt) & ~ hreq : ts1;  // if end of TS4 or halted and halt not requested, start TS1
        ts2  <= clockts ? ts1 : ts2;                    // start TS2 at end of TS1
        ts3  <= clockts ? ts2 : ts3;                    // start TS3 at end of TS2
        iog1 <= clockts ? ts3 &   ioinst : iog1;        // start IOG1 at end of TS3 with ioinst (gap bewteen TS3 and IOP1)
        iop1 <= clockts ? iog1 : iop1;                  // start IOP1 at end of IOG1
        iog2 <= clockts ? iop1 : iog2;                  // start IOG2 at end of IOP1 (gap between IOP1 and IOP2)
        iop2 <= clockts ? iog2 : iop2;                  // start IOP2 at end of IOG2
        iog4 <= clockts ? iop2 : iog4;                  // start IOG4 at end of IOP2 (gap between IOP2 and IOP4)
        iop4 <= clockts ? iog4 : iop4;                  // start IOP4 at end of IOG4
        ioge <= clockts ? iop4 : ioge;                  // start IOGE at end of IOP4 (gap between IOP4 and TS4)
        ts4  <= clockts ? ts3 & ~ ioinst | ioge : ts4;  // start TS4 at end of IOGE or end of TS3 with no ioinst

        // TPn start in last 100nS of corresponding TSn and continue for 200nS
        tp1 <= ts1 & tsct[1];
        tp2 <= ts2 & tsct[1];
        tp3 <= ts3 & tsct[1];
        tp4 <= ts4 & tsct[1];
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

    ////////////////////
    //  MAJOR STATES  //
    ////////////////////

    // major state following the current major state cycle
    // this is used at posedge TP4, after any possible IOPs of current instruction
    always @(*) begin

        // compute major state following last cycle of current instruction
        if (syncbrkrq) begin
            brkintfet = i3CYCLE ? MS_WRDCT : MS_BREAK;
        end

        else if (syncintrq &                        // some device is requesting an interrupt
                 intenabled &                       // 6001 was executed at least one instruction ago
                 (~ iINTINH | oJMPJMS)) begin       // not blocked by prior 62x2/62x3 until jump or currently jumping
            brkintfet = MS_INTAK;
        end

        else brkintfet = MS_FETCH;                  // nothing special, fetch next instruction

        // compute major state following the current major state cycle
        case (majstate)

            // end of FETCH cycle
            MS_FETCH: begin
                case (ireg)

                    // add, tad, isz, dca, jms
                    0, 1, 2, 3, 4: nxtmajst = mbuf[08] ? MS_DEFER : MS_EXEC;

                    // jmp
                    5: nxtmajst = mbuf[08] ? MS_DEFER : brkintfet;

                    // iot
                    6: nxtmajst = brkintfet;

                    // opr
                    7: nxtmajst = mbuf[08] & (mbuf[02] | mbuf[01]) & mbuf[00] ? MS_EXEC : brkintfet;
                endcase
            end

            // end of DEFER cycle
            MS_DEFER: begin
                nxtmajst = (ireg == 5) ? brkintfet : MS_EXEC;
            end

            // end of EXEC cycle
            // end of BREAK
            MS_EXEC, MS_INTAK, MS_BREAK: begin
                nxtmajst = brkintfet;
            end

            // end of wordcount
            MS_WRDCT: nxtmajst = MS_CURAD;

            // end of currentaddress
            MS_CURAD: nxtmajst = MS_BREAK;

            // EXAM, DEPOS: stay in that state
            default: nxtmajst = majstate;
        endcase
    end

    reg lasthgnt, lasttp1, lasttp2, lasttp3, lasttp4;

    // asserted for single 100nS clock cycle after button pressed
    wire posedgeldad  = hgnt & ~ lastswldad  & swLDAD;
    wire posedgeexam  = hgnt & ~ lastswexam  & swEXAM;
    wire posedgedepos = hgnt & ~ lastswdepos & swDEPOS;
    wire posedgecontx = hgnt & ~ lastswcont  & swCONT & ((majstate == MS_EXAM) | (majstate == MS_DEPOS));
    wire posedgestart = hgnt & ~ lastswstart & swSTART;

    // asserted for single 100nS clock cycle after button released
    wire negedgeldad  = lastswldad  & ~ swLDAD;
    wire negedgeexam  = lastswexam  & ~ swEXAM;
    wire negedgedepos = lastswdepos & ~ swDEPOS;
    wire negedgecont  = lastswcont  & ~ swCONT;
    wire negedgestart = lastswstart & ~ swSTART;

    // asserted during last 100nS clock cycle of TSn
    wire posedgetp1 = ~ lasttp1 & tp1;
    wire posedgetp2 = ~ lasttp2 & tp2;
    wire posedgetp3 = ~ lasttp3 & tp3;
    wire posedgetp4 = ~ lasttp4 & tp4;

    // asserted during last 100nS clock cycle of IOPn
    // accumulator and ioskip updated at the end of the cycle
    wire negedgeiop = clockts & (iop1 | iop2 | iop4);

    // accumulator data being read from a pio device or extended arithmetic board
    wire[11:00] ioindata = (iACCLEAR ? 0 : acum) | iINBUS;

    // current cycle is performing extended arithmetic
    // accumulator and link get clocked at TP3 in these cycles
    //  FETCH: must have opcode 111 1xx xxx xx1
    //   EXEC: must have opcode 111 xxx xxx xxx  it is only 7 opcode that uses EXEC state
    wire extarithexec = (ireg == 7) & ((majstate == MS_FETCH) & mbuf[08] & mbuf[00] | (majstate == MS_EXEC));

    always @(posedge zclock) begin

        // maintain major state
        majstate <=

            // power-on reset
            preset ? MS_PWRON :

            // various console switches being pressed set state to process the switch
            posedgeldad  ? MS_EXAM  :
            posedgeexam  ? MS_EXAM  :
            posedgedepos ? MS_DEPOS :
            posedgecontx ? MS_FETCH :
            posedgestart ? MS_FETCH :

            // processor running, load from nxtmajst on posedge TP4
            posedgetp4 ? nxtmajst :

            // none of the above, maintain current state
            majstate;

        // maintain memory address register
        madr <=

            // load address switch
            posedgeldad ? swREG :

            // consecutive examine and deposit switches
            posedgeexam  & (majstate == MS_EXAM)  ? madr + 1 :
            posedgedepos & (majstate == MS_DEPOS) ? madr + 1 :

            // clocking at posedge TP4 based on next state
            posedgetp4 & (nxtmajst == MS_FETCH) ? pctr     :    // fetch reads instruction from PC
            posedgetp4 & (nxtmajst == MS_DEFER) ? effaddr  :    // defer reads pointer from effaddr
            posedgetp4 & (nxtmajst == MS_EXEC)  ? (
                           ireg == 7 ? pctr  :                  // extended arithmetic with memory operand
                majstate == MS_DEFER ? mbuf  :                  // indirect address, read from indirect pointer
                                    effaddr) :                  // direct address, read from effective address
            posedgetp4 & (nxtmajst == MS_WRDCT) ? iDMAADDR :    // word count reads count from DMAADDR
            posedgetp4 & (nxtmajst == MS_CURAD) ? madr + 1 :    // current address reads pointer from address after WRDCT address
            posedgetp4 & (nxtmajst == MS_BREAK) ? (
                             i3CYCLE ? mbuf  :                  // 3-cycle dma gets address from incremented CURAD pointer
                                   iDMAADDR) :                  // 1-cycle dma gets address from DMAADDR
            posedgetp4 & (nxtmajst == MS_INTAK) ? 0 :           // interrupt acknowledge writes return address to location 00000

            // none of the above, keep existing value
            madr;

        // maintain field select register
        oFLDSEL <=

            // pressing console switch while halted
            posedgeldad  ? FS_INST :
            posedgeexam  ? FS_INST :
            posedgedepos ? FS_INST :
            posedgecontx ? FS_INST :
            posedgestart ? FS_INST :

            // running updates at posedge TP4
            posedgetp4 & (nxtmajst == MS_FETCH) ? FS_INST  :
            posedgetp4 & (nxtmajst == MS_DEFER) ? FS_INST  :
            posedgetp4 & (nxtmajst == MS_EXEC)  ? (majstate == MS_DEFER & ~ ireg[11] ? FS_DATA : FS_INST) :
            posedgetp4 & (nxtmajst == MS_WRDCT) ? FS_ZERO  :
            posedgetp4 & (nxtmajst == MS_CURAD) ? FS_ZERO  :
            posedgetp4 & (nxtmajst == MS_BREAK) ? FS_BREAK :
            posedgetp4 & (nxtmajst == MS_INTAK) ? FS_INST  :

            // otherwise maintain existing value
            oFLDSEL;

        // maintain halt request register
        hreq <=

            // power-on reset
            preset ? 1 :

            // releasing console switch
            negedgeldad  ? 0 :
            negedgeexam  ? 0 :
            negedgedepos ? 0 :
            negedgecont  ? 0 :
            negedgestart ? 0 :

            // HLT instruction bit
            posedgetp3 & (majstate == MS_FETCH) & (ireg == 7) & mbuf[08] & ~ mbuf[00] & mbuf[01] ? 1 :

            // console single-stepping, single-cycling, stop switch
            posedgetp4 & swSINST & (nxtmajst == MS_FETCH) | swSSTEP | swSTOP ? 1 :

            // exam, deposit cycles cause an halt
            posedgetp4 & (nxtmajst == MS_EXAM | nxtmajst == MS_DEPOS) ? 1 :

            // otherwise maintain value
            hreq;

        // maintain memory buffer register
        mbuf <=

            // clock in memory data on posedge TP1
            posedgetp1 ? iMEMBUS :

            // increment at posedge TP2 and in DEFER state and autoincrement pointer
            posedgetp2 & (majstate == MS_DEFER) & (madr[11:03] == 1) ? mbuf + 1 :

            // increment at posedge TP2 and in EXEC state for ISZ instruction
            posedgetp2 & (majstate == MS_EXEC) & (ireg == 2) ? mbuf + 1 :

            // load from ACUM at posedge TP2 and in EXEC state for DCA instruction
            posedgetp2 & (majstate == MS_EXEC) & (ireg == 3) ? acum :

            // load from PCTR at posedge TP2 and in EXEC or INTAK state for JMS instruction
            posedgetp2 & ((majstate == MS_EXEC) | (majstate == MS_INTAK)) & (ireg == 4) ? pctr :

            // increment at posedge TP2 and in WRDCT state
            posedgetp2 & (majstate == MS_WRDCT) ? mbuf + 1 :

            // increment at posedge TP2 and in CURAD state with iCAINC
            posedgetp2 & (majstate == MS_CURAD) & iCAINC ? mbuf + 1 :

            // load from DMA data at posedge TP2 and in BREAK state with iBRKWRM
            posedgetp2 & (majstate == MS_BREAK) & iBRKWRM ? iDMADATA :

            // load from switches at posedge TP2 and in DEPOS state
            posedgetp2 & (majstate == MS_DEPOS) ? swREG :

            mbuf;

        // maintain instruction register
        ireg <=

            // load at posedge TP2 when in FETCH state
            posedgetp2 & (majstate == MS_FETCH) ? mbuf[11:09] :

            // load at posedge TP4 when going into MS_INTAK state
            posedgetp4 & (nxtmajst == MS_INTAK) ? 4 :

            ireg;

        // maintain program counter register
        pctr <=

            // get from madr for CONTx and START switches
            posedgecontx ? madr :
            posedgestart ? madr :

            // increment after instruction fetched
            // leave madr pointing to instruction so effaddr will be correct
            posedgetp2 & (majstate == MS_FETCH) ? pctr + 1 :

            // load effective address for direct JMP
            posedgetp3 & (majstate == MS_FETCH) & (ireg == 5) & ~ mbuf[08] ? effaddr :

            // increment PC for Group 2 skip condition
            posedgetp3 & (majstate == MS_FETCH) & (ireg == 7) & mbuf[08] & ~ mbuf[00] & g2skip ? pctr + 1 :

            // load pointer contents for indirect JMP
            posedgetp3 & (majstate == MS_DEFER) & (ireg == 5) ? mbuf :

            // increment PC for ISZ instruction if now zero
            posedgetp3 & (majstate == MS_EXEC) & (ireg == 2) & (mbuf == 0) ? pctr + 1 :

            // load from where return address was saved + 1 for JMS instruction
            posedgetp3 & ((majstate == MS_EXEC) | (majstate == MS_INTAK)) & (ireg == 4) ? madr + 1 :

            // increment PC for extended arithmetic with memory operand
            posedgetp3 & (majstate == MS_EXEC) & (ireg == 7) ? pctr + 1 :

            // increment PC for IOP skips
            negedgeiop & iIOSKIP ? pctr + 1 :

            // otherwise maintain current value
            pctr;

        // wordcount cycle overflow
        oBWCOV <= posedgetp2 & (majstate == MS_WRDCT) ? (mbuf == 12'o7777) : oBWCOV;

        // maintain accumulator register
        acum <=

            // Group 1 computation result
            posedgetp3 & (majstate == MS_FETCH) & (ireg == 7) & ~ mbuf[08] ? g1acum :

            // Group 2 computation result
            posedgetp3 & (majstate == MS_FETCH) & (ireg == 7) & mbuf[08] & ~ mbuf[00] ? g2acum :

            // AND, TAD and DCA instructions
            posedgetp3 & (majstate == MS_EXEC) & (ireg == 0) ? acum & mbuf :
            posedgetp3 & (majstate == MS_EXEC) & (ireg == 1) ? tadacum :
            posedgetp3 & (majstate == MS_EXEC) & (ireg == 3) ? 0 :

            // extended arithmetic
            posedgetp3 & extarithexec ? ioindata :

            // accumulator updates at end of IO pulse
            negedgeiop ? ioindata :

            // otherwise maintain value
            acum;

        // maintain link register
        link <=

            // Group 1
            posedgetp3 & (majstate == MS_FETCH) & (ireg == 7) & ~ mbuf[08] ? g1link :

            // TAD instruction
            posedgetp3 & (majstate == MS_EXEC) & (ireg == 1) ? tadlink :

            // extended arithmetic
            posedgetp3 & extarithexec & iLNKTOG ? ~ link :

            // otherwise maintain value
            link;

        // synchronize external async inputs
        syncbrkrq <= posedgetp3 ? iBRKRQST : syncbrkrq;
        syncintrq <= posedgetp3 ? iINTRQST : syncintrq;

        // maintain interrupt enable register
        intdelayed <=

            // disable for acknowledge interrupt cycle
            posedgetp2 & (majstate == MS_INTAK) ? 0 :

            // enable during IOP1 if IOF (6001) instruction
            // the enable will be delayed until fetch of next instruction
            iop1 & (mbuf[08:00] == 1) ? 1 :

            // disable during IOP2 if IOF (6002) instruction
            // the disable will be in effect by the time TP4 processes interrupt request at end of IOF instruction
            iop2 & (mbuf[08:00] == 2) ? 0 :

            // maintain value otherwise
            intdelayed;

        intenabled <=

            // get delayed enable when fetching instruction
            posedgetp2 & (majstate == MS_FETCH) ? intdelayed :

            // disable for acknowledge interrupt cycle
            posedgetp2 & (majstate == MS_INTAK) ? 0 :

            // disable interrupts during IOP2 if IOF (6002) instruction
            // the disable will be in effect by the time TP4 processes interrupt request at end of IOF instruction
            iop2 & (mbuf[08:00] == 2) ? 0 :

            // maintain value otherwise
            intenabled;

        // edge detection
        lasthgnt <= hgnt;
        lasttp1  <= tp1;
        lasttp2  <= tp2;
        lasttp3  <= tp3;
        lasttp4  <= tp4;

        lastswstart <= swSTART;
        lastswldad  <= swLDAD;
        lastswdepos <= swDEPOS;
        lastswexam  <= swEXAM;
        lastswcont  <= swCONT;
    end

    //////////////////////////
    //  output connections  //
    //////////////////////////

    assign oBREAK  = (majstate == MS_BREAK);
    assign oBUSINI = zreset | preset | swSTART;
    assign oEXEFET = (nxtmajst == MS_EXEC) | (nxtmajst == MS_FETCH);
    assign oINTACK = (nxtmajst == MS_INTAK);    // valid from just after posedge TS3 of INTACK cycle to posedge TS3 of INTACK cycle
    assign oIOP1   = iop1;
    assign oIOP2   = iop2;
    assign oIOP4   = iop4;
    assign oJMPJMS = (ireg[11:10] == 2);
    assign oLINK   = link;
    assign oRUN    = ~ hgnt;
    assign oTP1    = tp1;
    assign oTP2    = tp2;
    assign oTP3    = tp3;
    assign oTP4    = tp4;
    assign oTS1    = ts1;
    assign oTS2    = ts2;
    assign oTS3    = ts3;
    assign oTS4    = ts4;
    assign oACUM   = acum;
    assign oMADR   = madr;
    assign oMBUF   = mbuf;

    assign lbPCTR  = pctr;
    assign lbIREG  = ireg;
    assign lbMAJST = majstate;
    assign lbION   = intenabled;
    assign lbPAUSE = 0;

endmodule
