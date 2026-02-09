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
    input zclock,               // fpga 10MHz clock
    input zreset,               // fpga reset

    input preset,               // power-on reset
    input businit,              // start switch being pressed
    input iop1, iop2, iop4,     // IO instuction pulses
    input ldaddrsw,             // console LOAD ADDRESS switch
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

    always @(posedge zclock) begin

        ////////////////
        //  bus init  //
        ////////////////

        if (preset) begin

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
            if (iop1) begin
                dfld   <= mbuf[05:03];
            end

            // 62x2 : CIFn instruction
            // won't be followed by intack cuz it blocks interrupts
            if (iop2) begin
                ifldaj <= mbuf[05:03];
                intinh <= 1;
            end

            if (iop4) begin
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

        if (~ iop4) begin
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

        // change fields just after TP4 pulse starts
        // don't change field during TS3 cuz memory is being written
        if (tp4) begin

            // near end of of jmp/jms, don't inhibit interrupts any more
            //  tp3    = blip near end of writing memory
            //  jmpjms = JMP or JMS opcode currently in instruction register
            //  exefet = EXEC or FETCH state is next
            //
            // cases:
            //  direct JMP:
            //                      <- here with jmpjms = 0
            //   jmp fetch:  old IF
            //                      <- here with jmpjms = 1, exefet = 1
            //   next fetch: new IF
            //
            //  indirect JMP (the usual case, return-from-interrupt):
            //                      <- here with jmpjms = 0
            //   jmp fetch:  old IF
            //                      <- here with jmpjms = 1, exefet = 0
            //   jmp defer:  old IF
            //                      <- here with jmpjms = 1, exefet = 1
            //   next fetch: new IF
            //
            //  direct JMS:
            //                      <- here with jmpjms = 0
            //   jms fetch:  old IF
            //                      <- here with jmpjms = 1, exefet = 1
            //   jms exec:   new IF
            //                      <- here with jmpjms = 1, exefet = 1
            //   next fetch: new IF
            //
            //  indirect JMS:
            //                      <- here with jmpjms = 0
            //   jms fetch:  old IF
            //                      <- here with jmpjms = 1, exefet = 0
            //   jms defer:  old IF
            //                      <- here with jmpjms = 1, exefet = 1
            //   jms exec:   new IF
            //                      <- here with jmpjms = 1, exefet = 1
            //   next fetch: new IF
            //
            if (jmpjms & exefet) begin

                // exefet is dependent on TP3* for interrupt requests so can change during the beginning of TS4
                // then by the time the PDP clocks the major state at TP4 it is different than what we have here
                // but the MC-8/L clocks it at TP3 so we do the same here

                // since this changes things only when intinh is set, exefet should be steady
                // at this point and reflect FETCH/EXEC is next assuming no interrupt pending

                // note: TP3* indicates TP3 but delayed to end of io pulses for IOT instructions, ie, beginning of TS4

                //  esetfset = eset | fset
                //  TP2,3*,4,intinhibit

                //  eset     = intok | defer & ~ jmp | fetch & ~ mb03 & ~ jmp & ~ iot & ~ opr
                //  TP2,3*,4   TP2,3*  TP4       TP2   TP4       TP2      TP2     TP2     TP2

                //  fset = ~ dset & ~ eset & ~ breakok & ~ specialcycle
                //  TP2,3*,4 TP2,3*,4 TP2,3*,4 TP4         TP4

                //  dset = fetch & mb03 & ~ iot & ~ opr
                //  TP2,4  TP4     TP2      TP2     TP2

                //  intok = intsync & intdelay & ~ intinhibit & (irmb != 600x)
                //  TP2,3*  TP3*      TP3*                       TP2

                //  breakok = ~ eset & ~ fset & ~ specialcycle & brksync
                //                                TP4            TP1

                //  specialcycle = wordcount | currentaddress
                //  TP4            TP4         TP4

                //  intstrobe = ioend | tp3 & ~ iot
                //  TP3* = start of TS4

                // MC-8/L
                //   INT_INH clock = posedge (LOAD_IF | KEY_CLEAR)  (p11 C-4)
                //   LOAD_IF       = jmpjms & tp3 & exefet  (p11 C-4)
                intinh <= 0;

                // MC-8/L
                //   IF clock = posedge LOAD_IF  (p11 C-7)
                //   LOAD_IF  = jmpjms & tp3 & exefet  (p11 C-4)
                ifld <= ifldaj;
            end

            // near end of instruction to be followed by jms 0 for an interrupt
            //  intack = next cycle will be the exec of the jms 0 for calling interrupt service routine
            //           valid in time for posedge TP4
            // the interrupt service routine always starts in field 0
            if (intack) begin
                saveddfld <= dfld;      // save data & instruction fields
                savedifld <= jmpjms ? ifldaj : ifld;
                dfld   <= 0;            // interrupt routine starts in field 0
                ifld   <= 0;
                ifldaj <= 0;
            end
        end
    end
endmodule
