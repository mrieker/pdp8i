
// small computer handbook 1973
// pages 5-1... just the mode A parts
// states mode A works like pdp-8/i

module extarith (
    input CLOK2,                // 10MHz clock
    input BUSINI,               // power-on reset

    // bus signals
    output reg HOLD,            // hold internal clocking (stretch cycle)
    inout ACCLEAR,              // io pulse clears AC
    inout IOSKIP,               // increment PC at end of IO pulse
    inout LNKTOG,               // toggle link register
    inout [11:00] INBUS,        // IO data being read from device
    input LINK,                 // link register
    input TP1,                  // time pulses
    input TP2,
    input TP3,
    input TP4,
    input TS1,                  // time states
    input TS2,
    input TS3,
    input TS4,
    input[11:00] ACUM,          // IO data being written to device

    input[3:0] MAJST,

    output[11:00] MQUO,
    output[4:0] SCTR
);

`include "msdef.v"

    reg extar, memop, myln, s3clk;
    reg[11:00] mquo, myac;
    reg[11:00] yreg;
    reg[6:4] extop64;
    reg[3:1] extop31;
    reg[5:0] sctr;

    assign MQUO = mquo;
    assign SCTR = sctr[4:0];

    // major state executing
    wire msfetch = MAJST == MS_FETCH;
    wire msexec  = MAJST == MS_EXEC;

    // we are doing execute cycle of an extended arithmetic instruction
    wire extarex = extar & (memop ? msexec : msfetch);

    // opcode is one of SHL,ASR,LSR
    wire countedshift = extop31[3] & (extop31[2] | extop31[1]);

    // normalize is done
    wire nmidone = (myac[11] != myac[10]) | (myac[09:00] == 0) & (mquo == 0);

    // step 2 - clocked into myac at TP2
    wire[11:00] myacstep2 = (extop64[4] ? 12'b0 : myac) |                // 0020 MQL - load multipler quotient from accumulator
                            (extop64[5] ? { 7'b0, sctr[4:0] } : 12'b0) | // 0040 SCA - step counter load into accumulator
                            (extop64[6] ? mquo : 12'b0);                 // 0100 MQA - multiplier quotient load into accumulator

    // each step in multiply
    wire[11:00] ymuy = mquo[00] ? yreg : 0;
    wire[11:00] muyacstep, muymqstep;
    assign { muyacstep, muymqstep[11] } = { 1'b0, myac } + { 1'b0, ymuy };
    assign muymqstep[10:00] = mquo[11:01];

    // each step in divide
    wire dviover = myac >= yreg;
    wire[11:00] dvidend = { myac[10:00], mquo[11] };
    wire dviboro;
    wire[11:00] dvidiff;
    assign { dviboro, dvidiff } = { 1'b0, dvidend } - { 1'b0, yreg };
    wire dviqbit = myac[11] | ~ dviboro;
    wire[11:00] dviacstep = dviqbit ? dvidiff : dvidend;
    wire[11:00] dvimqstep = { mquo[10:00],  dviqbit };   // shift quotient bit into bottom of MQ

    // each step in shift left (also works for normalize)
    wire shllnstep;
    wire[11:00] shlacstep, shlmqstep;
    assign { shllnstep, shlacstep, shlmqstep } = { myac, mquo, 1'b0 };

    // each step in shift right
    wire shrlnstep = extop31[1] ? 1'b0 : myac[11];
    wire[11:00] shracstep, shrmqstep;
    assign { shracstep, shrmqstep } = { shrlnstep, myac, mquo[11:01] };

    // opcode being fetched from memory
    wire extar_clk = TP1 & msfetch;
    wire extar_dat = (INBUS & 12'o7401) == 12'o7401;
    wire memop_clk = extar_clk;
    wire memop_dat = INBUS[2:1] != 0;

    always @(posedge extar_clk or posedge BUSINI) begin
        if (BUSINI) extar <= 0;
        else extar <= extar_dat;
    end

    always @(posedge memop_clk) begin
        memop <= memop_dat;
    end

    // extended arithmetic opcode
    //  [6:4] = step 2 opcode; computed during TS2, clocked at TP2
    //  [3:1] = step 3 opcode; computed during TS3, clocked at TP3
    //                         TS3 stretched by HOLD
    wire[6:1] extop_dat = INBUS[06:01];
    wire extop_clk = TP1 & msfetch;

    always @(posedge extop_clk) begin
        extop64 <= extop_dat[6:4];
        extop31 <= extop_dat[3:1];
    end


    // hold processor at beginning of TS3 while doing step 3
    // stop holding when termination condition is met
    wire HOLD_clk = TS3;
    wire HOLD_dat = extarex;
    wire _HOLD_pc =
            (extop31 == 2) & ~ sctr[5] |                // MUY done when 12 s3clk pulses have been generated
            (extop31 == 3) & ~ sctr[5] & ~ dviover |    // DVI done when 12 s3clk pulses or when overflow
            (extop31 == 4) & ~ nmidone |                // NMI done when NMI condition met
            countedshift   & ~ sctr[5];                 // shifts done when given number s3clk pulses generated

    always @(posedge HOLD_clk or negedge _HOLD_pc) begin
        if (~ _HOLD_pc) HOLD <= 0;
        else HOLD <= HOLD_dat;
    end

    // perform step 3 clocking while processor holding at beginning of TS3
    // make sure all pulses have full width
    wire s3clk_clk = CLOK2;
    wire s3clk_dat = ~ s3clk & HOLD;

    always @(posedge s3clk_clk) begin
        s3clk <= s3clk_dat;
    end

    // output results to processor
    // it clocks them in at TP3
    // so start outputting at TS3 to give them time to soak
    wire outit = TS3 & extarex;
    assign ACCLEAR = outit ? 1'b1 : 1'bZ;
    assign IOSKIP  = outit ? 1'b1 : 1'bZ;
    assign INBUS   = outit ? myac : 12'hZZZ;
    assign LNKTOG  = outit ? LINK ^ myln_out : 1'bZ;

    // important clocks:
    //  TP1   - clocks at end of reading memory, INBUS valid with data
    //  s3clk - clocks while holding to step through multiply,divide,shifts
    //  TP3   - clocks when all stepping has finished, sends results back to processor

    // internal copy of link
    wire myln_out =
        (extop31 == 2) ? 0 :
        (extop31 == 3) ? dviover :
        (extop31 == 4) ? shllink :
        (extop31 == 5) ? shllink :
        (extop31 == 6) ? myac[11] :
        (extop31 == 7) ? 0 :
            LINK;

    reg shllink;

    // internal copy of accumulator
    wire[11:00] myac_dat =
        TS1 & msfetch ? (INBUS[07] ? 0 : ACUM) :                // get accumulator during fetch
        TS2 & extarex        ? myacstep2 :                      // update accumulator for step 2
        TS3 & (extop31 == 2) ? muyacstep :                      // update accumulator for multiply
        TS3 & (extop31 == 3) ? dviacstep :                      // update accumulator for divide
        TS3 & (extop31[3:2] == 2) ? shlacstep :                 // update accumulator for shift left
        TS3 & (extop31[3:2] == 3) ? shracstep :                 // update accumulator for shift right
            myac;

    wire myac_clk =
        TP1 & msfetch |                                         // get acum during fetch
        TP2 & extarex & (extop64 != 0) |                        // update acum during step 2 (MQL,SCA,MQA)
        s3clk & (extop31 == 2) |                                // accumulator for multiply steps
        s3clk & (extop31 == 3) |                                // accumulator for divide steps
        s3clk & extop31[3];                                     // accumulator for shifts

    always @(posedge myac_clk) begin
        shllink <= TS3 ? shllnstep : LINK;                      // init from LINK in case NMI with no shifts
                                                                // otherwise save bit shifted out top of myac
        myac <= myac_dat;
    end

    // multiplier/quotient
    wire[11:00] mquo_dat =
        TS2 & extop64[4] ? myac :                               // get from accum for step 2
        TS3 & (extop31 == 2) ? muymqstep :
        TS3 & (extop31 == 3) ? dvimqstep :
        TS3 & (extop31[3:2] == 2) ? shlmqstep :                 // NMI,SHL
        TS3 & (extop31[3:2] == 3) ? shrmqstep :                 // ASR,LSR
            mquo;

    wire mquo_clk =
        TP2 & extarex & extop64[4] |                            // load mquo from acum in step 2
        s3clk & (extop31 == 2) |                                // mult/quo for multiply steps
        s3clk & (extop31 == 3) |                                // mult/quo for divide steps
        s3clk & extop31[3];                                     // mult/quo for shifts

    always @(posedge mquo_clk or posedge BUSINI) begin
        if (BUSINI) mquo <= 0;
        else mquo <= mquo_dat;
    end


    wire[5:0] sctr_dat =
        TS2 & (extop31 == 1) ? { 1'b0, ~ yreg[04:00] } :        // load sctr from memory
        TS2 & (extop31[3:2] == 1) ? 20 :                        // load 20 at TP2 for MUY,DVI
        TS2 & (extop31      == 4) ?  0 :                        // load  0 at TP2 for NMI
        TS2 & countedshift ? { 1'b0, ~ yreg[04:00] } :          // load sctr from memory for SHL,ASR,LSR
            sctr;

    wire sctr_clk =
        TP2 & extarex & (extop31      == 1) |                   // load sctr from memory
        TP2 & extarex & (extop31[3:2] == 1) |                   // load 0 at TP2 for MUY,DVI
        TP2 & extarex & (extop31      == 4) |                   // load 0 at TP2 for NMI
        TP2 & extarex & countedshift;                           // load sctr from memory for SHL,ASR,LSR

    wire sctr_inc =
        s3clk & (extop31[3:2] != 0);                            // increment count for MUY,DVI,NMI,SHL,ASR,LSR

    always @(posedge sctr_clk or posedge sctr_inc or posedge BUSINI) begin
        if (BUSINI) sctr <= 0;
        else if (sctr_inc) sctr <= sctr + 1;
        else sctr <= sctr_dat;
    end


    wire[11:00] yreg_dat = INBUS;
    wire yreg_clk = TP1 & msexec;                               // load YREG from memory during EXEC cycle

    always @(posedge yreg_clk) begin
        yreg <= yreg_dat;
    end

endmodule
