
module DFF #(parameter W=1) (
    input T, PC, PS,
    input[W-1:0] D,
    output reg[W-1:0] Q, _Q);

    always @(posedge PC or posedge PS or posedge T) begin
        if (PC | PS) begin
             Q <= { W { PS } };
            _Q <= { W { PC } };
        end else begin
             Q <=   D;
            _Q <= ~ D;
        end
    end
endmodule

module JKFF (
    input J, K, T, PC, PS,
    output reg Q, _Q);

    always @(posedge PC or posedge PS or posedge T) begin
        if (PC | PS) begin
             Q <= PS;
            _Q <= PC;
        end else begin
            case ({ J, K })
                0: begin end
                1: begin Q <= 0;  _Q <= 1; end
                2: begin Q <= 1;  _Q <= 0; end
                3: begin Q <= _Q; _Q <= Q; end
            endcase
        end
    end
endmodule
