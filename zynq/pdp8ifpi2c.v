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

// PDP-8/I front panel interface
//  communicates with front-panel board (console.kicad_sch) via i2c line
//  sends light and switch settings to the arm
//  allows arm to override switches

module pdp8ifpi2c (
    input CLOCK,    // 100MHz FPGA clock
    input RESET,    // FPGA power-on reset
    input iRESET,   // processor bus power-on reset

    input armwrite,
    input[3:0] armraddr, armwaddr,
    input[31:00] armwdata,
    output[31:00] armrdata,

    output i2cclo,
    input  i2ccli,
    output i2cdao,
    input  i2cdai
);

    reg inmode, manual, startbit;
    reg[31:00] armlock;
    reg[31:00] commandlo;
    reg[63:00] command;

    localparam[1:0] RS = 1; // restart
    localparam[1:0] RD = 2; // read
    localparam[1:0] WR = 3; // write

    reg[1:0]   mcpswrow;    // switch row being processed 0..2
    reg[2:0]   mcpltrow;    // light row being processed 0..7
    reg[3:0]   mcpstate;    // processing state
    reg[22:00] mcpassno;
    reg[15:00] mcpltime;    // time for displaying light row

    reg[11:00] lightrows[7:0], switchrows[2:0], switchovrs[2:0];

    reg[15:00] ltspeed;
    reg[9:0] i2cspeed;

    wire[2:0] i2cstate;
    wire[14:00] i2ccount;
    wire[63:00] comand, status;

    assign armrdata = (armraddr ==  0) ? 32'h46503001 : // [31:16] = 'FP'; [15:12] = (log2 nreg) - 1; [11:00] = version
                      (armraddr ==  1) ? { comand[31:00] } :
                      (armraddr ==  2) ? { comand[63:32] } :
                      (armraddr ==  3) ? { status[31:00] } :
                      (armraddr ==  4) ? { status[63:32] } :
                      (armraddr ==  5) ? { i2cclo, i2cdao, i2cdai, i2ccli, 6'b0, i2cstate, i2ccount, manual, 1'b0, inmode, 1'b0 } :
                      (armraddr ==  6) ? armlock :
                      (armraddr ==  7) ? { mcpassno, mcpltrow, mcpswrow, mcpstate } :

                        //            LR0 LR1 LR2 LR3 LR4 LR5 LR6 LR7  SR0 SR1 SR2
                        // 14  GPB5   pc1 ma1 mb1 ac1 mq1 and cad df1  sw1 df1 start   [MSB]
                        // 15  GPB4   pc2 ma2 mb2 ac2 mq2 tad brk df2  sw2 df2 ldaddr
                        //  4  GPB3   pc3 ma3 mb3 ac3 mq3 isz ion df3  sw3 df3 dep
                        //  5  GPB2    .   .   .   .   .  dca pau if1   .  if1 exam
                        //  6  GPB1    .   .   .   .   .  jms run if2   .  if2 cont
                        //  7  GPB0    .   .   .   .   .  jmp sc1 if3   .  if3 stop
                        //  8  GPA5    .   .   .   .   .  iot sc2 lnk   .      sstep
                        //  9  GPA4    .   .   .   .   .  opr sc3       .      sinst
                        // 10  GPA3    .   .   .   .   .  fet sc4       .
                        // 11  GPA2    .   .   .   .   .  exe sc5       .
                        // 12  GPA1    .   .   .   .   .  def           .
                        // 13  GPA0    .   .   .   .   .  wct           .              [LSB]

                      (armraddr ==  8) ? { 2'b0,                    //30
                                           lightrows[5][03:00],     //26 { FET, EXE, DEF, WCT }
                                           lightrows[6][11:10],     //24 { CAD, BRK }
                                           lightrows[1],            //12 MADR[11:00]
                                           lightrows[0] } :         //00 PCTR[11:00]

                      (armraddr ==  9) ? { lightrows[5][11:04],     //24 { AND, TAD, ISZ, DCA, JMS, JMP, IOT, OPR }
                                           lightrows[3],            //12 ACUM[11:00]
                                           lightrows[2] } :         //00 MBUF[11:00]

                      (armraddr == 10) ? { 5'b0,                    //27
                                           lightrows[7][11:05],     //20 { DF[2:0], IF[2:0], LINK }
                                           lightrows[6][09:02],     //12 { ION, PAUSE, RUN, SCTR[4:0] }
                                           lightrows[4] } :         //00 MQUO[11:00]

                      (armraddr == 11) ? { 6'b0,                    //26
                                           switchrows[2][11:04],    //18 { START, LDAD, DEP, EXAM, CONT, STOP, SSTEP, SINST }
                                           switchrows[1][11:06],    //12 { DF[2:0], IF[2:0] }
                                           switchrows[0] } :        //00 SR[11:00]

                      (armraddr == 12) ? { 6'b0,                    //26
                                           switchovrs[2][11:04],    //18 { START, LDAD, DEP, EXAM, CONT, STOP, SSTEP, SINST }
                                           switchovrs[1][11:06],    //12 { DF[2:0], IF[2:0] }
                                           switchovrs[0] } :        //00 SR[11:00]

                      (armraddr == 13) ? { 6'b0, ltspeed, i2cspeed } :

                       32'hDEADBEEF;

    i2cmaster fpi2cintf (
        .CLOCK (CLOCK),
        .RESET (iRESET),        // reset i2c on processor reset (matches console.kicad_sh mcp23017 reset)
        .CSTEP (1'b1),
        .wrcmd (startbit),
        .command (command),
        .comand (comand),
        .status (status),
        .sclo (i2cclo),
        .scli (i2ccli),
        .sdao (i2cdao),
        .sdai (i2cdai),
        .speed (i2cspeed),
        .state (i2cstate),
        .count (i2ccount));

    always @(posedge CLOCK) begin
        if (iRESET) begin           // processor power-on reset
            if (RESET) begin        // fpga power-on reset
                manual   <= 1;      // let console.kicad_sch clock itself
                ltspeed  <= 19999;  // each light row stays on for 200uS
                i2cspeed <= 29;     // operate i2c at 1.667MHz
                switchovrs[0] <= 0; // not overriding any switches
                switchovrs[1] <= 0;
                switchovrs[2] <= 0;
            end
            armlock  <= 0;
            inmode   <= 0;          // data pins not known to be in input mode
            mcpassno <= 0;
            mcpltime <= 0;
            mcpltrow <= 7;
            mcpstate <= 15;
            startbit <= 0;
        end else if (armwrite) begin

            // writing register from arm
            case (armwaddr)
                1: commandlo <= armwdata;       // save lo-order command word
                2: begin
                    command  <= { armwdata, commandlo };
                end
                5: begin
                    manual <= armwdata[03];     // 0=scan console automatically
                                                // 1=arm must issue i2c commands to scan
                end

                // test-and-set cell for arm processor use
                //  anything can be written when it is currently zero
                //  otherwise writing the same number back clears it to zero
                //  all other writes are ignored
                6: begin
                    if (armlock == 0) begin
                        armlock <= armwdata;
                    end else if (armlock == armwdata) begin
                        armlock <= 0;
                    end
                end

                // save switch value bits that are enabled for override
                // otherwise retain latest sensed physical switch value bits
                11: begin
                    switchrows[2][11:04] <= switchovrs[2][11:04] & armwdata[25:18] | ~ switchovrs[2][11:04] & switchrows[2][11:04];
                    switchrows[1][11:06] <= switchovrs[1][11:06] & armwdata[17:12] | ~ switchovrs[1][11:06] & switchrows[1][11:06];
                    switchrows[0][11:00] <= switchovrs[0][11:00] & armwdata[11:00] | ~ switchovrs[0][11:00] & switchrows[0][11:00];
                end

                // save mask of which switch bits are being overridden by arm
                //  0=use physical switch sensed via front panel gpio connector
                //  1=use value written to switchrows by arm processor
                12: begin
                    switchovrs[2][11:04] <= armwdata[25:18];
                    switchovrs[1][11:06] <= armwdata[17:12];
                    switchovrs[0][11:00] <= armwdata[11:00];
                end

                13: begin
                    ltspeed  <= armwdata[25:10];
                    i2cspeed <= armwdata[09:00];
                end
            endcase

            startbit <= (armwaddr == 2);
        end else if (startbit) begin

            // startbit stays on for only one fpga clock cycle
            startbit <= 0;
        end else begin

            // ltrow  states...               i2c bytes...
            //    0    0 1 2 3 4 5 6 8 5 6 7   0+4+6+0+4+4+3+4+4+3+0 = 32
            //    1    0 1 2 3 4 5 6 7         4+4+6+0+4+4+3+0       = 25
            //    2    0 1 2 3 4               4+4+6+0+0             = 14 = 1.4mS @ 100KHz; 83uS @ 1.7MHz
            //    3    0 1 2 3 4               0+4+6+0+0             = 10
            //    4    0 1 2 3 4 10 11         0+4+6+0+3+5+0         = 18
            //    5    0 1 2 3 4 10 11         0+4+6+0+3+5+0         = 18
            //    6    0 1 2 3 4 10 11         0+4+6+0+3+5+0         = 18
            //    7    0 1 2 3 4               0+4+6+0+0             = 10
            //                                                  total 145 = 14.5mS @ 100KHz

            //ltrow:    0                                  1                           2                3            4                    5                    6                    7
            //state:    1111222222...444455556668888555566600001111222222...4444555566600001111222222...1111222222...1111222222...444AAAAA1111222222...444AAAAA1111222222...444AAAAA1111222222...
            //liteon:   777 000000000000                           111111111111                222222222222 333333333333 444444444444         555555555555         666666666666         777777777
            //              ^........^ ltspeed                              ^..^ 60*i2cspeed

            // total cycle time = 8*ltspeed + (160-48)*20*i2cspeed = 1600uS + 2240*300nS = 1600+672uS = 2272uS
            // total light time = 8*ltspeed +       24*20*i2cspeed                       = 1600+144uS = 1744uS
            //  total dark time =                   88*20*i2cspeed                                    =  528uS
            // each light row stays on 218uS/2272uS = 9.6% of time
            // assumes ltspeed = 19999 = 200uS = time light row stays on
            //        i2cspeed = 29 = 300nS = time to transmit half a bit (1.667MHz, 6uS per byte)

            case (mcpstate)

                // send command to set all data pins to input mode
                0: begin
                    if (~ manual) begin
                        // maybe increment pass number
                        if (mcpltrow == 7) mcpassno <= mcpassno + 1;
                        // select next light row for display
                        mcpltrow <= mcpltrow + 1;
                        // set data pins to input mode: 0x00 <= 0x3F3F
                        if (~ inmode) begin
                            command  <= { WR, 8'h40, WR, 8'h00, WR, 8'h3F, WR, 8'h3F, 24'b0 };
                            startbit <= 1;
                            inmode   <= 1;
                        end
                        mcpstate <= 1;
                    end
                end

                // send command to set iicsel selection pins to the light row
                // when command completes, the lights will be on
                1: begin
                    mcpltime <= mcpltime + 1;
                    if (status[63:60] == 0) begin
                        ////$display ("pdp8ifpi2c*: selecting light row %o", mcpltrow);
                        // set iicsel selection pins to the light row
                        //  0x14 <= 1'b0 row<2> 6'b000000
                        //  0x15 <=    row<1:0> 6'b000000
                        command  <= { WR, 8'h40, WR, 8'h14, WR, { 1'b0, mcpltrow[2], 6'b000000 }, WR, { mcpltrow[1:0], 6'b000000 }, 24'b0 };
                        startbit <= 1;
                        mcpstate <= 2;
                    end
                end

                // send command to read light pins from bGPIO lines
                2: begin
                    if (status[63:60] == 0) begin
                        ////$display ("pdp8ifpi2c*: reading light row %o", mcpltrow);
                        mcpltime <= 0;
                        // read light pins from bGPIO: 0x12,0x13
                        command  <= { WR, 8'h40, WR, 8'h12, RS, WR, 8'h41, RD, RD, 28'b0 };
                        startbit <= 1;
                        mcpstate <= 3;
                    end
                end

                // capture light row bits
                3: begin
                    mcpswrow <= mcpltrow[1:0];
                    mcpltime <= mcpltime + 1;
                    if (status[63:60] == 0) begin
                        ////$display ("pdp8ifpi2c*: capture light row %o = %o", mcpltrow, ~ { status[05:00], status[13:08] });
                        lightrows[mcpltrow][11:00] <= ~ { status[05:00], status[13:08] };
                        mcpstate <= 4;
                    end
                end

                // let lights soak for 200uS
                // if light row 0..2, set data pins to like-numbered switch row value
                //              3..7, go on to next light row
                4: begin
                    mcpltime <= mcpltime + 1;
                    // wait for light row displayed for 200uS
                    if (mcpltime >= ltspeed) begin
                        // update like-numbered switch row flipflops
                        //  if just displayed light row 0, update switch row 0 then row 2 flipflops
                        //  if just displayed light row 1, update switch row 1 flipflops
                        if (mcpltrow <= 1) begin
                            ////$display ("pdp8ifpi2c*: sending switch row %o = %o", mcpswrow, switchrows[mcpswrow]);
                            // at this point, ldswrow0,1,2 are all high
                            // set data pins value to switch row and value:
                            //  0x14 <=    2'b10 swval<11:06>
                            //  0x15 <= row<1:0> swval<05:00>
                            // only changes one iicsel bit (sets iicsel_3) to avoid glitching ldswrows<n>
                            // ...which smoothly drives ldswrow<n> low
                            command  <= { WR, 8'h40, WR, 8'h14, WR, { 2'b10, switchrows[mcpswrow][05:00] }, WR, { mcpswrow, switchrows[mcpswrow][11:06] }, 24'b0 };
                            startbit <= 1;
                            mcpstate <= 5;
                        end

                        // read like-numbered physical switch row
                        //  if just displayed light row 4, sense switch row 0
                        //  if just displayed light row 5, sense switch row 1
                        //  if just displayed light row 6, sense switch row 2
                        else if ((mcpltrow >= 4) & (mcpltrow <= 6)) begin
                            ////$display ("pdp8ifpi2c*: sense physical switch row %o", mcpswrow);
                            // at this point, ldswrow0,1,2 are all high
                            // set data pins value to switch row:
                            //  0x14 <= 2'b11 6'b000000
                            // only changes one iicsel bit (sets iicsel_3) to avoid glitching ldswrows<n>
                            command  <= { WR, 8'h40, WR, 8'h14, WR, { 2'b11, 6'b000000 }, 34'b0 };
                            startbit <= 1;
                            mcpstate <= 10;
                        end

                        // no switches, do next light row
                        else begin
                            mcpstate <= 0;
                        end
                    end
                end

                // wait for mcp to get the switch value to be sent to flipflops
                // ...and for ldswrow<n> to go low
                // then set data pins to output mode so bits get sent out the mcp to flipflop inpts
                5: begin
                    // waiting for mcp to get the data
                    // and for ldswrow<n> to go low
                    if (status[63:60] == 0) begin
                        ////$display ("pdp8ifpi2c*: set data pins to output mode");
                        // set data pins to output mode: 0x00 <= 0x0000
                        // gates data pins to flipflop inputs
                        command  <= { WR, 8'h40, WR, 8'h00, WR, 8'h00, WR, 8'h00, 24'b0 };
                        startbit <= 1;
                        inmode   <= 0;
                        mcpstate <= 6;
                    end
                end

                // waiting for mcp to turn output data pins on so flipflops will get data
                // then go to iicsel=4'b1011 which drives ldswrow<n> high, clocking data into flipflops
                6: begin
                    if (status[63:60] == 0) begin
                        // data outputs turned on, kerchunk value into flipflops
                        if (mcpswrow == 0) begin
                            ////$display ("pdp8ifpi2c*: intermediate from switch row 0 to 2 (clocks data %o into swrow 0 flipflops)", switchrows[0]);
                            // doing swrow 0, transition iicsel from 1000 to 1011 might glitch
                            // so transition iicsel from 1000 to 1010 first
                            // by doing 0x15 <= 2'b10 val<05:00>
                            // driving ldswrow0 high (clocking data into swrow0)
                            //  with side-effect of driving ldswrow2 low
                            command  <= { WR, 8'h40, WR, 8'h15, WR, { 2'b10, switchrows[mcpswrow][11:06] }, 34'b0 };
                            startbit <= 1;
                            mcpstate <= 8;
                        end else begin
                            ////$display ("pdp8ifpi2c*: clock switch %o data %o into flipflops", mcpswrow, switchrows[mcpswrow]);
                            // doing swrow 1 or 2, transition iicsel from 1001 or 1010 to 1011 won't glitch
                            // drives ldswrow<n> high
                            // so do 0x15 <= 2'b11 val<05:00>
                            command  <= { WR, 8'h40, WR, 8'h15, WR, { 2'b11, switchrows[mcpswrow][11:06] }, 34'b0 };
                            startbit <= 1;
                            mcpstate <= 7;
                        end
                    end
                end

                // waiting for mcp to receive iicsel=4'b1011 command, which clocked data into mcpswrow flipflops
                7: begin
                    if (status[63:60] == 0) begin
                        ////$display ("pdp8ifpi2c*: clocking complete");
                        // new switch value has been clocked into switch flipflops
                        // resume doing lights
                        mcpstate <= 0;
                    end
                end

                // waiting for mcp to receive iicsel=4'b1010 command, which clocked data into swrow 0 flipflops,
                // ...and is now cocked to clock into row 2
                8: begin
                    if (status[63:60] == 0) begin
                        ////$display ("pdp8ifpi2c*: clock switch 2 data %o into flipflops", switchrows[2]);
                        // ldswrow2 is now low after driving ldswrow0 high
                        // we must clock in proper swrow2 contents to drive ldswrow2 high
                        // ...as idle state of ldswrow0,1,2 is high
                        mcpswrow <= 2;
                        command  <= { WR, 8'h40, WR, 8'h14, WR, { 2'b10, switchrows[2][05:00] }, WR, { 2'b10, switchrows[2][11:06] }, 24'b0 };
                        startbit <= 1;
                        mcpstate <= 5;
                    end
                end

                // send command to read physical switch pins from bGPIO lines
                10: begin
                    if (status[63:60] == 0) begin
                        ////$display ("pdp8ifpi2c*: start reading physical switch row %o", mcpswrow);
                        // read switch pins from bGPIO: 0x12,0x13
                        command  <= { WR, 8'h40, WR, 8'h12, RS, WR, 8'h41, RD, RD, 28'b0 };
                        startbit <= 1;
                        mcpstate <= 11;
                    end
                end

                // capture physical switch row bits that aren't being overridden by bits from the arm
                // then go on to display next light row
                11: begin
                    if (status[63:60] == 0) begin
                        ////$display ("pdp8ifpi2c*: read switch row %o got data %o", mcpswrow, { status[05:00], status[13:08] });
                        switchrows[mcpswrow] <= switchovrs[mcpswrow] & switchrows[mcpswrow] |
                                              ~ switchovrs[mcpswrow] & { status[05:00], status[13:08] };
                        mcpstate <= 0;
                    end
                end

                // startup delay 1uS after power-on reset
                15: begin
                    mcpltime <= mcpltime + 1;
                    if (mcpltime >= 100) begin
                        mcpstate <= 0;
                    end
                end
            endcase
        end
    end
endmodule
