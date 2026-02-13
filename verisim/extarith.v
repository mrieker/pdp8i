
// small computer handbook 1970
// pages p73/v59

module extarith (
    input clok2,                // 10MHz clock
    input reset,                // power-on reset

    // bus signals
    output reg iACCLEAR,        // io pulse clears AC
    output reg iHOLD,           // hold internal clocking (stretch cycle)
    output reg iIOSKIP,         // increment PC at end of IO pulse
    output reg iLNKTOG,         // toggle link register
    output reg[11:00] iINBUS,   // IO data being read from device
    output reg[11:00] iMEMBUS,  // data being read from memory
    input oLINK,                // link register
    input oTP1,                 // time pulses, 200nS each
    input oTP2,                 // ...starting so as to overlap last 100nS of corresponding TSn
    input oTP3,                 // ...usually overlapping first 100nS of subsequent TS(n+1)
    input oTP4,
    input[11:00] oACUM,         // IO data being written to device
    input[11:00] oMBUF,         // data being written to memory

    input[3:0] lbMAJST,

    output reg[11:00] mulq,
    output reg[4:0] sctr
);

`include "msdef.v"

    reg isextar, memop, mylink;
    reg[4:0] bctr;
    reg[6:1] extop;
    reg[11:00] myac, yreg;
    reg[23:00] prod;

    always @(posedge clok2) begin

        if (reset) begin
            isextar <= 0;
            mulq    <= 0;
            sctr    <= 0;
        end

        if (oTP1 & (lbMAJST == MS_FETCH)) begin
            isextar <= (iMEMBUS & 12'o7401) == 12'o7401;            // see if an extended arithmetic opcode is being fetched
            bctr    <= 0;                                           // reset bit counter in case it is needed
            extop   <= iMEMBUS[06:01];                              // save needed extended arithmetic opcode bits
            memop   <= iMEMBUS[02:01] != 0;                         // it includes memory operand
            myac    <= iMEMBUS[07] ? 0 : oACUM;                     // step 1: 0200 CLA - clear accumulator
            mylink  <= oLINK;                                       // initialize local link copy
        end

        if (oTP1 & isextar & (lbMAJST == MS_EXEC)) begin
            yreg   <= iMEMBUS;                                      // local copy of extended operand so we can modify it
            prod   <= 0;
        end

        if ((oTP2 | iHOLD) & isextar & (lbMAJST == (memop ? MS_EXEC : MS_FETCH))) begin
            if (extop == 0) begin
                iACCLEAR <= 1;
                iHOLD    <= 0;
                iINBUS   <= myac;
                iLNKTOG  <= oLINK ^ mylink;
            end else begin
                iHOLD    <= 1;

                // step 2
                if (extop[6:4] != 0) begin
                    if (extop[4]) mulq <= myac;                     // 0020 MQL - load multipler quotient from accumulator

                    myac <= (extop[4] ? 12'b0 : myac) |             // 0020 MQL - load multipler quotient from accumulator
                            (extop[5] ? { 7'b0, sctr } : 12'b0) |   // 0040 SCA - step counter load into accumulator
                            (extop[6] ? mulq : 12'b0);              // 0100 MQA - multiplier quotient load into accumulator

                    extop[6:4] <= 0;                                // step 2 complete
                end

                // step 3
                else case (extop[3:1])

                    // 7401 nop
                    0: begin end

                    // 7403 SCL - step counter load from memory
                    1: begin
                        sctr  <= ~ yreg[04:00];
                        extop <= 0;
                    end

                    // 7405 MUY - multiply: Y * MQ => AC,MQ
                    2: begin
                        if (bctr != 12) begin
                            prod   <= { prod[22:00], 1'b0 } + { 12'b0, (mulq[11] ? yreg : 12'b0) };
                            mulq   <= { mulq[10:00], 1'b0 };
                            bctr   <= bctr + 1;
                        end else begin
                            extop  <= 0;
                            myac   <= prod[23:12];
                            mulq   <= prod[11:00];
                            mylink <= 0;
                        end
                    end

                    // 7407 DVI - divide: AC,MQ / Y => MQ r AC
                    3: begin
                        if ((bctr == 0) & (myac >= yreg)) begin
                            extop  <= 0;
                            mylink <= 1;
                        end else begin
                            if ({ myac, mulq[11] } >= { 1'b0, yreg }) begin
                                { myac, mulq } <= { { { myac[10:00], mulq[11] } - yreg }, mulq[10:00], 1'b1 };
                            end else begin
                                { myac, mulq } <= { myac[10:00], mulq, 1'b0 };
                            end
                            if (bctr != 11) begin
                                bctr <= bctr + 1;
                            end else begin
                                extop  <= 0;
                                mylink <= 0;
                            end
                        end
                    end

                    // 7411 NMI - normalize
                    4: begin
                        if ((myac[11] != myac[10]) | (myac[09:00] == 0) & (mulq == 0)) begin
                            extop <= 0;
                            sctr  <= bctr;
                        end else begin
                            { mylink, myac, mulq } <= { myac, mulq, 1'b0 };
                            bctr  <= bctr + 1;
                        end
                    end

                    // 7413 SHL - shift left
                    5: begin
                        { mylink, myac, mulq } <= { myac, mulq, 1'b0 };
                        if (yreg[04:00] != 0) begin
                            yreg   <= yreg - 1;
                        end else begin
                            extop  <= 0;
                        end
                    end

                    // 7415 ASR - arithmetic shift right
                    6: begin
                        { myac, mulq } <= { myac[11], myac, mulq[11:01] };
                        if (yreg[04:00] != 0) begin
                            yreg   <= yreg - 1;
                        end else begin
                            extop  <= 0;
                            mylink <= myac[11];
                        end
                    end

                    // 7417 LSR - logical shift right
                    7: begin
                        { myac, mulq } <= { 1'b0, myac, mulq[11:01] };
                        if (yreg[04:00] != 0) begin
                            yreg   <= yreg - 1;
                        end else begin
                            extop  <= 0;
                            mylink <= 0;
                        end
                    end
                endcase
            end
        end

        // end of cycle, release bus signals
        if (oTP4) begin
            iACCLEAR <= 0;
            iINBUS   <= 0;
            iLNKTOG  <= 0;
        end
    end
endmodule
