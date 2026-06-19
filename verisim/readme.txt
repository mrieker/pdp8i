
Verimain simulates the circuit boards (including the Zynq)
plugged into a backplane.

Primary purpose of verimain is to test the circuit board
design, using realistic propagation delays of chips on
the circuit boards.  The chip delays are given in
chips-varns.v.

Must have Verilator installed.

The simtest.sh script uses verimain to thoroughly test the
circuit boards, including dma, pio and the Zynq.  It
generates random opcodes and operands then makes sure the
circuit responds correctly.  Put $display() calls in the
various .v files for debugging.

Test using console.kicad_sch internal scanning circuits:
    export usefpi2c=0
    ./simtest.sh

Test using zynq pdp8ifpi2c.v scanning circuits:
    export usefpi2c=1
    ./simtest.sh

Script ./last.sh prints every 100th instruction and saves
all of the last 4M output in case of error.

