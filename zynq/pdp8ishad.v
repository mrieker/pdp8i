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

// Verify the PDP-8/I operation, memory cycle by cycle

// test that pdp8ishad works by running verisim/simtest.sh script

// normally the shadower is running checking the processor state
// it keeps running until it finds an error, setting a bit in 'err' register
// a shadow error will freeze the processor only if 'frzonerr' enabled by the arm
// reset the shadower by setting then clearing the 'clearit' bit from the arm

module pdp8ishad (
    input CLOCK, RESET,  // fpga 100MHz clock and reset

    input armwrite,
    input[2:0] armraddr, armwaddr,
    input[31:00] armwdata,
    output[31:00] armrdata,

    input fpgamemen,

    // all signals coming into fpga from the external bus
    input[11:00]    oACUM,
    input           oBRKCYC,
    input           oBRKGNTI,
    input           oBRKRQST,
    input           oBUSINI,
    input           oBWCOV,
    input           oIOP,
    input           oLINK,
    input[11:00]    oMADR,
    input[11:00]    oMBUF,
    input[2:0]      oMEAD,
    input[3:0]      oMAJST,
    input           oRUN,
    input           oTP1,
    input           oTP2,
    input           oTP3,
    input           oTP4,
    input           oTS1,
    input           oTS2,
    input           oTS3,
    input           oTS4,

    // fpga outputs these signals to the external bus conditionally
    // otherwise we do not know their state on the external bus
    input        dmagntd,  // enable dma cycle signals onto the external bus
    input        iBRKWRM,  // [dmagntd]
    input        iCAINC,   // [dmagntd]
    input        iCYCLE3,  // [dmagntd]
    input[2:0]   iDMAFLD,  // [dmagntd]

    input        ioenabd,  // enable io signals onto the external bus
    input        iACCLEAR, // [ioenabd]
    input[11:00] iINBUS,   // [ioenabd]
    input        iIOSKIP,  // [ioenabd]

    input        poweron,  // enable the 'always on' and 'open collector' signals onto the external bus
                           // - shadow can assume these are always enabled to the bus
    input        iCLOCK,   // [poweron]
    input        iMEMDIS,  // [poweron]
    input        iRESET,   // [poweron]
    input        iBRKRQST, // [poweron] open collector
    input        iINTRQST, // [poweron] open collector
    input        iPAUSE,   // [poweron] open collector

    // stop clocking processor
    output freeze,
    output[11:00] shadowpc
);

    localparam MS_FETCH =  1;       // memory cycle is fetching instruction
    localparam MS_DEFER =  2;       // memory cycle is reading pointer
    localparam MS_EXEC  =  3;       // memory cycle is for executing instruction
    localparam MS_WRDCT =  4;       // memory cycle is for incrementing dma word count
    localparam MS_CURAD =  5;       // memory cycle is for reading dma address
    localparam MS_BREAK =  6;       // memory cycle is for dma data word transfer
    localparam MS_INTAK =  7;       // memory cycle is for interrupt acknowledge
    localparam MS_DEPOS =  8;       // memory cycle initiated by DEPOS key
    localparam MS_EXAM  =  9;       // memory cycle initiated by LDAD or EXAM key

    localparam TS_S =  0;       // startup, shadow context invalid
    localparam TS_1 =  1;       // read memory (EA sampled at posedge TS1)
                                // - TP1: sample BRK_RQST; inc PC (FETCH); clear ADDR_ACCEPT
                                //   save IF,DF (INTAK)
    localparam TS_2 =  2;       // compute update to memory
                                // - TP2: load IR (FETCH); load MB; load WC_OVERFLOW
    localparam TS_3 =  3;       // write memory, update registers
                                // - TP3: load L,AC (AND,TAD,DCA,OPR); load PC (jumps, skips); sample INT_RQST
    localparam TS_4 =  4;       // determine next state
                                // - TP4: set IR=4 (INTAK next); load F,D,E,WC,CA,B; load MA; load ADDR_ACCEPT (BREAK)
    localparam TS_H =  5;       // halted, shadow context valid

    reg maknown, pcknown, frzonerr;
    reg[11:00] acum, ireg, madr, mquo, mbrd, mbwr, pctr, tp1dat;
    reg[29:00] err1;
    reg[4:0] err2;
    reg[4:0] sctr;
    reg[3:0] majst, timestate;
    reg clearit, intendly, intenabd, intinhuj, link, tp1datval;

    assign shadowpc = pctr;

    // field registers:
    //  <3> = 0: <2:0> = not known to match processor
    //        1: <2:0> = field value should match what processor has
    reg[3:0] dfld, ifaj, ifld, saveddf, savedif;
    reg[2:0] tp1fld;

    wire error = (err1 != 0) | (err2 != 0);
    assign freeze = error & frzonerr;

    reg lasttp1, lastts1, lastts2, lastts3, lastts4;
    reg[1:0] extarstep;

    assign armrdata = (armraddr == 0) ? 32'h53482006 : // [31:16] = 'SH'; [15:12] = (log2 nreg) - 1; [11:00] = version
                      (armraddr == 1) ? { frzonerr, clearit, err1 } :
                      (armraddr == 2) ? { majst, timestate, ireg, pctr } :
                      (armraddr == 3) ? { intendly, intenabd, intinhuj, lastts1, lastts2, lastts3, lastts4, tp1datval, mbrd, madr } :
                      (armraddr == 4) ? { dfld, ifaj, mbwr, acum } :
                      (armraddr == 5) ? { pcknown, maknown, ifld, saveddf, savedif, link, sctr, mquo } :
                      (armraddr == 6) ? { 10'b0, tp1fld, extarstep, err2, tp1dat } :
                      32'hDEADBEEF;

    wire [11:00] eadr = { mbrd[07] ? madr[11:07] : 5'b0, mbrd[06:00] };

    reg[3:0]  brkintfetmajst;   // what major state follows the end-of-instruction major state (or INTAK, or BREAK)
    reg[11:00] brkintfetmadr;   // memory address for brkintfetmajst
    reg brkintfetmakn;          // if brkintfetmadr is valid

    reg saveioacclr, saveioenabd, saveioskip;
    reg[11:00] saveioinbus;

    // calculate accumulator and link for group 1 instruction
    reg[11:00] g1acum, g1acumraw;
    reg g1link, g1linkraw;

    always @(*) begin

        // handle cla, cll, cma, cll, iac bits
        { g1linkraw, g1acumraw } = { (ireg[06] ? 1'b0 : link) ^ ireg[04], (ireg[07] ? 12'b0 : acum) ^ (ireg[05] ? 12'o7777 : 12'o0000) } + { 12'b0, ireg[00] };

        // handle rotate bits
        case (ireg[03:01])

            // bsw
            1: begin
                { g1link, g1acum } = { g1linkraw, g1acumraw[05:00], g1acumraw[11:06] };
            end

            // rol 1
            2: begin
                { g1link, g1acum } = { g1acumraw, g1linkraw };
            end

            // rol 2
            3: begin
                { g1link, g1acum } = { g1acumraw[10:00], g1linkraw, g1acumraw[11] };
            end

            // ror 1
            4: begin
                { g1link, g1acum } = { g1acumraw[00], g1linkraw, g1acumraw[11:01] };
            end

            // ror 2
            5: begin
                { g1link, g1acum } = { g1acumraw[01:00], g1linkraw, g1acumraw[11:02] };
            end

            // all else, nop
            default: begin
                { g1link, g1acum } = { g1linkraw, g1acumraw };
            end
        endcase
    end

    // calculate accumulator and program counter for group 2 instruction

    // - maybe increment PC for skip
    wire[11:00] g2pctr = pctr + { 11'b0, (
                  ((ireg[06] & acum[11]) |    // SMA
                   (ireg[05] & (acum == 0)) | // SZA
                   (ireg[04] & link)) ^       // SNL
                    ireg[03]                  // reverse
        ) };

    // - maybe clear accumulator and/or or in switch register
    //   we don't know sr contents so assume processor did it correctly
    wire[11:00] g2acum = (ireg[07] ? 0 : acum) | (ireg[02] ? oACUM : 0);

    // misc state

    wire[11:00] autoinc = (madr[11:03] == 1) ? 1 : 0;

    // extended arithmetic decoding
    reg ealn, eago;
    reg[11:00] eaac;
    wire extar    = (ireg & 12'o7401) == 12'o7401;
    wire extarnom = extar & (ireg[02:01] == 0); // NOP,NMI
    wire extarmem = extar & (ireg[02:01] != 0); // SCL,MUY,DVI,SHL,ASR,LSR

    // main processing loop

    always @(posedge CLOCK) begin

        // zynq power-on reset
        if (RESET) begin
            clearit  <= 1;
            frzonerr <= 0;
            dfld     <= 0;
            ifaj     <= 0;
            ifld     <= 0;
            saveddf  <= 0;
            savedif  <= 0;
        end

        // arm processor is writing one of the registers
        else if (armwrite) begin
            case (armwaddr)
                1: begin
                    err1     <= armwdata[29:00];
                    clearit  <= armwdata[30];
                    frzonerr <= armwdata[31];
                end

                6: begin
                    err2     <= armwdata[16:12];
                end
            endcase
        end

        // pulse from START switch or reset
        else if (oBUSINI | clearit) begin
            acum        <= oACUM;
            err1        <= 0;
            err2        <= 0;
            eago        <= 0;
            intendly    <= 0;
            intenabd    <= 0;
            intinhuj    <= 0;
            ireg        <= 0;
            lasttp1     <= 0;
            lastts1     <= 0;
            lastts2     <= 0;
            lastts3     <= 0;
            lastts4     <= 0;
            link        <= oLINK;
            majst       <= MS_FETCH;
            maknown     <= 0;
            pcknown     <= 0;
            saveddf     <= 8;
            savedif     <= 8;
            timestate   <= TS_S;
        end

        // keep processing until error detected
        else if (~ error) begin

            // TS1 and TS3 should always have at least 1 cycle gap (more like dozens)
            if ((oTS1 | lastts1) & (oTS3 | lastts3)) begin
                $display ("pdp8ishad: 1.00 oTS1=%b lastts1=%b oTS3=%b lastts3=%b", oTS1, lastts1, oTS3, lastts3);
                err1[00] <= 1;
            end

            // likewise for TS2 and TS4
            if ((oTS2 | lastts2) & (oTS4 | lastts4)) begin
                $display ("pdp8ishad: 1.01 oTS2=%b lastts2=%b oTS4=%b lastts4=%b", oTS2, lastts2, oTS4, lastts4);
                err1[01] <= 1;
            end

            case (timestate)

                // shadowing just started, wait for TS1
                // don't jump in for DEFER,EXEC cuz we don't have ireg,pctr etc
                TS_S: begin
                    if (oTS1) begin
                        if ((oMAJST == MS_FETCH) |
                            (oMAJST == MS_WRDCT) |
                            (oMAJST == MS_BREAK) |
                            (oMAJST == MS_INTAK)) begin
                            majst     <= oMAJST;
                            timestate <= TS_1;
                        end
                        if ((oMAJST == MS_DEPOS) | (oMAJST == MS_EXAM)) begin
                            madr      <= oMADR;
                            ifld      <= 0;     // DFLD,IFLD loaded from switches
                            dfld      <= 0;     // ...but we don't know what the switches are
                            ifaj      <= 0;
                            maknown   <= 1;
                            pctr      <= oMADR;
                            majst     <= oMAJST;
                            pcknown   <= 1;
                            timestate <= TS_1;
                        end
                    end
                end

                // majst = what we expect this cycle major state to be
                // acum,link,madr,pctr = should match what PDP/sim has
                // mbrd,mbwr = garbazhe

                // beginning of new major state
                TS_1: begin
                    if (oTS3 | oTS4) begin
                        $display ("pdp8ishad: 1.02 oTS3=%b oTS4=%b", oTS3, oTS4);
                        err1[02] <= 1;
                    end
                    if (oTS1) begin

                        // wait for extended address bits valid
                        if (oTP1) begin

                            // verify major state is what we expect
                            if (majst != oMAJST) begin
                                $display ("pdp8ishad: 1.03 majst=%x oMAJST=%x", majst, oMAJST);
                                err1[03] <= 1;
                            end

                            // can't be acknowledging interrupt if interrupts disabled
                            if ((majst == MS_INTAK) & (~ intenabd | intinhuj)) begin
                                $display ("pdp8ishad: 1.27 intenabd=%b intinhuj=%b", intenabd, intinhuj);
                                err1[27] <= 1;
                            end

                            // verify extended memory address is what we expect
                            // capture any unknown bits
                            if (~ maknown) begin
                                madr  <= oMADR;
                                maknown <= 1;
                            end else if (madr != oMADR) begin
                                $display ("pdp8ishad: 1.04 majst=%x madr=%o oMADR=%o", majst, madr, oMADR);
                                err1[04] <= 1;
                            end
                            case (majst)
                                MS_FETCH, MS_DEFER, MS_DEPOS, MS_EXAM: begin
                                    if (~ ifld[3]) begin
                                        ifld <= { 1'b1, oMEAD };
                                    end else if (ifld[2:0] != oMEAD) begin
                                        $display ("pdp8ishad: 2.00 majst=%x ifld=%o oMEAD=%o", majst, ifld[2:0], oMEAD);
                                        err2[00] <= 1;
                                    end
                                end
                                MS_EXEC: begin
                                    if (~ ireg[11] & ireg[08]) begin
                                        if (~ dfld[3]) begin
                                            dfld <= { 1'b1, oMEAD };
                                        end else if (dfld[2:0] != oMEAD) begin
                                            $display ("pdp8ishad: 2.01 majst=%x dfld=%o oMEAD=%o", majst, dfld[2:0], oMEAD);
                                            err2[01] <= 1;
                                        end
                                    end else begin
                                        if (~ ifld[3]) begin
                                            ifld <= { 1'b1, oMEAD };
                                        end else if (ifld[2:0] != oMEAD) begin
                                            $display ("pdp8ishad: 2.02 majst=%x ifld=%o oMEAD=%o", majst, ifld[2:0], oMEAD);
                                            err2[02] <= 1;
                                        end
                                    end
                                end
                                MS_INTAK, MS_WRDCT, MS_CURAD: begin
                                    if (oMEAD != 0) begin
                                        $display ("pdp8ishad: 2.03 majst=%x oMEAD=%o", majst, oMEAD);
                                        err2[03] <= 1;
                                    end
                                end
                                MS_BREAK: begin
                                    if (dmagntd & (iDMAFLD != oMEAD)) begin
                                        $display ("pdp8ishad: 2.04 iDMAFLD=%o oMEAD=%o", iDMAFLD, oMEAD);
                                        err2[04] <= 1;
                                    end
                                end
                            endcase
                        end else begin
                            // capture field and data up until posedge TP1
                            // data here always comes from zynq.v externmem chip
                            // - when fpgamemen=1: chip is driving inbus so should make it into real mbuf no matter what
                            // - when fpgamemen=0: real mbuf gets loaded from real extmemory.kicad_sch chips
                            //                     tp1dat here gets loaded from zynq.v externmem chip
                            //                     the two match if previously written since power up
                            tp1fld <= oMEAD;                        // capture field generated by processor
                            tp1dat <= iINBUS;                       // capture memory read data
                            tp1datval <= fpgamemen |                // valid when zynq.v externmem driving INBUS
                                (majst == MS_FETCH) |               // valid during FETCH cycles
                                (majst == MS_DEFER) |               // valid during DEFER cycles
                                (majst == MS_WRDCT) |               // valid during WRDCT cycles
                                (majst == MS_CURAD) |               // valid during CURAD cycles
                                ((majst == MS_BREAK) & ~ iBRKWRM) | // valid during BREAK read cycles
                                ((majst == MS_EXEC) &               // valid during EXEC when not DCA,JMS
                                    (ireg[11:09] != 3) & (ireg[11:09] != 4));
                        end
                    end else if (oTS2) begin

                        // make sure the processor latched the correct value in oMBUF
                        if (tp1datval & (oMBUF != tp1dat)) begin
                            $display ("pdp8ishad: 1.29 majst=%x oMADR=%o.%o oMBUF=%o iINBUS=%o", majst, oMEAD, oMADR, oMBUF, tp1dat);
                            err1[29] <= 1;
                        end

                        // if read from (PC)+, increment PC
                        if ((majst == MS_FETCH) | ((majst == MS_EXEC) & extar)) begin
                            if (~ pcknown) pcknown <= 1;
                            else if (oMADR != pctr) begin
                                $display ("pdp8ishad: 1.05 pctr=%o oMADR=%o", pctr, oMADR);
                                err1[05] <= 1;
                            end
                            pctr  <= oMADR + 1;
                        end

                        // if fetch, save 12-bit opcode in ireg
                        // also update delayed interrupt enable
                        if (majst == MS_FETCH) begin
                            intenabd <= intendly;
                            ireg     <= oMBUF;
                        end

                        // if intak, save ifld,dfld
                        if (majst == MS_INTAK) begin
                            saveddf <= dfld;
                            savedif <= ifld;
                        end

                        // in any case, save value read from memory
                        mbrd      <= oMBUF;

                        timestate <= TS_2;
                    end
                end

                //  oMEAD,oMADR = memory address for this cycle
                // mbrd = oMBUF = value read from that location
                // ireg loaded from oMBUF at end of TS1 if FETCH cycle

                TS_2: begin
                    if (oTS1 | oTS4) begin
                        $display ("pdp8ishad: 1.06 oTS1=%b oTS4=%b", oTS1, oTS4);
                        err1[06] <= 1;
                    end
                    if (~ oTS2) begin
                        if (((majst == MS_FETCH) & (ireg[11:09] == 6)) ^ oIOP) begin
                            $display ("pdp8ishad: 1.07 majst=%x ireg=%o oIOP=%b", majst, ireg, oIOP);
                            err1[07] <= 1;
                        end
                        if (oTS3) begin
                            eago      <= 0;
                            timestate <= TS_3;
                        end
                    end
                end

                //  mbrd = value what was read from memory
                // oMBUF = value to be written back to memory

                TS_3: begin
                    if (oTS1 | oTS2) begin
                        $display ("pdp8ishad: 1.08 oTS1=%b oTS2=%b", oTS1, oTS2);
                        err1[08] <= 1;
                    end
                    if (oTS3) begin

                        // processor clocks in io signals at TP3
                        // so save io signals during TS3 until TP3
                        if (~ oTP3) begin
                            saveioenabd <= ioenabd;
                            saveioacclr <= iACCLEAR;
                            saveioskip  <= iIOSKIP;
                            saveioinbus <= iINBUS;
                        end

                        // field and address persist from TS1 through TS3
                        if ({ tp1fld, madr } != { oMEAD, oMADR }) begin
                            $display ("pdp8ishad: 1.28 majst=%x madr sb %o.%o but is %o.%o", majst, tp1fld, madr, oMEAD, oMADR);
                            err1[28] <= 1;
                        end

                        // MBUF gets loaded at end of TS2 with value to be written to memory
                        // verify its contents

                        case (majst)
                            MS_FETCH: begin
                                if (oMBUF != mbrd) begin
                                    $display ("pdp8ishad: 1.09 oMBUF=%o mbrd=%o", oMBUF, mbrd);
                                    err1[09] <= 1;
                                end
                                // start extarith for non-memory opcodes (NOP,NMI)
                                eago <= extarnom;
                            end
                            MS_DEFER: begin
                                if (oMBUF != mbrd + autoinc) begin
                                    $display ("pdp8ishad: 1.10 oMBUF=%o mbrd=%o autoinc=%o", oMBUF, mbrd, autoinc);
                                    err1[10] <= 1;
                                end
                            end
                            MS_EXEC: begin
                                case (ireg[11:09])
                                    2: begin    // ISZ
                                        if (oMBUF != mbrd + 12'b1) begin
                                            $display ("pdp8ishad: 1.11 oMBUF=%o mbrd=%o", oMBUF, mbrd);
                                            err1[11] <= 1;
                                        end
                                    end
                                    3: begin    // DCA
                                        if (oMBUF != acum) begin
                                            $display ("pdp8ishad: 1.12 oMBUF=%o acum=%o", oMBUF, acum);
                                            err1[12] <= 1;
                                        end
                                    end
                                    4: begin    // JMS
                                        if (pcknown & (oMBUF != pctr)) begin
                                            $display ("pdp8ishad: 1.13 oMBUF=%o pctr=%o", oMBUF, pctr);
                                            err1[13] <= 1;
                                        end
                                    end
                                    7: begin    // OPR (only OPRs using EXEC should be extarith with memory operand)
                                        // start extarith for memory opcodes (SCL,MUY,DVI,SHL,ASR,LSR)
                                        eago <= extarmem;
                                    end
                                    default: begin
                                        if (oMBUF != mbrd) begin
                                            $display ("pdp8ishad: 1.14 oMBUF=%o mbrd=%o", oMBUF, mbrd);
                                            err1[14] <= 1;
                                        end
                                    end
                                endcase
                            end
                            MS_WRDCT: begin
                                if (oMBUF != mbrd + 12'b1) begin
                                    $display ("pdp8ishad: 1.15 oMBUF=%o mbrd=%o", oMBUF, mbrd);
                                    err1[15] <= 1;
                                end
                            end
                            MS_CURAD: begin
                                if (dmagntd) begin
                                    if (oMBUF != mbrd + { 11'b0, iCAINC }) begin
                                        $display ("pdp8ishad: 1.16 oMBUF=%o mbrd=%o iCAINC=%b", oMBUF, mbrd, iCAINC);
                                        err1[16] <= 1;
                                    end
                                end else begin
                                    if ((oMBUF != mbrd) & (oMBUF != mbrd + 12'b1)) begin
                                        $display ("pdp8ishad: 1.26 oMBUF=%o mbrd=%o", oMBUF, mbrd);
                                        err1[26] <= 1;
                                    end
                                end
                            end
                            MS_INTAK: begin
                                if (pcknown & (oMBUF != pctr)) begin
                                    $display ("pdp8ishad: 1.17 oMBUF=%o pctr=%o", oMBUF, pctr);
                                    err1[17] <= 1;
                                end
                            end
                            MS_EXAM: begin
                                if (oMBUF != mbrd) begin
                                    $display ("pdp8ishad: 1.18 oMBUF=%o mbrd=%o", oMBUF, mbrd);
                                    err1[18] <= 1;
                                end
                            end
                        endcase
                        mbwr <= oMBUF;
                    end else if (oTS4) begin

                        // end of TS3, update what AC, LINK and PC should be at this point
                        case (majst)

                            // FETCH:
                            //  direct JMS: set up to write return address in new field
                            //  direct JMP: sets PC = effective address in new field
                            //   (indirect JMP sets PC in DEFER cycle)
                            //  IOT: updates to AC, PC
                            //  OPR: update AC, LINK, PC from opcode
                            MS_FETCH: begin
                                case (ireg[11:09])
                                    4: begin    // JMS
                                        intinhuj <= 0;
                                        if (~ ireg[08]) begin
                                            ifld <= ifaj;
                                        end
                                    end
                                    5: begin    // JMP
                                        intinhuj <= 0;
                                        if (~ ireg[08]) begin
                                            ifld <= ifaj;
                                            pctr <= eadr;
                                        end
                                    end
                                    6: begin    // IOT
                                        if (ireg[08:00] == 9'o001) begin                // 6001 ION
                                            intendly <= 1;
                                            saveioenabd <= 1;
                                            saveioskip  <= 0;
                                        end else if (ireg[08:00] == 9'o002) begin       // 6002 IOF
                                            intenabd <= 0;
                                            intendly <= 0;
                                            saveioenabd <= 1;
                                            saveioskip  <= 0;
                                        end else if (ireg[08:06] == 3'o2) begin
                                            if (ireg[00]) begin                         // 62n1 CDFn
                                                dfld <= { 1'b1, ireg[05:03] };
                                            end
                                            if (ireg[01]) begin                         // 62n2 CIFn
                                                ifaj <= { 1'b1, ireg[05:03] };
                                                intinhuj <= 1;
                                            end
                                            if ((ireg[05:00] & 6'o37) == 6'o14) begin   // 6214 RDF
                                                // if dfld known, calc what acum should be
                                                // otherwise, get what processor is saying
                                                acum[05:03] <= acum[05:03] | (dfld[3] ? dfld[2:0] : oACUM[05:03]);
                                            end
                                            if ((ireg[05:00] & 6'o37) == 6'o24) begin   // 6224 RIF
                                                // if ifld known, calc what acum should be
                                                // otherwise, get what processor is saying
                                                acum[05:03] <= acum[05:03] | (ifld[3] ? ifld[2:0] : oACUM[05:03]);
                                            end
                                            if ((ireg[05:00] & 6'o37) == 6'o34) begin   // 6234 RIB
                                                // if saved fields known, calc what acum should be
                                                // otherwise, get what processor is saying
                                                acum[05:00] <= acum[05:00] |
                                                        (savedif[3] & saveddf[3] ? { savedif[2:0], saveddf[2:0] } : oACUM[05:00]);
                                            end
                                            if ((ireg[05:00] & 6'o47) == 6'o44) begin   // 6244 RIF
                                                dfld <= saveddf;
                                                ifaj <= savedif;
                                            end
                                            saveioenabd <= 1;
                                            saveioskip  <= 0;
                                        end else begin
                                            if (saveioenabd) begin
                                                // fpga internal device, we can calculate what processor should have done
                                                acum <= (saveioacclr ? 12'b0 : acum) | saveioinbus;
                                            end else begin
                                                // external to fpga, we assume processor calculated correctly
                                                acum <= oACUM;
                                            end
                                        end
                                    end
                                    7: begin    // OPR
                                        if (~ ireg[08]) begin
                                            acum <= g1acum;
                                            link <= g1link;
                                        end else if (~ ireg[00]) begin
                                            acum <= g2acum;
                                            pctr <= g2pctr;
                                        end else if (extarnom) begin
                                            if (extarstep != 0) begin
                                                $display ("pdp8ishad: 1.22 extarstep=%o sctr=%o", extarstep, sctr);
                                                err1[22] <= 1;
                                            end
                                            eago <= 0;
                                            acum <= eaac;
                                            link <= ealn;
                                        end
                                    end
                                endcase
                            end

                            // DEFER:
                            //  indirect JMS: pointer was read using old ifld
                            //                set up to write return address to new ifld
                            //  indirect JMP: pointer was read using old ifld
                            //                jump to new ifld
                            MS_DEFER: begin
                                if (ireg[11:10] == 2) begin // JMS,JMP
                                    ifld <= ifaj;
                                end
                                if (ireg[11:09] == 5) begin // JMP
                                    pctr <= mbwr;
                                end
                            end

                            // EXEC:
                            //  AND,TAD,DCA: update according to opcode
                            //  ISZ: maybe increment PC
                            //  JMS: return address has been written to new field; PC = MA + 1
                            MS_EXEC: begin
                                case (ireg[11:09])
                                    0: begin    // AND
                                        acum <= acum & mbrd;
                                    end
                                    1: begin    // TAD
                                        { link, acum } <= { link, acum } + { 1'b0, mbrd };
                                    end
                                    2: begin    // ISZ
                                        if (mbwr == 0) pctr <= pctr + 1;
                                    end
                                    3: begin    // DCA
                                        acum <= 0;
                                    end
                                    4: begin    // JMS
                                        pctr <= madr + 1;
                                    end
                                    7: begin    // OPR
                                        if (extarmem) begin
                                            if (extarstep != 0) begin
                                                $display ("pdp8ishad: 1.25 extarstep=%o sctr=%o", extarstep, sctr);
                                                err1[25] <= 1;
                                            end
                                            eago <= 0;
                                            acum <= eaac;
                                            link <= ealn;
                                        end
                                    end
                                endcase
                            end
                        endcase

                        // TS4 is next
                        timestate <= TS_4;
                    end
                end

                // processor is doing TS4 - computing next major state and extended memory address
                TS_4: begin
                    if (oTS2 | oTS3) begin
                        $display ("pdp8ishad: 1.19 oTS2=%b oTS3=%b", oTS2, oTS3);
                        err1[19] <= 1;
                    end

                    if (oTS4) begin

                        // verify changes made at TP3
                        if ((oACUM != acum) | (oLINK != link)) begin
                            $display ("pdp8ishad: 1.20 ireg=%o majst=%x oLINK.ACUM=%b.%o link.acum=%b.%o", ireg, majst, oLINK, oACUM, link, acum);
                            err1[20] <= 1;
                        end

                        // compute what next major state and memory address should be
                        // ...assuming currently at end-of-instruction state
                        if (dmagntd) begin
                            // something in zynq.v has been granted the dma bus so the dma signals are known
                            brkintfetmajst <= iCYCLE3 ? MS_WRDCT : MS_BREAK;
                            brkintfetmadr  <= iINBUS;
                            brkintfetmakn  <= 1;
                        end else begin
                            // something else might be granted the dma bus so the dma signals are unknown
                            // we will assume the procesor is doing the right thing
                            case (oMAJST)
                                MS_INTAK: begin
                                    brkintfetmajst <= MS_INTAK;
                                    brkintfetmadr  <= 12'o0000;
                                    brkintfetmakn  <= 1;
                                end
                                MS_WRDCT: begin
                                    brkintfetmajst <= MS_WRDCT;
                                    brkintfetmadr  <= oMADR;
                                    brkintfetmakn  <= 1;
                                end
                                MS_BREAK: begin
                                    brkintfetmajst <= MS_BREAK;
                                    brkintfetmakn  <= 0;
                                end
                                default: begin
                                    brkintfetmajst <= MS_FETCH;
                                    brkintfetmadr  <= pcknown ? pctr : oMADR;
                                    brkintfetmakn  <= 1;
                                end
                            endcase
                        end
                    end

                    // check for processor either halted or started TS1 of the next major state
                    else if (~ oRUN | oTS1) begin

                        // compute what next major state and memory address should be
                        case (majst)

                            // just completed fetching an instruction
                            MS_FETCH: begin
                                case (ireg[11:09])
                                    0,1,2,3,4: begin                    // AND,TAD,ISZ,DCA,JMS
                                        madr  <= eadr;                  // for direct JMS, ifld already updated from ifaj at end of TS3
                                                                        //                 ...so return address gets written to new ifld
                                                                        // for indirect JMS, ifld still old value
                                                                        //                 ...so pointer gets read from old ifld
                                        majst <= ireg[08] ? MS_DEFER : MS_EXEC;
                                    end
                                    5: begin                            // JMP
                                        if (ireg[08]) begin
                                            madr  <= eadr;              // indirect JMP, DEFER cycle reads from eadr in old ifld
                                            majst <= MS_DEFER;          // ...still using old ifld so pointer gets read from old ifld
                                        end else begin
                                                                        // direct JMP, PC and IF were updated at end of TS3
                                            madr    <= (brkintfetmajst == MS_FETCH) ? eadr : brkintfetmadr;
                                            maknown <= (brkintfetmajst == MS_FETCH) ? 1    : brkintfetmakn;
                                            majst   <= brkintfetmajst;
                                        end
                                    end
                                    6: begin                            // IOT
                                        if (saveioenabd) begin
                                            // fpga internal device, we can calculate what processor should have done
                                            madr    <= (brkintfetmajst == MS_FETCH) ? pctr + { 11'b0, saveioskip } : brkintfetmadr;
                                            maknown <= (brkintfetmajst == MS_FETCH) ? 1 : brkintfetmakn;
                                            pctr    <= pctr + { 11'b0, saveioskip };
                                        end else begin
                                            // external to fpga, we assume processor calculated correctly
                                            if (brkintfetmajst == MS_FETCH) begin
                                                // fetch is next, address should be PC (no IOSKIP) or PC+1 (with IOSKIP)
                                                if ((oMEAD != ifld[2:0]) | ((oMADR != pctr) & (oMADR != pctr + 12'b1))) begin
                                                    $display ("pdp8ishad: 1.21 oMEAD,oMADR=%o%o ifld,pctr=%o%o", oMEAD, oMADR, ifld, pctr);
                                                    err1[21] <= 1;
                                                end
                                                madr <= oMADR;
                                                pctr <= oMADR;
                                            end else begin
                                                // don't know if PC was incremented or not
                                                pcknown <= 0;
                                                madr    <= brkintfetmadr;
                                                maknown <= brkintfetmakn;
                                            end
                                        end
                                        majst <= brkintfetmajst;
                                    end
                                    7: begin
                                        // if HLT instruction, make sure it halted
                                        if (((ireg[08:00] & 9'o403) == 9'o402) & oTS1) begin
                                            $display ("pdp8ishad: 1.23 ireg=%o oTS1=%b", ireg, oTS1);
                                            err1[23] <= 1;
                                        end

                                        // extarith with memory operand goes to EXEC state next
                                        // otherwise go to BREAK/INTAK/FETCH next
                                        if (extarmem) begin
                                            madr    <= pctr;
                                            majst   <= MS_EXEC;
                                        end else begin
                                            madr    <= brkintfetmadr;
                                            maknown <= brkintfetmakn;
                                            majst   <= brkintfetmajst;
                                        end
                                    end
                                endcase
                            end

                            // just completed reading the pointer (and maybe writing auto-incd pointer back)
                            MS_DEFER: begin
                                madr    <= (ireg[11:09] == 5) ? brkintfetmadr  : mbwr;
                                maknown <= (ireg[11:09] == 5) ? brkintfetmakn  : 1;
                                majst   <= (ireg[11:09] == 5) ? brkintfetmajst : MS_EXEC;
                            end

                            // just completed executing the instruction
                            MS_EXEC: begin
                                madr    <= brkintfetmadr;
                                maknown <= brkintfetmakn;
                                majst   <= brkintfetmajst;
                            end

                            // just completed incrementing the word count
                            // current address is next sequential address
                            MS_WRDCT: begin
                                madr  <= madr + 1;
                                majst <= MS_CURAD;
                            end

                            // just completed possibly incrementing the current address
                            MS_CURAD: begin
                                madr    <= mbwr;
                                maknown <= 1;
                                majst   <= MS_BREAK;
                            end

                            // just completed reading/writing memory on behalf of io device
                            MS_BREAK: begin
                                if ((brkintfetmajst == MS_FETCH) & ~ pcknown) begin
                                    madr    <= oMADR;
                                    maknown <= 1;
                                    pctr    <= oMADR;
                                    pcknown <= 1;
                                end else begin
                                    madr    <= brkintfetmadr;
                                    maknown <= brkintfetmakn;
                                end
                                majst <= brkintfetmajst;
                            end

                            // just completed writing pc to 00000 and disabling interrupts etc
                            MS_INTAK: begin
                                madr    <= (brkintfetmajst == MS_FETCH) ? 12'o0001 : brkintfetmadr;
                                maknown <= (brkintfetmajst == MS_FETCH) ? 1 : brkintfetmakn;
                                dfld    <= 8;       // DFLD,IFLD now known to be 0
                                ifaj    <= 8;
                                ifld    <= 8;
                                pctr    <= 1;
                                pcknown <= 1;
                                majst   <= brkintfetmajst;
                            end

                            // just finished accessing memory on behalf of console
                            // processor should halt and not enter TS1 until some other button pressed
                            MS_DEPOS, MS_EXAM: begin
                                if (oTS1) begin
                                    $display ("pdp8ishad: 1.24");
                                    err1[24] <= 1;
                                end
                            end
                        endcase
                        timestate <= oTS1 ? TS_1 : TS_H;
                    end
                end

                // halted with shadow context intact, wait for TS1
                // CONT switch should resume exactly where it left off
                // DEPOS,EXAM,LDAD switches mess the state up
                TS_H: begin
                    if (oTS1) begin
                        if ((oMAJST == MS_DEPOS) | (oMAJST == MS_EXAM)) begin
                            madr    <= oMADR;
                            dfld    <= 0;       // DFLD,IFLD loaded from switches
                            ifaj    <= 0;       // ...but we don't know what the switches are
                            ifld    <= 0;
                            pctr    <= oMADR;
                            majst   <= oMAJST;
                            maknown <= 1;
                            pcknown <= 1;
                        end
                        // if previous depos/exam cycle, next state could be anything
                        // so trust processor is doing the right thing
                        else if ((majst == MS_DEPOS) | (majst == MS_EXAM)) begin
                            majst <= oMAJST;
                        end
                        // in any case, start shadowing again
                        timestate <= TS_1;
                    end
                end
            endcase

            // time strobe edge detect
            lasttp1 <= oTP1;
            lastts1 <= oTS1;
            lastts2 <= oTS2;
            lastts3 <= oTS3;
            lastts4 <= oTS4;
        end
    end

    // process extended arithmetic
    // called every 10nS durint TS3 to step state when processing extended arithmetic opcode
    //  input:
    //   extarnom = set iff no-memory extarith opcode (NOP, NMI)
    //   extarmem = set iff memory extarith opcode (SCL, MUY, DVI, SHL, ASR, LSR)
    //   extarstep = starts at 1 for first call of the opcode
    //   acum,ireg,link,mquo,sctr = processor registers
    //   mbrd = value read from memory for SCL,MUY,DVI,SHL,ASR,LSR
    //  output:
    //   eaac,ealn,mquo,sctr = possibly updated
    //   extarstep = possibly incremented

    // PDP-8/I small computer handbook 1970
    // pages 57..63
    // also small computer handbook 1973 mode A (says it's 8/I compatible)

    // normalize is done
    wire nmidone = (eaac[11] != eaac[10]) | (eaac[09:00] == 0) & (mquo == 0);

    // memory operand for SCL,MUY,DVI,SHL,ASR,LSR
    wire[11:00] yreg = mbrd;

    // each step in multiply
    wire muymbit = mquo[00];    // set means add yreg to shifted product in eaac,mquo
    wire[11:00] muyacstep, muymqstep;
    assign { muyacstep, muymqstep[11] } = { 1'b0, eaac } + { 1'b0, muymbit ? yreg : 12'b0 };
    assign muymqstep[10:00] = mquo[11:01];

    wire _dviqbit, dviover;
    wire[11:00] dviacstep;
    assign { _dviqbit, dviover, dviacstep } = { 1'b0, eaac, mquo[11] } - { 2'b0, yreg };
    wire[11:00] dvimqstep = { mquo[10:00], ~ _dviqbit };   // shift quotient bit into bottom of MQ

    wire[11:00] step2eaac = (ireg[04] ? 0 : eaac) |             // MQL - clear accumulator after loading into MQUO
                            (ireg[05] ? { 7'b0, sctr } : 0) |   // SCA - step counter load into accumulator
                            (ireg[06] ? mquo : 0);              // MQA - multiplier/quotient load into accumulator

    always @(posedge CLOCK) begin
        if (~ eago) begin
            if (oBUSINI) begin
                mquo <= 0;
                sctr <= 0;
            end
            extarstep <= 1;
        end else case (extarstep)

            // step 1
            1: begin
                eaac <= ireg[07] ? 0 : acum;                    // CLA
                ealn <= link;
                extarstep <= 2;
            end

            // step 2
            2: begin
                if (ireg[04]) mquo <= eaac;                     // MQL - load multiplier/quotient from accumulator
                eaac <= step2eaac;
                case (ireg[03:01])
                    2: begin                                    // MUY
                        ealn <= 0;
                        sctr <= -11;
                    end
                    3: begin                                    // DVI
                        ealn <= step2eaac >= yreg;
                        sctr <= -11;
                    end
                    4: begin                                    // NMI
                        sctr <= 0;
                    end
                    1,5,6,7: begin                              // SCL,SHL,ASR,LSR
                        sctr <= ~ yreg[4:0];
                    end
                endcase
                extarstep <= 3;
            end

            // step 3
            3: begin
                case (ireg[03:01])
                    0,1: begin                          // NOP,SCL
                        extarstep <= 0;                 // - done
                    end
                    2: begin                            // MUY
                        eaac <= muyacstep;
                        mquo <= muymqstep;
                        if (sctr == 0) extarstep <= 0;
                        else sctr <= sctr + 1;
                    end
                    3: begin                            // DVI
                        eaac <= _dviqbit ? { eaac[10:00], mquo[11] } : dviacstep;
                        mquo <= dvimqstep;
                        if (ealn | (sctr == 0)) extarstep <= 0;
                        else sctr <= sctr + 1;
                    end
                    4: begin                            // NMI
                        if (nmidone) extarstep <= 0;
                        else begin
                            { ealn, eaac, mquo } <= { eaac, mquo, 1'b0 };
                            sctr <= sctr + 1;
                        end
                    end
                    5: begin                            // SHL
                        { ealn, eaac, mquo } <= { eaac, mquo, 1'b0 };
                        if (sctr == 5'o37) extarstep <= 0;
                        sctr <= sctr + 1;
                    end
                    6: begin                            // ASR
                        { ealn, eaac, mquo } <= { eaac[11], eaac[11], eaac, mquo[11:01] };
                        if (sctr == 5'o37) extarstep <= 0;
                        sctr <= sctr + 1;
                    end
                    7: begin                            // LSR
                        { ealn, eaac, mquo } <= { 2'b0, eaac, mquo[11:01] };
                        if (sctr == 5'o37) extarstep <= 0;
                        sctr <= sctr + 1;
                    end
                endcase
            end
        endcase
    end
endmodule
