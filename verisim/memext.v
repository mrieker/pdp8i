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

// PDP-8/L extended memory

module memext (
    input clok2,                // 10MHz clock
    input reset,                // power-on reset

    input businit,              // start switch being pressed
    input iop,                  // IO instuction pulse
    input ldaddrsw,             // console LOAD ADDRESS switch
    input tp3,                  // processor end-of-TS3 pulse
    input tp4,                  // processor end-of-TS4 pulse
    input exefet,               // EXEC or FETCH cycle next
    input intack,               // INTACK cycle next
    input jmpjms,               // JMP or JMS instruction in instruction register
    input[2:0] dmafield,        // field for DMA cycle
    input[2:0] dfldsw,          // console DF switches
    input[2:0] ifldsw,          // console IF switches
    input[1:0] fldsel,          // processor indicating which field to use
    input[11:00] acum,          // processor AC register
    input[11:00] mbuf,          // processor MB register

    output reg intinh,          // interrupts inhibited until jmp/jms
    output[2:0] field,          // current memory field active
    output reg[11:00] inbus     // IO instruction read data
);

`include "fsdef.v"

    reg[2:0] dfld, ifld, ifldaj, saveddfld, savedifld;

    // fldsel is loaded at beginning of TP4 so field will be ready in time for subsequent TS1 memory cycle
    // ...and will remain valid through the following TP4
    // it is also loaded by console switches when processor is halted well in advance of any memory cycle
    assign field = (fldsel == FS_INST) ? ifld :
                   (fldsel == FS_DATA) ? dfld :
                  (fldsel == FS_BREAK) ? dmafield : 0;

    always @(posedge clok2) begin

        ////////////////
        //  bus init  //
        ////////////////

        if (reset) begin

            // these get cleared on power up
            // they remain as is when start switch is pressed
            dfld   <= 0;
            ifld   <= 0;
            ifldaj <= 0;
        end

        if (businit) begin

            // these get cleared on power up or start switch
            intinh    <= 0;
            saveddfld <= 0;
            savedifld <= 0;
        end

        /////////////////////////////////
        //  IO instruction processing  //
        /////////////////////////////////

        // see mc8l memory extension, p6
        // note: if intack is asserted, the intack code below that saves ifld,dfld,etc has already executed at tp3 time
        //       so anything here must take that into account, using the saved values instead of current values

        if ((mbuf & 12'o0700) == 12'o0200) begin

            // 62x1 : CDFn instruction
            // won't be followed by intack, just set the field
            if (iop & mbuf[00]) begin
                dfld   <= mbuf[05:03];
            end

            // 62x2 : CIFn instruction
            // won't be followed by intack cuz it blocks interrupts
            if (iop & mbuf[01]) begin
                ifldaj <= mbuf[05:03];
                intinh <= 1;
            end

            if (iop & mbuf[02]) begin
                case (mbuf[05:03])
                    1: begin    // 6214 RDF
                        inbus[05:03] <= dfld;
                    end

                    2: begin    // 6224 RIF
                        inbus[05:03] <= ifld;
                    end

                    3: begin    // 6234 RIB
                        inbus[05:03] <= savedifld;
                        inbus[02:00] <= saveddfld;
                    end

                    4: begin    // 6244 RMF
                        dfld   <= saveddfld;
                        ifldaj <= savedifld;
                    end
                endcase
            end
        end

        if (~ iop) begin
            inbus <= 0;
        end

        //////////////////////////////////////////////
        //  manage IF and DF and related registers  //
        //////////////////////////////////////////////

        // maybe we have load address switch to process
        // theoretically can't happen when the processor is running
        // ...so it won't interfere with io instruction processing
        // ldaddrsw is not debounced so this code must be idempotent
        if (ldaddrsw) begin
            dfld   <= dfldsw;
            ifld   <= ifldsw;
            ifldaj <= ifldsw;
        end

        // if doing a JMP instruction, stop blocking interrupts
        // do this at TP3 in time for new state to be calculated for TP4
        if (tp3 & jmpjms) begin
            intinh <= 0;
        end

        // change fields just after TP4 pulse starts
        // don't change field during TS3 cuz memory is being written
        if (tp4 & jmpjms & exefet) begin
            ifld <= ifldaj;
        end

        // near end of instruction to be followed by jms 0 for an interrupt
        //  intack = next cycle will be the exec of the jms 0 for calling interrupt service routine
        //           valid in time for posedge TP4
        // the interrupt service routine always starts in field 0
        if (tp4 & intack) begin
            saveddfld <= dfld;      // save data & instruction fields
            savedifld <= jmpjms ? ifldaj : ifld;
            dfld   <= 0;            // interrupt routine starts in field 0
            ifld   <= 0;
            ifldaj <= 0;
        end
    end
endmodule
