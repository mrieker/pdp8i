
module console (
    input zclock,
    input zreset,

    input preset,

//  inout[27:04] gpio,
    input[27:04] gpin,
    output[27:04] gpout,

    input[11:00] lbpctr,
    input[11:00] lbmadr,
    input[11:00] lbmbuf,
    input[11:00] lbacum,
    input[11:00] lbmquo,
    input[11:09] lbireg,
    input[3:0]   lbmajst,
    input        lbion,
    input        lbpause,
    input        lbrun,
    input[4:0]   lbsc,
    input[2:0]   lbdf,
    input[2:0]   lbif,
    input        lblink,

    output reg[11:00] swreg,
    output reg[2:0] swdfld,
    output reg[2:0] swifld,
    output reg swstart,
    output reg swldad,
    output reg swdepos,
    output reg swexam,
    output reg swcont,
    output reg swstop,
    output reg swsstep,
    output reg swsinst
);

    localparam[3:0] MS_PWRON = 0;   // power-on reset
    localparam[3:0] MS_FETCH = 1;   // memory cycle is fetching instruction
    localparam[3:0] MS_DEFER = 2;   // memory cycle is reading pointer
    localparam[3:0] MS_EXEC  = 3;   // memory cycle is for executing instruction
    localparam[3:0] MS_WRDCT = 4;   // memory cycle is for incrementing dma word count
    localparam[3:0] MS_CURAD = 5;   // memory cycle is for reading dma address
    localparam[3:0] MS_BREAK = 6;   // memory cycle is for dma data word transfer
    localparam[3:0] MS_INTAK = 7;   // memory cycle is for interrupt acknowledge
    localparam[3:0] MS_DEPOS = 8;   // memory cycle is for deposit switch
    localparam[3:0] MS_EXAM  = 9;   // memory cycle is for examine switch

    //           LR1 LR2 LR3 LR4 LR5 LR6 LR7 LR8 SR1 SR2 SR3
    // gpio lbus rn0 rn1 rn2 rn3 rn4 rn5 rn6 rn7 rn8 rn9 rn10
    //  14   11  pc1 ma1 mb1 ac1 mq1 and cad df1 sw1 df1 start  [MSB]
    //  15   10  pc2 ma2 mb2 ac2 mq2 tad brk df2 sw2 df2 ldad
    //   4    9  pc3 ma3 mb3 ac3 mq3 isz ion df3 sw3 df3 depos
    //   5    8   .   .   .   .   .  dca pau if1  .  if1 exam
    //   6    7   .   .   .   .   .  jms run if2  .  if2 cont
    //   7    6   .   .   .   .   .  jmp sc1 if3  .  if3 stop
    //   8    5   .   .   .   .   .  iot sc2 lnk  .      sstep
    //   9    4   .   .   .   .   .  opr sc3      .      sinst
    //  10    3   .   .   .   .   .  fet sc4      .
    //  11    2   .   .   .   .   .  exe sc5      .
    //  12    1   .   .   .   .   .  def          .
    //  13    0   .   .   .   .   .  wct          .             [LSB]

    reg[3:0] rownum;
    reg[5:0] debounce;
    reg[11:00] timer;
//  wire[27:04] gpout;

    wire[3:0] nextrow = (rownum == 10) ? 0 : rownum + 1;

//  wire[27:04] gpin = gpio;
//  assign gpio[27:20] = gpout[27:20];                          // led row select
//  assign gpio[19]    = 1'bZ;                                  // spare
//  assign gpio[18:16] = gpout[18:16];                          // switch row select
//  assign gpio[15:04] = rownum[3] ? 12'hZZZ : gpout[15:04];    // columns

    always @(posedge zclock) begin
        if (preset) begin
            debounce <= 0;
            rownum   <= 0;
            timer    <= 0;
        end else begin
            // let switch sensing soak for 10uS
            // let light driving soak for 200uS
            //if (timer == (rownum[3] ? 99 : 1999)) begin
            if (timer == 9) begin
                // save switch contents
                case (rownum)
                     8: begin
                        swreg[11] <= gpin[14];
                        swreg[10] <= gpin[15];
                        swreg[09] <= gpin[04];
                        swreg[08] <= gpin[05];
                        swreg[07] <= gpin[06];
                        swreg[06] <= gpin[07];
                        swreg[05] <= gpin[08];
                        swreg[04] <= gpin[09];
                        swreg[03] <= gpin[10];
                        swreg[02] <= gpin[11];
                        swreg[01] <= gpin[12];
                        swreg[00] <= gpin[13];
                    end
                     9: begin
                        swdfld[2] <= gpin[14];
                        swdfld[1] <= gpin[15];
                        swdfld[0] <= gpin[04];
                        swifld[2] <= gpin[05];
                        swifld[1] <= gpin[06];
                        swifld[0] <= gpin[07];
                    end
                    10: begin
                        // comes through here every 1.63mS
                        // debounce for 32 cycles (52.16mS)
                        if (~ gpin[14] & ~ gpin[04] & ~ gpin[05] & ~ gpin[06]) begin
                            debounce <= 0;
                        //end else if (~ debounce[5]) begin
                        end else if (~ debounce[2]) begin
                            debounce <= debounce + 1;
                        end
                        // output debounced switches
                        // LDAD, STOP are idempotent
                        // SSTEP, SINST are toggles
                        swstart   <= gpin[14] & debounce[2];//5
                        swldad    <= gpin[15];
                        swdepos   <= gpin[04] & debounce[2];//5
                        swexam    <= gpin[05] & debounce[2];//5
                        swcont    <= gpin[06] & debounce[2];//5
                        swstop    <= gpin[07];
                        swsstep   <= gpin[08];
                        swsinst   <= gpin[09];
                    end
                endcase
                // on to next row
                rownum <= nextrow;
                timer  <= 0;
                if (nextrow[3]) begin                       // 8..10: set up to read switch row 0..2
                    gpout[27:20] <= 0;                      //  not driving any leds
                    gpout[18:16] <= ~ (1 << nextrow[1:0]);  //  select switch row
                end else begin                              // 0..7: start lighting up led row 0..7
                    gpout[27:20] <= 1 << nextrow[2:0];      //  select led row
                    gpout[18:16] <= 7;                      //  don't select any switch row
                    case (nextrow[2:0])
                        0: begin
                            gpout[14] <= ~ lbpctr[11];
                            gpout[15] <= ~ lbpctr[10];
                            gpout[04] <= ~ lbpctr[09];
                            gpout[05] <= ~ lbpctr[08];
                            gpout[06] <= ~ lbpctr[07];
                            gpout[07] <= ~ lbpctr[06];
                            gpout[08] <= ~ lbpctr[05];
                            gpout[09] <= ~ lbpctr[04];
                            gpout[10] <= ~ lbpctr[03];
                            gpout[11] <= ~ lbpctr[02];
                            gpout[12] <= ~ lbpctr[01];
                            gpout[13] <= ~ lbpctr[00];
                        end
                        1: begin
                            gpout[14] <= ~ lbmadr[11];
                            gpout[15] <= ~ lbmadr[10];
                            gpout[04] <= ~ lbmadr[09];
                            gpout[05] <= ~ lbmadr[08];
                            gpout[06] <= ~ lbmadr[07];
                            gpout[07] <= ~ lbmadr[06];
                            gpout[08] <= ~ lbmadr[05];
                            gpout[09] <= ~ lbmadr[04];
                            gpout[10] <= ~ lbmadr[03];
                            gpout[11] <= ~ lbmadr[02];
                            gpout[12] <= ~ lbmadr[01];
                            gpout[13] <= ~ lbmadr[00];
                        end
                        2: begin
                            gpout[14] <= ~ lbmbuf[11];
                            gpout[15] <= ~ lbmbuf[10];
                            gpout[04] <= ~ lbmbuf[09];
                            gpout[05] <= ~ lbmbuf[08];
                            gpout[06] <= ~ lbmbuf[07];
                            gpout[07] <= ~ lbmbuf[06];
                            gpout[08] <= ~ lbmbuf[05];
                            gpout[09] <= ~ lbmbuf[04];
                            gpout[10] <= ~ lbmbuf[03];
                            gpout[11] <= ~ lbmbuf[02];
                            gpout[12] <= ~ lbmbuf[01];
                            gpout[13] <= ~ lbmbuf[00];
                        end
                        3: begin
                            gpout[14] <= ~ lbacum[11];
                            gpout[15] <= ~ lbacum[10];
                            gpout[04] <= ~ lbacum[09];
                            gpout[05] <= ~ lbacum[08];
                            gpout[06] <= ~ lbacum[07];
                            gpout[07] <= ~ lbacum[06];
                            gpout[08] <= ~ lbacum[05];
                            gpout[09] <= ~ lbacum[04];
                            gpout[10] <= ~ lbacum[03];
                            gpout[11] <= ~ lbacum[02];
                            gpout[12] <= ~ lbacum[01];
                            gpout[13] <= ~ lbacum[00];
                        end
                        4: begin
                            gpout[14] <= ~ lbmquo[11];
                            gpout[15] <= ~ lbmquo[10];
                            gpout[04] <= ~ lbmquo[09];
                            gpout[05] <= ~ lbmquo[08];
                            gpout[06] <= ~ lbmquo[07];
                            gpout[07] <= ~ lbmquo[06];
                            gpout[08] <= ~ lbmquo[05];
                            gpout[09] <= ~ lbmquo[04];
                            gpout[10] <= ~ lbmquo[03];
                            gpout[11] <= ~ lbmquo[02];
                            gpout[12] <= ~ lbmquo[01];
                            gpout[13] <= ~ lbmquo[00];
                        end
                        5: begin
                            gpout[14] <= ~ (lbireg == 0);
                            gpout[15] <= ~ (lbireg == 1);
                            gpout[04] <= ~ (lbireg == 2);
                            gpout[05] <= ~ (lbireg == 3);
                            gpout[06] <= ~ (lbireg == 4);
                            gpout[07] <= ~ (lbireg == 5);
                            gpout[08] <= ~ (lbireg == 6);
                            gpout[09] <= ~ (lbireg == 7);
                            gpout[10] <= ~ (lbmajst == MS_FETCH);
                            gpout[11] <= ~ (lbmajst == MS_EXEC);
                            gpout[12] <= ~ (lbmajst == MS_DEFER);
                            gpout[13] <= ~ (lbmajst == MS_WRDCT);
                        end
                        6: begin
                            gpout[14] <= ~ (lbmajst == MS_CURAD);
                            gpout[15] <= ~ (lbmajst == MS_BREAK);
                            gpout[04] <= ~ lbion;
                            gpout[05] <= ~ lbpause;
                            gpout[06] <= ~ lbrun;
                            gpout[07] <= ~ lbsc[4];
                            gpout[08] <= ~ lbsc[3];
                            gpout[09] <= ~ lbsc[2];
                            gpout[10] <= ~ lbsc[1];
                            gpout[11] <= ~ lbsc[0];
                        end
                        7: begin
                            gpout[14] <= ~ lbdf[2];
                            gpout[15] <= ~ lbdf[1];
                            gpout[04] <= ~ lbdf[0];
                            gpout[05] <= ~ lbif[2];
                            gpout[06] <= ~ lbif[1];
                            gpout[07] <= ~ lbif[0];
                            gpout[08] <= ~ lblink;
                        end
                    endcase
                end
            end else begin
                timer <= timer + 1;
            end
        end
    end
endmodule
