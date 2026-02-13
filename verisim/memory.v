
module memory (
    input clok2,                // 10MHz clock

    input ts1,                  // read onto mbus
    input ts3,                  // write from mbuf
    input[14:00] xadr,          // 15-bit address
    input[11:00] mbuf,          // write data
    output reg[11:00] mbus      // read data
);

    reg[11:00] memarray[32767:0];

    always @(posedge clok2) begin
        if (ts1) begin
            mbus <= memarray[xadr];
        end
        if (ts3) begin
            memarray[xadr] <= mbuf;
        end
    end
endmodule
