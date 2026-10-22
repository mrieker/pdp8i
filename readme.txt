
Re-implementation of a PDP-8/I processor using
currently available 74HC series DIP-form chips.
Includes extended arithmetic, 32KW memory and a
TTY interface.

Interfaces to a PiDP-8/I panel, taking the place of
the RasPI.

Optionally can use a ZTurn Zynq board to provide
additional I/O device emulation and TCL script
console access.  The Zynq also contains Verilog
equivalents of the circuit boards so can be used
for debugging and testing the board designs and
software with or without the physical circuit
boards.

Must have either the PiDP-8/I panel or the Zynq
board or both.

The circuit is a re-design using currently available
74AC, 74AHC and 74HC series chips.  It uses a 10MHz
signal for timing instead of delay lines.  It
preserves the TS1,TS2,TS3,TS4 timing states for the
most part.  In this design, TS1 takes 300nS (three
10MHz cycles), TS2,3,4 each take 400nS (four 10MHz
cycles), giving an overall cycle time of 1.5uS.

    TS1 - read memory into MBUF
    TS2 - compute memory update into MBUF
    TS3 - write memory from MBUF
          compute then write ACUM,LINK update
    TS4 - compute next major state
          including extended memory address

    The corresponding TPn occurs during last 100nS of
    the TSn.

If present, the ZTurn board provides the 10MHz signal,
allowing the Zynq full control of the clock for testing.
Otherwise it must on a separate board.

I/O instructions are also 1.5uS instead of being extended
to 4.25uS.  There is just one io pulse regardless of the
low three opcode bits that occurs starting 100nS into TS2
and ends at end of TS3.  I/O devices can use TP2 or TP3 to
clock data coming from the processor (from ACUM bus lines).
The processor clocks data from the I/O device (ACCLEAR,
INBUS, IOSKIP bus lines) at TP3.  An I/O device can extend
TS3 by asserting PAUSE starting in TS2.

The major states are the same (FETCH, DEFER, EXEC, WRDCT,
CURAD, BREAK), but with the addition of:

    INTAK - save and clear DF,IF registers, write PC to 00000,
            clear interrupt enable, jump to 00001
    DEPOS - do memory write in response to DEP switch
    EXAM  - do memory read in response to LDAD or EXAM switch

When halted, all four of TS1,2,3,4 are negated.  The state
info in the registers indicates what is going to happen next,
as halting occurs at the end of TS4 which establishes the next
major state.  Pressing CONT will start TS1 with whatever is in
the registers.

Directories:

    ccode    - C programs that run on the Zynq
    demos    - some PDP-8/I programs
    kicads   - circuit boards
    verisim  - Verilator for testing circuit design
    zplin    - Zynq compatible Linux (softlink to pdp8l repo zplin)
    zynq     - Zynq Verilog code

Website:  https://www.outerworldapps.com/8ipics/

