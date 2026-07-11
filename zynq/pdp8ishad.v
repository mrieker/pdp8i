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

module pdp8ishad (
    input CLOCK, RESET,  // fpga 100MHz clock and reset

    input armwrite,
    input[2:0] armraddr, armwaddr,
    input[31:00] armwdata,
    output[31:00] armrdata,

    // all signals coming in from the bus
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

    // fpga outputs these signals conditionally
    // otherwise we do not know their state on the bus
    input        dmagntd,  // enable the dma cycle inputs
    input        iBRKWRM,  // [dmagntd]
    input        iCAINC,   // [dmagntd]
    input        iCYCLE3,  // [dmagntd]
    input[2:0]   iDMAFLD,  // [dmagntd]

    input        ioenabd,  // my io cycle | dma granted & TS4 | dma granted & BRKCYC & TS2 | memdis & TS1
    input        iACCLEAR, // [ioenabd]
    input[11:00] iINBUS,   // [ioenabd]
    input        iIOSKIP,  // [ioenabd]

    input        poweron,  // enable the 'always on' and 'open collector' inputs
    input        iCLOCK,   // [poweron]
    input        iMEMDIS,  // [poweron]
    input        iRESET,   // [poweron]
    input        iBRKRQST, // [poweron] open collector
    input        iINTRQST, // [poweron] open collector
    input        iPAUSE,   // [poweron] open collector

    // stop clocking processor
    output freeze
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

    localparam TS_H =  0;       // halted, shadow context valid
    localparam TS_1 =  1;       // read memory (EA sampled at posedge TS1)
                                // - TP1: sample BRK_RQST; inc PC (FETCH); clear ADDR_ACCEPT
    localparam TS_2 =  2;       // compute update to memory
                                // - TP2: load IR (FETCH); load MB; load WC_OVERFLOW
    localparam TS_3 =  3;       // write memory, update registers
                                // - TP3: load L,AC (AND,TAD,DCA,OPR); load PC (jumps, skips); sample INT_RQST
    localparam TS_4 =  4;       // determine next state
                                // - TP4: set IR=4 (INTAK next); load F,D,E,WC,CA,B; load MA; load ADDR_ACCEPT (BREAK)
    localparam TS_S =  5;       // startup, shadow context invalid

    reg maknown, pcknown, frzonerr;
    reg[11:00] acum, ireg, madr, mquo, mred, mwbk, pctr;
    reg[26:00] err;
    reg[4:0] sctr;
    reg[3:0] majst, timestate;
    reg[1:0] savedioskip;
    reg clearit, link;

    wire error = (err != 0);
    assign freeze = error & frzonerr;

    assign armrdata = (armraddr == 0) ? 32'h53482002 : // [31:16] = 'SH'; [15:12] = (log2 nreg) - 1; [11:00] = version
                      (armraddr == 1) ? { frzonerr, clearit, maknown, pcknown, 1'b0, err } :
                      (armraddr == 2) ? { majst, timestate, ireg, pctr } :
                      (armraddr == 3) ? { 8'b0, mred, madr } :
                      (armraddr == 4) ? { 7'b0, mwbk, link, acum } :
                      (armraddr == 5) ? { 15'b0, sctr, mquo } :
                      32'hDEADBEEF;

    wire [11:00] eadr = { mred[07] ? madr[11:07] : 5'b0, mred[06:00] };

    reg[3:0]  brkintfetmajst;
    reg[11:00] brkintfetmadr;

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
    wire[11:00] g2pctr = pctr + { 10'b0, (
                  ((ireg[06] & acum[11]) |    // SMA
                   (ireg[05] & (acum == 0)) | // SZA
                   (ireg[04] & link)) ^       // SNL
                    ireg[03]                  // reverse
        ) };

    // - maybe clear accumulator and/or or in switch register
    wire[11:00] g2acum = (ireg[07] ? 0 : acum) | (ireg[02] ? oACUM : 0);

    // misc state

    reg lasttp1, lastts1, lastts2, lastts3, lastts4;

    wire[11:00] autoinc = (madr[11:03] == 1) ? 1 : 0;

    // extended arithmetic decoding
    reg ealn, eago;
    reg[11:00] eaac;
    reg[1:0] extarstep;
    wire extar    = (ireg & 12'o7401) == 12'o7401;
    wire extarnom = extar & (ireg[02:01] == 0); // NOP,NMI
    wire extarmem = extar & (ireg[02:01] != 0); // SCL,MUY,DVI,SHL,ASR,LSR

    // main processing loop

    always @(posedge CLOCK) begin

        // zynq power-on reset
        if (RESET) begin
            clearit  <= 1;
            frzonerr <= 0;
        end

        // arm processor is writing one of the registers
        else if (armwrite) begin
            case (armwaddr)
                1: begin
                    err   <= armwdata[26:00];
                    clearit  <= armwdata[30];
                    frzonerr <= armwdata[31];
                end
            endcase
        end

        // pulse from START switch or reset
        else if (oBUSINI | clearit) begin
            acum        <= oACUM;
            err         <= 0;
            eago        <= 0;
            ireg        <= 0;
            lasttp1     <= 0;
            lastts1     <= 0;
            lastts2     <= 0;
            lastts3     <= 0;
            lastts4     <= 0;
            link        <= oLINK;
            maknown     <= 0;
            majst       <= MS_FETCH;
            pcknown     <= 0;
            timestate   <= TS_S;
        end

        // keep processing until error detected
        else if (~ error) begin

            // TS1 and TS3 should always have at least 1 cycle gap (more like dozens)
            if ((oTS1 | lastts1) & (oTS3 | lastts3)) begin
                $display ("pdp8ishad: 00 oTS1=%b lastts1=%b oTS3=%b lastts3=%b", oTS1, lastts1, oTS3, lastts3);
                err[00] <= 1;
            end

            // likewise for TS2 and TS4
            if ((oTS2 | lastts2) & (oTS4 | lastts4)) begin
                $display ("pdp8ishad: 01 oTS2=%b lastts2=%b oTS4=%b lastts4=%b", oTS2, lastts2, oTS4, lastts4);
                err[01] <= 1;
            end

            case (timestate)

                // halted or shadowing just started, wait for TS1
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
                            pctr      <= oMADR;
                            majst     <= oMAJST;
                            maknown   <= 1;
                            pcknown   <= 1;
                            timestate <= TS_1;
                        end
                    end
                end

                // majst = what we expect this cycle major state to be
                // acum,link,madr,pctr = should match what PDP/sim has
                // mred,mwbk = garbazhe

                // beginning of new major state
                TS_1: begin
                    if (oTS3 | oTS4) begin
                        $display ("pdp8ishad: 02 oTS3=%b oTS4=%b", oTS3, oTS4);
                        err[02] <= 1;
                    end
                    if (oTS1) begin

                        if (oTP1) begin

                            // verify major state is what we expect
                            if (majst != oMAJST) begin
                                $display ("pdp8ishad: 03 majst=%x oMAJST=%x", majst, oMAJST);
                                err[03] <= 1;
                            end

                            // verify memory address is what we expect
                            // ...but capture it if unknown
                            if (~ maknown) madr <= oMADR;
                            else if (madr != oMADR) begin
                                $display ("pdp8ishad: 04 madr=%o oMADR=%o", madr, oMADR);
                                err[04] <= 1;
                            end
                            maknown <= 1;
                        end
                    end else if (oTS2) begin

                        // if read from (PC)+, increment PC
                        if ((majst == MS_FETCH) | ((majst == MS_EXEC) & extar)) begin
                            if (~ pcknown) pcknown <= 1;
                            else if (oMADR != pctr) begin
                                $display ("pdp8ishad: 05 pctr=%o oMADR=%o", pctr, oMADR);
                                err[05] <= 1;
                            end
                            pctr  <= oMADR + 1;
                        end

                        // if fetch, save opcode in ireg
                        if (majst == MS_FETCH) begin
                            ireg  <= oMBUF;
                        end

                        // in any case, save value read from memory
                        mred      <= oMBUF;

                        timestate <= TS_2;
                    end
                end

                //  oMEAD,oMADR = memory address for this cycle
                // mred = oMBUF = value read from that location
                // ireg loaded from oMBUF at end of TS1 if FETCH cycle

                TS_2: begin
                    if (oTS1 | oTS4) begin
                        $display ("pdp8ishad: 06 oTS1=%b oTS4=%b", oTS1, oTS4);
                        err[06] <= 1;
                    end
                    if (~ oTS2) begin
                        if (((majst == MS_FETCH) & (ireg[11:09] == 6)) ^ oIOP) begin
                            $display ("pdp8ishad: 07 majst=%x ireg=%o oIOP=%b", majst, ireg, oIOP);
                            err[07] <= 1;
                        end
                        if (oTS3) begin
                            eago      <= 0;
                            timestate <= TS_3;
                        end
                    end
                end

                //  mred = value what was read from memory
                // oMBUF = value to be written back to memory

                TS_3: begin
                    if (oTS1 | oTS2) begin
                        $display ("pdp8ishad: 08 oTS1=%b oTS2=%b", oTS1, oTS2);
                        err[08] <= 1;
                    end
                    if (oTS3) begin

                        if (~ oTP3) begin
                            saveioenabd <= ioenabd;
                            saveioacclr <= iACCLEAR;
                            saveioskip  <= iIOSKIP;
                            saveioinbus <= iINBUS;
                        end

                        // MBUF gets loaded at end of TS2 with value to be written to memory
                        // verify its contents

                        case (majst)
                            MS_FETCH: begin
                                if (oMBUF != mred) begin
                                    $display ("pdp8ishad: 09 oMBUF=%o mred=%o", oMBUF, mred);
                                    err[09] <= 1;
                                end
                                // start extarith for non-memory opcodes (NOP,NMI)
                                eago <= extarnom;
                            end
                            MS_DEFER: begin
                                if (oMBUF != mred + autoinc) begin
                                    $display ("pdp8ishad: 10 oMBUF=%o mred=%o autoinc=%o", oMBUF, mred, autoinc);
                                    err[10] <= 1;
                                end
                            end
                            MS_EXEC: begin
                                case (ireg[11:09])
                                    2: begin    // ISZ
                                        if (oMBUF != mred + 12'b1) begin
                                            $display ("pdp8ishad: 11 oMBUF=%o mred=%o", oMBUF, mred);
                                            err[11] <= 1;
                                        end
                                    end
                                    3: begin    // DCA
                                        if (oMBUF != acum) begin
                                            $display ("pdp8ishad: 12 oMBUF=%o acum=%o", oMBUF, acum);
                                            err[12] <= 1;
                                        end
                                    end
                                    4: begin    // JMS
                                        if (~ pcknown) begin
                                            pcknown <= 1;
                                            pctr <= oMBUF;
                                        end else begin
                                            if (oMBUF != pctr) begin
                                                $display ("pdp8ishad: 13 oMBUF=%o pctr=%o", oMBUF, pctr);
                                                err[13] <= 1;
                                            end
                                        end
                                    end
                                    7: begin    // OPR (only OPRs using EXEC should be extarith with memory operand)
                                        // start extarith for memory opcodes (SCL,MUY,DVI,SHL,ASR,LSR)
                                        eago <= extarmem;
                                    end
                                    default: begin
                                        if (oMBUF != mred) begin
                                            $display ("pdp8ishad: 14 oMBUF=%o mred=%o", oMBUF, mred);
                                            err[14] <= 1;
                                        end
                                    end
                                endcase
                            end
                            MS_WRDCT: begin
                                if (oMBUF != mred + 12'b1) begin
                                    $display ("pdp8ishad: 15 oMBUF=%o mred=%o", oMBUF, mred);
                                    err[15] <= 1;
                                end
                            end
                            MS_CURAD: begin
                                if (dmagntd) begin
                                    if (oMBUF != mred + { 11'b0, iCAINC }) begin
                                        $display ("pdp8ishad: 16 oMBUF=%o mred=%o iCAINC=%b", oMBUF, mred, iCAINC);
                                        err[16] <= 1;
                                    end
                                end else begin
                                    if ((oMBUF != mred) & (oMBUF != mred + 12'b1)) begin
                                        $display ("pdp8ishad: 26 oMBUF=%o mred=%o", oMBUF, mred);
                                        err[26] <= 1;
                                    end
                                end
                            end
                            MS_INTAK: begin
                                if (~ pcknown) begin
                                    pcknown <= 1;
                                    pctr <= oMBUF;
                                end else begin
                                    if (oMBUF != pctr) begin
                                        $display ("pdp8ishad: 17 oMBUF=%o pctr=%o", oMBUF, pctr);
                                        err[17] <= 1;
                                    end
                                end
                            end
                            MS_EXAM: begin
                                if (oMBUF != mred) begin
                                    $display ("pdp8ishad: 18 oMBUF=%o mred=%o", oMBUF, mred);
                                    err[18] <= 1;
                                end
                            end
                        endcase
                        mwbk <= oMBUF;
                    end else if (oTS4) begin

                        // end of TS3, update what AC, LINK and PC should be at this point
                        case (majst)

                            // FETCH:
                            //  direct JMP: sets PC = effective address
                            //   (indirect JMP sets PC in DEFER cycle)
                            //  IOT: updates to AC, PC
                            //  OPR: update AC, LINK, PC from opcode
                            MS_FETCH: begin
                                case (ireg[11:09])
                                    5: begin    // JMP
                                        if (~ ireg[08]) begin
                                            pctr <= eadr;
                                        end
                                    end
                                    6: begin    // IOT
                                        if (saveioenabd) begin
                                            // fpga internal device, we can calculate what processor should have done
                                            acum <= (saveioacclr ? 12'b0 : acum) | saveioinbus;
                                        end else begin
                                            // external to fpga, we assume processor calculated correctly
                                            acum <= oACUM;
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
                                                $display ("pdp8ishad: 22 extarstep=%o sctr=%o", extarstep, sctr);
                                                err[22] <= 1;
                                            end
                                            eago <= 0;
                                            acum <= eaac;
                                            link <= ealn;
                                        end
                                    end
                                endcase
                            end

                            MS_DEFER: begin
                                if (ireg[11:09] == 5) begin
                                    pctr <= mwbk;
                                end
                            end

                            // EXEC:
                            //  AND,TAD,DCA: update according to opcode
                            //  ISZ: maybe increment PC
                            //  JMS: PC = MA + 1
                            MS_EXEC: begin
                                case (ireg[11:09])
                                    0: begin    // AND
                                        acum <= acum & mred;
                                    end
                                    1: begin    // TAD
                                        { link, acum } <= { link, acum } + { 1'b0, mred };
                                    end
                                    2: begin    // ISZ
                                        if (mwbk == 0) pctr <= pctr + 1;
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
                                                $display ("pdp8ishad: 25 extarstep=%o sctr=%o", extarstep, sctr);
                                                err[25] <= 1;
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

                TS_4: begin
                    if (oTS2 | oTS3) begin
                        $display ("pdp8ishad: 19 oTS2=%b oTS3=%b", oTS2, oTS3);
                        err[19] <= 1;
                    end

                    if (oTS4) begin

                        // verify changes made at TP3
                        if ((oACUM != acum) | (oLINK != link)) begin
                            $display ("pdp8ishad: 20 ireg=%o majst=%x oLINK.ACUM=%b.%o link.acum=%b.%o", ireg, majst, oLINK, oACUM, link, acum);
                            err[20] <= 1;
                        end

                        // compute what next major state and memory address should be
                        if (dmagntd) begin
                            if (iCYCLE3) begin
                                brkintfetmajst <= MS_WRDCT;
                                brkintfetmadr  <= iINBUS;
                            end else begin
                                brkintfetmajst <= MS_BREAK;
                                brkintfetmadr  <= iINBUS;
                            end
                        end else begin
                            brkintfetmajst <= (oMAJST == MS_WRDCT) | (oMAJST == MS_BREAK) | (oMAJST == MS_INTAK) ? oMAJST : MS_FETCH;
                            brkintfetmadr <= (oMAJST == MS_WRDCT) | (oMAJST == MS_BREAK) ? oMADR : (oMAJST == MS_INTAK) ? 0 : pctr;
                        end
                    end

                    // check for processor either halted or started TS1 of the next major state
                    else if (~ oRUN | oTS1) begin

                        // compute what next major state and memory address should be
                        case (majst)
                            MS_FETCH: begin
                                case (ireg[11:09])
                                    0,1,2,3,4: begin                    // AND,TAD,ISZ,DCA,JMS
                                        madr  <= eadr;
                                        majst <= ireg[08] ? MS_DEFER : MS_EXEC;
                                    end
                                    5: begin                            // JMP
                                        if (ireg[08]) begin
                                            madr  <= eadr;              // indirect JMP, DEFER cycle reads from eadr
                                            majst <= MS_DEFER;
                                        end else begin
                                            pctr  <= eadr;              // direct JMP, set PC to the effective address
                                            madr  <= (brkintfetmajst == MS_FETCH) ? eadr : brkintfetmadr;
                                            majst <= brkintfetmajst;
                                        end
                                    end
                                    6: begin                            // IOT
                                        if (saveioenabd) begin
                                            // fpga internal device, we can calculate what processor should have done
                                            madr <= (brkintfetmajst == MS_FETCH) ? pctr + { 11'b0, saveioskip } : brkintfetmadr;
                                            pctr <= pctr + { 11'b0, saveioskip };
                                        end else begin
                                            // external to fpga, we assume processor calculated correctly
                                            if (brkintfetmajst == MS_FETCH) begin
                                                // fetch is next, address should be PC (no IOSKIP) or PC+1 (with IOSKIP)
                                                if ((oMADR != pctr) & (oMADR != pctr + 12'b1)) begin
                                                    $display ("pdp8ishad: 21 oMADR=%o pctr=%o", oMADR, pctr);
                                                    err[21] <= 1;
                                                end
                                                madr <= oMADR;
                                                pctr <= oMADR;
                                            end else begin
                                                // don't know if PC was incremented or not
                                                pcknown <= 0;
                                                madr <= brkintfetmadr;
                                            end
                                        end
                                        majst <= brkintfetmajst;
                                    end
                                    7: begin
                                        // if HLT instruction, make sure it halted
                                        if (((ireg[08:00] & 9'o403) == 9'o402) & oTS1) begin
                                            $display ("pdp8ishad: 23 ireg=%o oTS1=%b", ireg, oTS1);
                                            err[23] <= 1;
                                        end

                                        // extarith with memory operand goes to EXEC state next
                                        // otherwise go to BREAK/INTAK/FETCH next
                                        if (extarmem) begin
                                            madr  <= pctr;
                                            majst <= MS_EXEC;
                                        end else begin
                                            madr  <= brkintfetmadr;
                                            majst <= brkintfetmajst;
                                        end
                                    end
                                endcase
                            end

                            MS_DEFER: begin
                                if (ireg[11:09] == 5) pctr <= mwbk;
                                madr  <= (ireg[11:09] == 5) ? brkintfetmadr  : mwbk;
                                majst <= (ireg[11:09] == 5) ? brkintfetmajst : MS_EXEC;
                            end

                            MS_EXEC: begin
                                madr  <= brkintfetmadr;
                                majst <= brkintfetmajst;
                            end

                            MS_WRDCT: begin
                                madr  <= madr + 1;
                                majst <= MS_CURAD;
                            end

                            MS_CURAD: begin
                                madr  <= mwbk;
                                majst <= MS_BREAK;
                            end

                            MS_BREAK: begin
                                if ((brkintfetmajst == MS_FETCH) & ~ pcknown) begin
                                    madr <= oMADR;
                                    pctr <= oMADR;
                                    pcknown <= 1;
                                end else begin
                                    madr <= brkintfetmadr;
                                end
                                majst <= brkintfetmajst;
                            end

                            MS_INTAK: begin
                                madr    <= (brkintfetmajst == MS_FETCH) ? 1 : brkintfetmadr;
                                pctr    <= 1;
                                pcknown <= 1;
                                majst   <= brkintfetmajst;
                            end

                            MS_DEPOS, MS_EXAM: begin
                                if (oTS1) begin
                                    $display ("pdp8ishad: 24");
                                    err[24] <= 1;
                                end
                            end
                        endcase
                        timestate <= oTS1 ? TS_1 : TS_H;
                    end
                end

                // halted with shadow context intact, wait for TS1
                TS_H: begin
                    if (oTS1) begin
                        if ((oMAJST == MS_DEPOS) | (oMAJST == MS_EXAM)) begin
                            madr    <= oMADR;
                            pctr    <= oMADR;
                            maknown <= 1;
                            pcknown <= 1;
                        end
                        majst     <= oMAJST;
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
    //   mred = value read from memory for SCL,MUY,DVI,SHL,ASR,LSR
    //  output:
    //   eaac,ealn,mquo,sctr = possibly updated
    //   extarstep = possibly incremented

    // PDP-8/I small computer handbook 1970
    // pages 57..63
    // also small computer handbook 1973 mode A (says it's 8/I compatible)

    // normalize is done
    wire nmidone = (eaac[11] != eaac[10]) | (eaac[09:00] == 0) & (mquo == 0);

    // memory operand for SCL,MUY,DVI,SHL,ASR,LSR
    wire[11:00] yreg = mred;

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
