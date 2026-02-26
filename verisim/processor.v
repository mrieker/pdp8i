
module processor (
    input clok2,                // 10MHz clock
    input reset,                // power-on reset

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
    output oIOP,                // IO pulse - 700nS
    output oJMPJMS,             // JMP/JMS instruction in instruction register
    output oLINK,               // link register
    output oRUN,                // processing instructions
    output oTP1,                // time pulses, 100nS each
    output oTP2,                // ...overlap last 100nS of corresponding TSn
    output oTP3,
    output oTP4,
    output oTS1,                // time states
    output oTS2,                // ...400nS each
    output oTS3,                // ...no spacing
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

    wire _clok1 = ~ clok2;
    wire clok0 = ~ _clok1;

    ///////////////////
    //  TIME STATES  //
    ///////////////////

    reg[1:0] tsct, _tsct;
    reg hgnt, hreq, _hgnt;
    reg ts1, ts2, ts3, ts4, iop;
    reg tp1, tp2, tp3, tp4;
    reg _ts1, _ts2, _ts3, _ts4, _iop;
    reg _tp1, _tp2, _tp3, _tp4;

    // count the 400nS interval
    wire tsct0j = ~ iHOLD;
    wire tsct0k = ~ iHOLD;
    wire tsct1j = ~ iHOLD & tsct[0];
    wire tsct1k = ~ iHOLD & tsct[0];
    JKFF tsct0ff (.PC (reset), .PS (0), .J (tsct0j), .K (tsct0k), .T (clok0), .Q (tsct[0]), ._Q (_tsct[0]));
    JKFF tsct1ff (.PC (reset), .PS (0), .J (tsct1j), .K (tsct1k), .T (clok0), .Q (tsct[1]), ._Q (_tsct[1]));
    wire ts400 = tsct[0] & tsct[1];     // last 100nS of 400nS cycle

    // halt grant - spliced in between previous cycle TS4 and next cycle TS1
    // - these can occur mid-instruction such as when single cycling
    //   majstate indicates what state will be executed when hgnt is cleared and TS1 begins
    wire hgntj = tp4 & hreq;                        // begin HGNT when TS4 ends and halt being requested
    wire hgntk = ts400 & ~ hreq;                    // end HGNT when halt no longer being requested
    JKFF hgntff (.PC (0), .PS (reset), .J (hgntj), .K (hgntk), .T (clok0), .Q (hgnt), ._Q (_hgnt));

    // [HGNT] TS1 TS2 TS3 TS4  (1.6 uS + halt time)
    // all states last 400nS
    wire ts1j = (tp4 | hgnt) & ts400 & ~ hreq;      // begin TS1 when halt not requested and ending TS4 or HGNT
    JKFF ts1ff (.PC (reset), .PS (0), .J (ts1j), .K (tp1), .T (clok0), .Q (ts1), ._Q (_ts1));
    JKFF ts2ff (.PC (reset), .PS (0), .J (tp1),  .K (tp2), .T (clok0), .Q (ts2), ._Q (_ts2));
    JKFF ts3ff (.PC (reset), .PS (0), .J (tp2),  .K (tp3), .T (clok0), .Q (ts3), ._Q (_ts3));
    JKFF ts4ff (.PC (reset), .PS (0), .J (tp3),  .K (tp4), .T (clok0), .Q (ts4), ._Q (_ts4));

    // TPn asserted for last 100nS of corresponding TSn
    JKFF tp1ff (.PC (reset), .PS (0), .J (ts1 & tsct[1]), .K (ts400), .T (clok0), .Q (tp1), ._Q (_tp1));
    JKFF tp2ff (.PC (reset), .PS (0), .J (ts2 & tsct[1]), .K (ts400), .T (clok0), .Q (tp2), ._Q (_tp2));
    JKFF tp3ff (.PC (reset), .PS (0), .J (ts3 & tsct[1]), .K (ts400), .T (clok0), .Q (tp3), ._Q (_tp3));
    JKFF tp4ff (.PC (reset), .PS (0), .J (ts4 & tsct[1]), .K (ts400), .T (clok0), .Q (tp4), ._Q (_tp4));

    // IOP asserted 100nS into TS2 and negated when TS3 negated (total 700nS)
    // accumulator mods and ioskip clocked on posedge TP3 (ie 600nS into IOP)
    wire iopj = ts2 & (ireg[11:09] == 6) & (majstate == MS_FETCH);
    JKFF iopff (.PC (reset), .PS (0), .J (iopj), .K (tp3), .T (clok0), .Q (iop), ._Q (_iop));

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
    // this is used at posedge TP4
    always @(*) begin

        // compute major state following last cycle of current instruction
        if (syncbrkrq) begin
            brkintfet = i3CYCLE ? MS_WRDCT : MS_BREAK;
        end

        else if (syncintrq &                        // some device is requesting an interrupt
                 intenabled &                       // 6001 was executed at least one instruction ago
                 ~ iINTINH) begin                   // not blocked by prior 62x2/62x3 until jump
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

    // asserted for single 100nS clock cycle after button pressed and processor is halted
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

    // accumulator data being read from a pio device or extended arithmetic board
    wire[11:00] ioindata = (iACCLEAR ? 0 : acum) | iINBUS;

    // current cycle is performing extended arithmetic
    // accumulator and link get clocked at TP3 in these cycles
    //  FETCH: must have opcode 111 1xx xxx xx1
    //   EXEC: must have opcode 111 xxx xxx xxx  it is only 7 opcode that uses EXEC state
    wire extarithexec = (ireg == 7) & ((majstate == MS_FETCH) & mbuf[08] & mbuf[00] | (majstate == MS_EXEC));

    wire breakwrite = tp2 & (majstate == MS_BREAK) & iBRKWRM;

    always @(posedge clok0) begin

        // maintain major state
        majstate <=

            // power-on reset
            reset ? MS_PWRON :

            // various console switches being pressed while halted set state to process the switch
            posedgeldad  ? MS_EXAM  :
            posedgeexam  ? MS_EXAM  :
            posedgedepos ? MS_DEPOS :
            posedgecontx ? MS_FETCH :
            posedgestart ? MS_FETCH :

            // TP4 happens only when processor running, load from nxtmajst
            tp4 ? nxtmajst :

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
            tp4 & (nxtmajst == MS_FETCH) ? pctr     :   // fetch reads instruction from PC
            tp4 & (nxtmajst == MS_DEFER) ? effaddr  :   // defer reads pointer from effaddr
            tp4 & (nxtmajst == MS_EXEC)  ? (
                           ireg == 7 ? pctr  :          // extended arithmetic with memory operand
                majstate == MS_DEFER ? mbuf  :          // indirect address, read from indirect pointer
                                    effaddr) :          // direct address, read from effective address
            tp4 & (nxtmajst == MS_WRDCT) ? iDMAADDR :   // word count reads count from DMAADDR
            tp4 & (nxtmajst == MS_CURAD) ? madr + 1 :   // current address reads pointer from address after WRDCT address
            tp4 & (nxtmajst == MS_BREAK) ? (
                             i3CYCLE ? mbuf  :          // 3-cycle dma gets address from incremented CURAD pointer
                                   iDMAADDR) :          // 1-cycle dma gets address from DMAADDR
            tp4 & (nxtmajst == MS_INTAK) ? 0 :          // interrupt acknowledge writes return address to location 00000

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
            tp4 & (nxtmajst == MS_FETCH) ? FS_INST  :
            tp4 & (nxtmajst == MS_DEFER) ? FS_INST  :
            tp4 & (nxtmajst == MS_EXEC)  ? (majstate == MS_DEFER & ~ ireg[11] ? FS_DATA : FS_INST) :
            tp4 & (nxtmajst == MS_WRDCT) ? FS_ZERO  :
            tp4 & (nxtmajst == MS_CURAD) ? FS_ZERO  :
            tp4 & (nxtmajst == MS_BREAK) ? FS_BREAK :
            tp4 & (nxtmajst == MS_INTAK) ? FS_INST  :

            // otherwise maintain existing value
            oFLDSEL;

        // maintain halt request register
        hreq <=

            // power-on reset
            reset ? 1 :

            // releasing console switch
            negedgeldad  ? 0 :
            negedgeexam  ? 0 :
            negedgedepos ? 0 :
            negedgecont  ? 0 :
            negedgestart ? 0 :

            // HLT instruction bit
            tp3 & (majstate == MS_FETCH) & (ireg == 7) & mbuf[08] & ~ mbuf[00] & mbuf[01] ? 1 :

            // console single-stepping, single-cycling, stop switch
            tp3 & (swSINST & (nxtmajst == MS_FETCH) | swSSTEP | swSTOP) ? 1 :

            // exam, deposit cycles cause an halt
            tp3 & (nxtmajst == MS_EXAM | nxtmajst == MS_DEPOS) ? 1 :

            // otherwise maintain value
            hreq;

        // maintain memory buffer register
        mbuf <=

            // clock in memory data on posedge TP1
            tp1 ? iMEMBUS :

            // increment at posedge TP2 and in DEFER state and autoincrement pointer
            tp2 & (majstate == MS_DEFER) & (madr[11:03] == 1) ? mbuf + 1 :

            // increment at posedge TP2 and in EXEC state for ISZ instruction
            tp2 & (majstate == MS_EXEC) & (ireg == 2) ? mbuf + 1 :

            // load from ACUM at posedge TP2 and in EXEC state for DCA instruction
            tp2 & (majstate == MS_EXEC) & (ireg == 3) ? acum :

            // load from PCTR at posedge TP2 and in EXEC or INTAK state for JMS instruction
            tp2 & ((majstate == MS_EXEC) | (majstate == MS_INTAK)) & (ireg == 4) ? pctr :

            // increment at posedge TP2 and in WRDCT state
            tp2 & (majstate == MS_WRDCT) ? mbuf + 1 :

            // increment at posedge TP2 and in CURAD state with iCAINC
            tp2 & (majstate == MS_CURAD) & iCAINC ? mbuf + 1 :

            // load from DMA data at posedge TP2 and in BREAK state with iBRKWRM
            breakwrite ? iDMADATA :

            // load from switches at posedge TP2 and in DEPOS state
            tp2 & (majstate == MS_DEPOS) ? swREG :

            mbuf;

        // maintain instruction register
        ireg <=

            // load at posedge TP1 when in FETCH state
            tp1 & (majstate == MS_FETCH) ? iMEMBUS[11:09] :

            // load at posedge TP4 when going into MS_INTAK state
            tp4 & (nxtmajst == MS_INTAK) ? 4 :

            ireg;

        // maintain program counter register
        pctr <=

            // get from madr for CONTx and START switches
            posedgecontx ? madr :
            posedgestart ? madr :

            // increment after instruction fetched
            // leave madr pointing to instruction so effaddr will be correct
            tp2 & (majstate == MS_FETCH) ? pctr + 1 :

            // load effective address for direct JMP
            tp3 & (majstate == MS_FETCH) & (ireg == 5) & ~ mbuf[08] ? effaddr :

            // increment PC for Group 2 skip condition
            tp3 & (majstate == MS_FETCH) & (ireg == 7) & mbuf[08] & ~ mbuf[00] & g2skip ? pctr + 1 :

            // load pointer contents for indirect JMP
            tp3 & (majstate == MS_DEFER) & (ireg == 5) ? mbuf :

            // increment PC for ISZ instruction if now zero
            tp3 & (majstate == MS_EXEC) & (ireg == 2) & (mbuf == 0) ? pctr + 1 :

            // load from where return address was saved + 1 for JMS instruction
            tp3 & ((majstate == MS_EXEC) | (majstate == MS_INTAK)) & (ireg == 4) ? madr + 1 :

            // increment PC for extended arithmetic with memory operand
            tp3 & (majstate == MS_EXEC) & (ireg == 7) ? pctr + 1 :

            // increment PC for IOP skips
            tp3 & iop & iIOSKIP ? pctr + 1 :

            // otherwise maintain current value
            pctr;

        // wordcount cycle overflow
        oBWCOV <= tp2 & (majstate == MS_WRDCT) ? (mbuf == 12'o7777) : oBWCOV;

        // maintain accumulator register
        acum <=

            // Group 1 computation result
            tp3 & (majstate == MS_FETCH) & (ireg == 7) & ~ mbuf[08] ? g1acum :

            // Group 2 computation result
            tp3 & (majstate == MS_FETCH) & (ireg == 7) & mbuf[08] & ~ mbuf[00] ? g2acum :

            // AND, TAD and DCA instructions
            tp3 & (majstate == MS_EXEC) & (ireg == 0) ? acum & mbuf :
            tp3 & (majstate == MS_EXEC) & (ireg == 1) ? tadacum :
            tp3 & (majstate == MS_EXEC) & (ireg == 3) ? 0 :

            // extended arithmetic
            tp3 & extarithexec ? ioindata :

            // accumulator updates at end of IO pulse
            tp3 & iop ? ioindata :

            // otherwise maintain value
            acum;

        // maintain link register
        link <=

            // Group 1
            tp3 & (majstate == MS_FETCH) & (ireg == 7) & ~ mbuf[08] ? g1link :

            // TAD instruction
            tp3 & (majstate == MS_EXEC) & (ireg == 1) ? tadlink :

            // extended arithmetic
            tp3 & extarithexec & iLNKTOG ? ~ link :

            // otherwise maintain value
            link;

        // synchronize external async inputs
        syncbrkrq <= tp3 ? iBRKRQST : syncbrkrq;
        syncintrq <= tp3 ? iINTRQST : syncintrq;

        // maintain interrupt enable register
        intdelayed <=

            // disable for acknowledge interrupt cycle
            tp3 & (majstate == MS_INTAK) ? 0 :

            // enable during IOP if ION (6001) instruction
            // the enable will be delayed until fetch of next instruction
            tp3 & iop & (mbuf[08:00] == 1) ? 1 :

            // disable during IOP if IOF (6002) instruction
            // the disable will be in effect by the time TP4 processes interrupt request at end of IOF instruction
            tp3 & iop & (mbuf[08:00] == 2) ? 0 :

            // maintain value otherwise
            intdelayed;

        intenabled <=

            // disable interrupts during IOP if IOF (6002) instruction
            // the disable will be in effect by the time TP4 processes interrupt request at end of IOF instruction
            tp3 & iop & (mbuf[08:00] == 2) ? 0 :

            // get delayed enable when fetching instruction
            tp3 & (majstate == MS_FETCH) ? intdelayed :

            // disable for acknowledge interrupt cycle
            tp3 & (majstate == MS_INTAK) ? 0 :

            // maintain value otherwise
            intenabled;

        // edge detection
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
    assign oBUSINI = reset | swSTART;
    assign oEXEFET = (nxtmajst == MS_EXEC) | (nxtmajst == MS_FETCH);
    assign oINTACK = (nxtmajst == MS_INTAK);    // valid from just after posedge TS3 of INTACK cycle to posedge TS3 of INTACK cycle
    assign oIOP    = iop;
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
