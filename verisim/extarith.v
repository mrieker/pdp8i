
// small computer handbook 1973
// pages 5-1... just the mode A parts
// states mode A works like pdp-8/i

module extarith (
    input CLOK2,                // 10MHz clock
    input BUSINI,               // power-on reset

    // bus signals
    output reg PAUSE,           // pause processor clocking (stretch cycle)
    inout ACCLEAR,              // io pulse clears AC
    inout IOSKIP,               // increment PC at end of IO pulse
    inout LNKTOG,               // toggle link register
    inout[11:00] INBUS,         // data being read from memory
    input[11:00] MBUF,          // memory operand
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

    reg extar, memop, myln;
    reg[11:00] mquo, myac;
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

    // memory operand for SCL,MUY,DVI,SHL,ASR,LSR
    wire[11:00] yreg = MBUF;

    // each step in multiply
    wire muymbit = mquo[00];    // set means add yreg to shifted product in myac,mquo
    wire[11:00] muyacstep, muymqstep;
    assign { muyacstep, muymqstep[11] } = { 1'b0, myac } + { 1'b0, yreg };
    assign muymqstep[10:00] = mquo[11:01];

    // each step in divide
    reg dviover;
    wire _dviover_pc = TS3;
    always @(posedge s3clk or negedge _dviover_pc) begin
        if (~ _dviover_pc) dviover <= 0;
        else dviover <= myac >= yreg;
    end
    wire dvicary;
    wire[11:00] dviacstep;
    assign { dvicary, dviacstep } = { 1'b0, myac[10:00], mquo[11] } + { 1'b0, ~ yreg } + 1;
    wire dviqbit = myac[11] | dvicary;
    wire[11:00] dvimqstep = { mquo[10:00], dviqbit };   // shift quotient bit into bottom of MQ

    // each step in shift left (also works for normalize, and divide when not subtracting)
    wire shllnstep;
    wire[11:00] shlacstep, shlmqstep;
    assign { shllnstep, shlacstep, shlmqstep } = { myac, mquo, 1'b0 };

    // each step in shift right (also works for multiply when not adding)
    wire shrlnstep = extop31[1] ? 1'b0 : myac[11];
    wire[11:00] asracstep = { myac[11], myac[11:01] };
    wire[11:00] lsracstep = {     1'b0, myac[11:01] };
    wire[11:00] shrmqstep = { myac[00], mquo[11:01] };

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
    //                         TS3 stretched by PAUSE
    wire[6:1] extop_dat = INBUS[06:01];
    wire extop_clk = TP1 & msfetch;

    always @(posedge extop_clk) begin
        extop64 <= extop_dat[6:4];
        extop31 <= extop_dat[3:1];
    end


    // pause processor at beginning of TS3 while doing step 3
    // resume when termination condition is met
    wire pause_dat =
            (extop31 == 2) & ~ sctr[5] |                // MUY done when 12 s3clk pulses have been generated
            (extop31 == 3) & ~ sctr[5] & ~ dviover |    // DVI done when 12 s3clk pulses or when overflow
            (extop31 == 4) & ~ nmidone |                // NMI done when NMI condition met
            countedshift   & ~ sctr[5];                 // shifts done when given number s3clk pulses generated
    assign PAUSE = TS3 & extarex & pause_dat;

    // perform step 3 clocking while processor pausing at beginning of TS3
    // make sure all pulses have full width
    // directly increments sctr
    // loads shift-by-shift results in myac,mquo
    reg s3clk_0, s3clk_1;
    wire s3clk = extop31[3] ? s3clk_0 : s3clk_1;        // _0: 200nS; _1: 300nS per shift
    wire s3clk_inc = ~ (~ PAUSE | s3clk);

    always @(posedge CLOK2) begin
        s3clk_1 <= s3clk_inc & s3clk_0;
        s3clk_0 <= s3clk_inc;
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
    //  s3clk - clocks while pausing to step through multiply,divide,shifts
    //          exactly 12 pulses for MUY
    //          exactly 12 pulses for DVI without overflow
    //          exactly -yreg[4:0] pulses for SHL,ASR,LSR
    //          variable number for NMI (counted by sctr)
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
    wire muy_lsr = (extop31 == 2) & ~ muymbit;  // MUY step behaves like LSR if multiplier bit is 0
    wire dvi_shl = (extop31 == 3) & ~ dviqbit;  // DVI step behaves like SHL if quotient bit is 0

    wire acsel_z = TS1 & INBUS[07];             // force output 0000 when fetching opcode with CLA bit set

        //  acsel  condition
        //    0    TS1 & msfetch                                    - get initial ACUM contents into MYAC
        //    1    TS2 & extarex                                    - get step 2 results into ACUM
        //    2    TS3 & (extop31 == 2 & muymbit)                   - MUY step with multiplier bit set
        //    3    TS3 & (extop31 == 3 & dviqbit)                   - DVI step with quotient bit set
        //    4    TS3 & (extop31 == 4 | extop31 == 3 & ~ dviqbit)  - shift left for NMI or DVI step with quotient bit clear
        //    5    TS3 & (extop31 == 5)                             - shift left for SHL
        //    6    TS3 & (extop31 == 6)                             - shift right for ASR
        //    7    TS3 & (extop31 == 7 | extop31 == 2 & ~ muymbit)  - shift right for LSR or MUY step with multiplier bit clear

    wire[2:0] acsel;
    assign acsel[2] =       TS3 &  (dvi_shl |  muy_lsr | extop31[3]);
    assign acsel[1] =       TS3 & ~ dvi_shl & (muy_lsr | extop31[2]);
    assign acsel[0] = TS2 | TS3 &  muy_lsr  |      TS3 & extop31[1];

    wire[11:00] myac_mux =
        acsel_z ? 12'o0000 :                    // fetch with CLA set   - get 0000 for myac
        (acsel == 0) ? ACUM :                   // fetch with CLA clear - get ACUM contents
        (acsel == 1) ? myacstep2 :              // exec step 2 results
        (acsel == 2) ? muyacstep :              // exec MUY with multiplier bit set, get shifted and summed value
        (acsel == 3) ? dviacstep :              // exec DVI with quotient bit set, get shifted and diffed value
        (acsel == 4) ? shlacstep :              // exec NMI get shifted value
        (acsel == 5) ? shlacstep :              // exec SHL or DVI with quo bit clear, get shifted value
        (acsel == 6) ? asracstep :              // exec ASR, get shifted value
        (acsel == 7) ? lsracstep :              // exec LSR or MUY with mul bit clear, get shifted value
            12'o7777;

    wire myac_clk =
        TP1 & msfetch |                         // get acum during fetch
        TP2 & extarex |                         // update acum during step 2 (MQL,SCA,MQA)
        s3clk;                                  // accumulator for MUY,DVI,shift steps

    always @(posedge myac_clk) begin
        shllink <= TS3 ? shllnstep : LINK;      // init from LINK in case NMI with no shifts
                                                // otherwise save bit shifted out top of myac
        myac <= myac_mux;
    end

    // multiplier/quotient
    wire[2:0] mqsel = acsel;

    wire[11:00] mquo_mux =
        (mqsel == 1) ? myac      :              // exec step 2 results (clock in myac only if MQL)
        (mqsel == 2) ? muymqstep :              // exec MUY with multiplier bit set, get shifted and summed value
        (mqsel == 3) ? dvimqstep :              // exec DVI with quotient bit set, get shifted and diffed value
        (mqsel == 4) ? shlmqstep :              // exec NMI get shifted value
        (mqsel == 5) ? shlmqstep :              // exec SHL or DVI with quo bit clear, get shifted value
        (mqsel == 6) ? shrmqstep :              // exec ASR, get shifted value
        (mqsel == 7) ? shrmqstep :              // exec LSR or MUY with mul bit clear, get shifted value
            12'o7777;

    wire mquo_clk =
        TP2 & extarex & extop64[4] |            // load mquo from acum in step 2 (MQL)
        s3clk;                                  // mult/quo for MUY,DVI,shift steps

    always @(posedge mquo_clk or posedge BUSINI) begin
        if (BUSINI) mquo <= 0;
        else mquo <= mquo_mux;
    end

    // shift count
    wire sctr_zer = (extop31      == 4);        // load  0 at TP2 for NMI
    wire sctr_sel = (extop31[3:2] == 1);        // load 20 at TP2 for MUY,DVI

    wire[5:0] sctr_mux =
        sctr_zer ?  0 :
        sctr_sel ? 20 :
            { 1'b0, ~ yreg[04:00] };            // load from memory at TP2 for SCL,SHL,ASR,LSR

    wire sctr_clk = TP2 & extarex & (extop31 != 0);

    wire sctr_inc = s3clk;                      // increment count for MUY,DVI,NMI,SHL,ASR,LSR

    always @(posedge sctr_clk or posedge sctr_inc or posedge BUSINI) begin
        if (BUSINI) sctr <= 0;
        else if (sctr_inc) sctr <= sctr + 1;
        else sctr <= sctr_mux;
    end

endmodule
