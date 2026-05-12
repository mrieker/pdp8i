
/*

    0)

        forward brkgnti to brkgnto

    1)

        wait for
        * brkrqst negated - nothing requesting a break
        * brkgnti negated - processor not granting a break
        * blockgrantpass negated - we are not doing a break

        output
        * blockgrantpass asserted - block sending brkgnt out to next outer device
        * brkrqst asserted - request a break cycle from processor

    2)

        wait for
        * brkgnti - processor to grant the request

        output
        * dmafld
        * cycle3
        * cainc
        * wrmem

    3)

        wait for
        * TS2 of BREAK cycle

        output
        * data to INBUS if write cycle

        wait for
        * TP2 of BREAK cycle

        clock in
        * MBUF for read data if read cycle
        * BWCOV if 3-cycle

        output
        * brkrqst negated
        * remove write data from INBUS

    4)

        wait for
        * brkgnti negated

        output
        * blockgrantpass negated

*/

// generate random dma requests

module dmatest (
    input[7:0] seed,
    input zclock, zreset,

    input armwrite,
    input[1:0] armraddr, armwaddr,
    input[31:00] armwdata,
    output[31:00] armrdata,

    // signals from processor
    input busini, brkcyc, tp2, tp3, ts2, ts3, ts4,
    input[11:00] mbuf,

    // signal coming from next inner dma board if any or processor
    input brkgnti,

    // signal going to next outer dma board if any
    output brkgnto,

    // wired-OR of all break requests including our own
    input brkrqst,

    // wordcount overflow for 3-cycle break
    input bwcov,

    // our dma request outputs to be wired-ORd to bus
    output reg brkrqst_o, cycle3_o, cainc_o, wrmem_o,
    output[2:0] dmafld_o,
    output[11:00] inbus_o
);

    reg enable, wcover;
    reg[63:00] lfsr;
    reg[14:00] brkadr;
    reg[11:00] rdata, wdata;

    reg cycle3req, caincreq, wrmemreq;

    // our break request has been granted
    wire isgranted = brkrqst_o & brkgnti;
 
    // end of our break cycle = our break request has been granted and processsor is doing a break cycle
    wire endofbrk = isgranted & brkcyc;

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
                      (armraddr == 2) ? { 4'b0, wcover, brkadr, wdata } :
                      (armraddr == 3) ? { 20'b0, rdata } :
                                        32'hDEADBEEF;

    // pass brkgnti to brkgnto unless we are requesting a break
    reg blockgrantpass;
    assign brkgnto = brkgnti & ~ blockgrantpass;

    // output dma field as long as our break request has been granted
    // otherwise output zeroes so it doesn't jam up bus
    assign dmafld_o = isgranted ? brkadr[14:12] : 3'o0;

    assign cycle3_o = isgranted ? cycle3req : 1'b0;
    assign cainc_o  = isgranted ? caincreq  : 1'b0;
    assign wrmem_o  = isgranted ? wrmemreq  : 1'b0;

    // output dma address during TS4 if our break request has been granted
    // output dma write data during TS2 of BREAK if our break request has been granted
    // otherwise output zeroes so it doesn't jam up bus
    assign inbus_o = isgranted & ts4 ? brkadr[11:00] :
                     endofbrk & wrmem_o & ts2 ? wdata :
                     12'o0000;

    reg[31:00] cyclect;
    reg lastisgranted;

    always @(posedge zclock or posedge armwrite) begin
        cyclect <= zreset ? 0 : cyclect + 1;

        if (zreset & enable) begin
            enable <= 0;
        end else if (armwrite) begin

            // arm writing enable bit
            case (armwaddr)
                1: enable <= armwdata[31];
            endcase
        end else if (~ enable | busini) begin
            blockgrantpass <= 0;
            brkrqst_o <= 0;
            lfsr <= { seed, 56'h12345678abcde };
        end else begin

            // if our break request has been granted and this is TP2 of a BREAK cycle, drop break request
            // also clock in wordcount overflow and read data at TP2
            if (endofbrk & tp2) begin
                $display ("dmatest*: %m %x finished mbuf=%o", cyclect, mbuf);
                brkrqst_o <= 0;
                wcover <= bwcov;
                rdata <= mbuf;
            end

            // allow grant to pass to outer circuit when we are all done and processor has dropped our grant
            else if (blockgrantpass & ~ brkrqst_o & ~ brkgnti) begin
                $display ("dmatest*: %m %x all done", cyclect);
                blockgrantpass <= 0;
            end

            // otherwise, if nothing, including us, is requesting a break, and break not being granted,
            // ...request a break from time-to-time
            // block grant from passing to outer circuit.  if outer circuit starts requesting right now,
            // ...it can't possibly receive grant from processor before we block it
            else if (~ brkrqst & ~ brkgnti & ~ blockgrantpass & (lfsr[63:54] == 0)) begin
                $display ("dmatest*: %m %x request dat=%o 3cy=%b cai=%b wrm=%b adr=%o",
                    cyclect, lfsr[11:00], lfsr[12], lfsr[13], lfsr[14], lfsr[29:15]);
                blockgrantpass <= 1;
                brkrqst_o <= 1;
                wdata     <= lfsr[11:00];
                cycle3req <= lfsr[12];
                caincreq  <= lfsr[13];
                wrmemreq  <= lfsr[14];
                brkadr    <= lfsr[29:15];
            end

            // https://www.xilinx.com/support/documentation/application_notes/xapp052.pdf
            lfsr <= { lfsr[62:51] ^ (endofbrk & tp2 & ~ wrmem_o ? mbuf : 12'o0000), lfsr[50:00], ~ lfsr[63] ^ lfsr[62] ^ lfsr[60] ^ lfsr[59] };
        end

        if (~ lastisgranted & isgranted) begin
            $display ("dmatest*: %m %x granted", cyclect);
        end
        lastisgranted <= isgranted;
    end
endmodule
