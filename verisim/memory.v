
module memory (
    input zclock,               // fpga 100MHz clock
    input zreset,               // fpga reset

    input ts1,
    input ts3,
    input[14:00] xadr,
    input[11:00] mbuf,
    output reg[11:00] mbus
);

    reg[11:00] memarray[32767:0];

    always @(posedge zclock) begin
        if (ts1) begin
            mbus <= memarray[xadr];
        end
        if (ts3) begin
            memarray[xadr] <= mbuf;
        end
    end
endmodule
