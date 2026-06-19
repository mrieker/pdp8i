
Re-implementation of a PDP-8/I processor using
currently available 74HC series DIP-form chips.
Includes extended arithmetic, 32KW memory and a
TTY interface.

Interfaces to a PiDP-8/I panel, taking the place of
the RasPI.  Must have either the PiDP-8/I panel or
the Zynq board or both.

Optionally can use a ZTurn Zynq board to provide
additional I/O device emulation and TCL script
console access.  The Zynq also contains Verilog
equivalents of the circuit boards so can be used
for debugging and testing the board designs and
software with or without the physical circuit
boards.

Directories:

    ccode    - C programs that run on the Zynq
    demos    - some PDP-8/I programs
    kicads   - circuit boards
    verisim  - Verilator for testing circuit design
    zplin    - Zynq compatible Linux
    zynq     - Zynq Verilog code

