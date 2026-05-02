
// generate random dma requests

module dmatest (
    input[7:0] seed,
    input zclock, zreset,

    input armwrite,
    input[1:0] armraddr, armwaddr,
    input[31:00] armwdata,
    output[31:00] armrdata,

    // signals from processor
    input busini, tp2, tp3, ts2, ts3, ts4,
    input[3:0] majst,
    input[11:00] mbuf,

    // signal coming from next inner dma board if any or processor
    input brkgnti,

    // signal going to next outer dma board if any
    output brkgnto,

    // wired-OR of all break requests including our own
    input brkrqst,

    // our dma request outputs to be wired-ORd to bus
    output reg brkrqst_o, cycle3_o, cainc_o, wrmem_o,
    output[2:0] dmafld_o,
    output[11:00] inbus_o
);

    reg enable;
    reg[63:00] lfsr;
    reg[14:00] brkadr;
    reg[11:00] rwdat;

    // our break request has been granted
    wire isgranted = brkrqst_o & brkgnti;
 
    // end of our break cycle = our break request has been granted and processsor is doing a break cycle
    wire endofbrk = isgranted & (majst == 6);

    // sim can read our status via arm port
    assign armrdata = (armraddr == 0) ? 32'h5A441001 : // [31:16] = 'ZD'; [15:12] = (log2 nreg) - 1; [11:00] = version
                      (armraddr == 1) ? { enable,     //31
                                          1'b0,       //30
                                          seed,       //22
                                          brkrqst_o,  //21
                                          cycle3_o,   //20
                                          cainc_o,    //19
                                          wrmem_o,    //18
                                          brkgnto,    //17
                                          brkgnti,    //16
                                          brkrqst,    //15
                                          dmafld_o,   //12
                                          inbus_o     //00
                                        } :
                      (armraddr == 2) ? { 5'b0, brkadr, rwdat } :
                                        32'hDEADBEEF;

    // pass brkgnti to brkgnto unless we are requesting a break
    assign brkgnto = brkgnti & ~ brkrqst_o;

    // output dma field as long as our break request has been granted
    // otherwise output zeroes so it doesn't jam up bus
    assign dmafld_o = isgranted ? brkadr[14:12] : 3'o0;

    // output dma address during TS4 if our break request has been granted
    // output dma data during TS2 of BREAK if our break request has been granted
    // otherwise output zeroes so it doesn't jam up bus
    assign inbus_o = isgranted & ts4 ? brkadr[11:00] :
                     endofbrk & wrmem_o & ts2 ? rwdat :
                     12'o0000;

    always @(posedge zclock or posedge armwrite) begin
        if (zreset & enable) begin
            enable    <= 0;
        end else if (armwrite) begin

            // arm writing enable bit
            case (armwaddr)
                1: enable <= armwdata[31];
            endcase
        end else if (~ enable | busini) begin
            brkrqst_o <= 0;
            cycle3_o  <= 0;
            cainc_o   <= 0;
            wrmem_o   <= 0;
            lfsr <= { seed, 56'h12345678abcde };
        end else begin

            // if our break request has been granted and this is TP2 of a BREAK cycle, drop break request
            if (endofbrk & tp2) begin
                if (~ wrmem_o) rwdat <= mbuf;
                brkrqst_o <= 0;
                cycle3_o  <= 0;
                cainc_o   <= 0;
                wrmem_o   <= 0;
            end

            // otherwise, if nothing, including us, is requesting a break, and break not being granted,
            // ...request a break from time-to-time
            else if (~ brkrqst & ~ brkgnti & (lfsr[63:45] == 0)) begin  // 327.68uS
                brkrqst_o <= 1;
                rwdat     <= lfsr[11:00];
                cycle3_o  <= lfsr[12];
                cainc_o   <= lfsr[13];
                wrmem_o   <= lfsr[14];
                brkadr    <= lfsr[29:15];
            end

            // https://www.xilinx.com/support/documentation/application_notes/xapp052.pdf
            lfsr <= { lfsr[62:51] ^ (endofbrk & tp2 & ~ wrmem_o ? mbuf : 12'o0000), lfsr[50:00], ~ lfsr[63] ^ lfsr[62] ^ lfsr[60] ^ lfsr[59] };
        end
    end
endmodule
