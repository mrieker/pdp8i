
// small computer handbook 1970
// pages p73/v59

module extarith (
    input CLOK2,                // 10MHz clock
    input BUSINI,               // power-on reset

    // bus signals
    output reg ACCLEAR,         // io pulse clears AC
    output reg HOLD,            // hold internal clocking (stretch cycle)
    output reg IOSKIP,          // increment PC at end of IO pulse
    output reg LNKTOG,          // toggle link register
    output reg[11:00] INBUS,    // IO data being read from device
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
    reg[11:00] mquo, myac, yreg;
    reg[6:4] extop64;
    reg[3:1] extop31;
    reg[4:0] sctr;

    always @(posedge CLOK2) begin
        $display ("extarith*: ts=%b%b%b%b majst=%x inbus=%o extar=%b memop=%b myln=%b s3clk=%b extop=%o%o sctr=%o myac=%o mquo=%o yreg=%o hold=%b skip=%b",
            TS1,TS2,TS3,TS4, MAJST, INBUS, extar, memop, myln, s3clk, extop64, extop31, sctr, myac, mquo, yreg, HOLD, IOSKIP);
    end

    assign MQUO = mquo;
    assign SCTR = sctr;

    // major state executing
    wire msfetch = MAJST == MS_FETCH;
    wire msexec  = MAJST == MS_EXEC;
    wire extarexec = extar & (memop ? msexec : msfetch);

    // opcode is one of SHL,ASR,LSR
    wire countedshift = extop31[3] & (extop31[2] | extop31[1]);
    wire countedshiftdone = countedshift & (yreg[04:00] != 0);

    // normalize is done
    wire nmidone = (myac[11] != myac[10]) | (myac[09:00] == 0) & (mquo == 0);

    // step 2
    wire[11:00] myacstep2 = (extop64[4] ? 12'b0 : myac) |           // 0020 MQL - load multipler quotient from accumulator
                            (extop64[5] ? { 7'b0, sctr } : 12'b0) | // 0040 SCA - step counter load into accumulator
                            (extop64[6] ? mquo : 12'b0);            // 0100 MQA - multiplier quotient load into accumulator

    // each step in multiply
    wire[11:00] ymuy = mquo[00] ? yreg : 0;
    wire[11:00] muyacstep, muymqstep;
    assign { muyacstep, muymqstep[11] } = { 1'b0, myac } + { 1'b0, ymuy };
    assign muymqstep[10:00] = mquo[11:01];

    // each step in divide
    wire dviover = myac >= yreg;
    wire[11:00] dvidend = { myac[10:00], mquo[11] };
    wire dvicary;
    wire[11:00] dvidiff;
    assign { dvicary, dvidiff } = { 1'b0, dvidend } + { 1'b1, ~ yreg } + 1;
    wire dviqbit = dvicary | myac[11];
    wire[11:00] dviacstep = dviqbit ? dvidiff : dvidend;
    wire[11:00] dvimqstep = { mquo[10:00],  dviqbit };   // shift quotient bit into bottom of MQ

    // each step in shift left (also works for normalize)
    wire shllnstep;
    wire[11:00] shlacstep, shlmqstep;
    assign { shllnstep, shlacstep, shlmqstep } = { myac, mquo, 1'b0 };

    // each step in arith shift right
    wire[11:00] asracstep, asrmqstep;
    assign { asracstep, asrmqstep } = { myac[11], myac, mquo[11:01] };

    // each step in logical shift right
    wire[11:00] lsracstep, lsrmqstep;
    assign { lsracstep, lsrmqstep } = { 1'b0, myac, mquo[11:01] };

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
    wire _extop64_pc = ~ TP2;
    wire _extop31_pc = ~ (
            s3clk & (extop31 == 1) |                                // SCL done
            s3clk & (extop31 == 2) & (sctr == 12) |                 // MUY done after 12 steps
            s3clk & (extop31 == 3) & (sctr == 0) & (myac >= yreg) | // DVI overflow
            s3clk & (extop31 == 3) & (sctr == 11) |                 // DVI normal
            s3clk & (extop31 == 4) & nmidone |                      // NMI done
            s3clk & (extop31 == 5) & countedshiftdone |             // SHL done
            s3clk & (extop31 == 6) & countedshiftdone |             // ASR done
            s3clk & (extop31 == 7) & countedshiftdone               // LSR done
        );

    always @(posedge extop_clk or negedge _extop64_pc) begin
        if (~ _extop64_pc) extop64 <= 0;
        else extop64 <= extop_dat[6:4];
    end

    always @(posedge extop_clk or negedge _extop31_pc) begin
        if (~ _extop31_pc) extop31 <= 0;
        else extop31 <= extop_dat[3:1];
    end


    // hold processor at beginning of TS3 while doing step 3
    wire HOLD_clk = TS3;
    wire HOLD_dat = extarexec;
    wire _HOLD_pc = (extop64 != 0) | (extop31 != 0);

    always @(posedge HOLD_clk or negedge _HOLD_pc) begin
        if (~ _HOLD_pc) HOLD <= 0;
        else HOLD <= HOLD_dat;
    end

    // output results to processor
    // it clocks them in at TP3
    wire outit = TS3 & extarexec;
    assign ACCLEAR = outit ? 1'b1 : 1'bZ;
    assign IOSKIP  = outit ? 1'b1 : 1'bZ;
    assign INBUS   = outit ? myac : 12'hZZZ;
    assign LNKTOG  = outit ? LINK ^ myln : 1'bZ;

    // perform step 3 clocking while processor holding at beginning of TS3
    wire s3clk_clk = CLOK2;
    wire s3clk_dat = ~ s3clk;
    wire _s3clk_pc = HOLD;

    always @(posedge s3clk_clk or negedge _s3clk_pc) begin
        if (~ _s3clk_pc) s3clk <= 0;
        else s3clk <= s3clk_dat;
    end

    // internal copy of link
    wire myln_dat =
        TS1 & msfetch ? LINK :                                  // get link during fetch
        TS3 & (extop31 == 2) ? 0 :                              // multiply link is always 0
        TS3 & (extop31 == 3) ? myac >= yreg :                   // divide link is overflow (first step only)
        TS3 & (extop31[3:2] == 2) ? shllnstep :                 // shift left link
        TS3 & (extop31[3:2] == 3) ? 0 :                         // shift right link always 0
            myln;

    wire myln_clk =
        TP1 & msfetch |                                         // get link during fetch
        s3clk & (extop31[3:2] == 1) & (sctr == 0) |             // clear link first step of multiply
                                                                // overflow detect first step of divide
        s3clk & (extop31 == 4) & ~ nmidone |                    // normalize step link
        s3clk & countedshift;                                   // shift left, shift right

    always @(posedge myln_clk) begin
        myln <= myln_dat;
    end


    wire[11:00] myac_dat =
        TS1 & msfetch ? (INBUS[07] ? 0 : ACUM) :                // get accumulator during fetch
        TS2 &  msexec           ? myacstep2 :                   // update accumulator for step 2
        TS3 & (extop31 == 2) ? muyacstep :                      // update accumulator for multiply
        TS3 & (extop31 == 3) ? dviacstep :                      // update accumulator for divide
        TS3 & (extop31[3:2] == 2) ? shlacstep :                 // update accumulator for shift left
        TS3 & (extop31 == 6) ? asracstep :                      // update accumulator for shift right
        TS3 & (extop31 == 7) ? lsracstep :                      // update accumulator for shift right
            myac;

    wire myac_clk =
        TP1 & msfetch |                                         // get acum during fetch
        TP2 &  msexec & (extop64 != 0) |                        // update acum during step 2 (MQL,SCA,MQA)
        s3clk & (extop31 == 2) & (sctr != 12) |                 // accumulator for each step of multiply
        s3clk & (extop31 == 3) & (sctr != 0 | myac < yreg) |    // accumulator for divide steps
        extop31[3] & myln_clk;                                  // accumulator for shifts same as link

    always @(posedge myac_clk) begin
        myac <= myac_dat;
    end


    wire[11:00] mquo_dat =
        TS2 & extop64[4] ? myac :                               // get from accum for step 2
        TS3 & (extop31 == 2) ? muymqstep :
        TS3 & (extop31 == 3) ? dvimqstep :
        TS3 & (extop31[3:2] == 2) ? shlmqstep :                 // NMI,SHL
        TS3 & (extop31 == 6) ? asrmqstep :                      // ASR
        TS3 & (extop31 == 7) ? lsrmqstep :                      // LSR
            mquo;

    wire mquo_clk =
        TP2 & msexec & extop64[4] |                             // load mquo from acum in step 2
        s3clk & (extop31 == 2) & (sctr != 12) |                 // mult/quo for each step of multiply
        s3clk & (extop31 == 3) & (sctr != 0 | myac < yreg) |    // mult/quo for divide steps
        extop31[3] & myln_clk;                                  // mult/quo for shifts same as link

    always @(posedge mquo_clk or posedge BUSINI) begin
        if (BUSINI) mquo <= 0;
        else mquo <= mquo_dat;
    end


    wire[4:0] sctr_dat =
        TS1 & msfetch ? 5'b0 :                                  // clear during fetch for MUY,DVI,NMI
        TS3 & (extop31 == 1) ? ~ yreg[04:00] :                  // load sctr from memory
            sctr;

    wire sctr_clk =
        TP1 & msfetch & extar_dat & ((INBUS[3:2] == 2) | (INBUS[3:1] == 4)) |
        s3clk & (extop31 == 1);                                 // load sctr from memory

    wire sctr_inc =
        s3clk & (extop31[3:2] == 1) |                           // multiply or divide, increment count
        s3clk & (extop31 == 4);                                 // normalize, increment count

    always @(posedge sctr_clk or posedge sctr_inc or posedge BUSINI) begin
        if (BUSINI) sctr <= 0;
        if (sctr_inc) sctr <= sctr + 1;
        else sctr <= sctr_dat;
    end


    wire[11:00] yreg_dat = INBUS;
    wire yreg_clk = TP1 & msexec;                               // load YREG from memory during EXEC cycle
    wire yreg40_dec = s3clk & countedshift;                     // TP3 decrement YREG for counted shifts

    always @(posedge yreg_clk or posedge yreg40_dec) begin
        if (yreg40_dec) yreg[04:00] <= yreg[04:00] - 1;
        else yreg <= yreg_dat;
    end

endmodule
