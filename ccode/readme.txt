
These programs normally run on the zynq board to
provide access to the simulated i/o devices.  They
can also be used for testing and debugging the
processor.

For example, to access the tty, use z8itty.
To access front panel with TCL scripting, use z8ipanel.
Pass -? to each program for help.

    z8idump  - dumps out zynq register page
    z8iila   - dumps out zynq internal cycle trace array
    z8ipanel - access front panel
    z8ipbit  - access simulated audio pulse bit
    z8iptp   - access simulated paper tape punch
    z8iptr   - access simulated paper tape reader
    z8irk8je - access simulated RK05
    z8itc08  - access simulated dectape
    z8itty   - access simulated tty
    z8ivc8   - access simulated video

The zynq has its own internal copy of the circuit
boards so can run all by itself.  Use the -sim
option of z8ipanel to enable the simulator.  Then
all the programs should work.  The zynq does not
need to be plugged into the backplane for the sim
to work.

These programs can also be compiled on a Linux PC.
It will use verilator to build an equivalent of the
zynq board which can be used for debugging zynq code
(eg, by putting in $display() calls).  It runs approx
200x slower than the real thing.  Just run verizynq
in background (./verizynq.x86_64 &), then put it in
simulator mode with './z8ipanel -sim'.  Now all the
z8i... programs should work.  For example:

    $ ./verizynq.x86_64 & (or run in separate window)
    $ cd ../demos
    $ ../ccode/z8ipanel -sim bootos8dpack.tcl
        give it 40sec or so to boot
        control-\ when done
    $ killall verizynq.x86_64

For testing the circuit board designs, see
readme.txt in the verisim directory.

