
Verimain simulates the circuit boards (including the Zynq)
plugged into a backplane.

Primary purpose of verimain is to test the circuit board
designs, using realistic propagation delays of chips on
the circuit boards.  The chip delays are given in
chips-varns.v.

Must have Verilator installed.

It converts the various kicad_pcb files to Verilog using a
Java program then uses Verilator to convert those files to C++.

The simtest.sh script uses verimain to thoroughly test the
circuit board designs, including dma, pio and the Zynq.  It
generates random opcodes and operands then makes sure the
designs respond correctly.  Put $display() calls in the
various .v files for debugging.

Test using console.kicad_sch internal scanning circuits:
    export usefpi2c=0
    ./simtest.sh

Test using zynq pdp8ifpi2c.v scanning circuits:
    export usefpi2c=1
    ./simtest.sh

Use faster clocking for stress testing:
    export clkratm1=9   # 100nS => 1.50uS mem cycle (default)
    export clkratm1=8   #  90nS => 1.35uS mem cycle
    export clkratm1=7   #  80nS => 1.20uS mem cycle
    export clkratm1=6   #  70nS => 1.05uS mem cycle (doesn't work)

Script ./last.sh prints every 100th instruction and saves
all of the last 4M output in case of error.

