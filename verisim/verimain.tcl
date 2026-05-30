
# assemble the given opcode and deposit in memory
proc assem {addr args} {
    wrmem $addr [asmop $addr $args]
}

# convert character to integer
proc chartoint {cc} {
    if {$cc == ""} {return -1}
    scan $cc "%c" ii
    return [expr {$ii & 0377}]
}

# disassemble the given range of memory
proc disas {loaddr {hiaddr ""}} {
    if {$hiaddr == ""} {set hiaddr $loaddr}
    for {set addr $loaddr} {$addr <= $hiaddr} {incr addr} {
        set opcd [rdmem $addr]
        puts [format "  %04o:%04o  %s" $addr $opcd [disop $addr $opcd]]
    }
}

proc dumpit {} {
    set pctr [octal [bus pctr]]
    set madr [octal [bus oMADR]]
    set mbuf [octal [bus oMBUF]]
    set link [bus oLINK]
    set acum [octal [bus oACUM]]
    set mquo [octal [bus mquo]]
    set run  [bus oRUN]
    set majst [bus majst]
    return "ST=$majst PC=$pctr MA=$madr MB=$mbuf L.AC=$link.$acum MQ=$mquo RUN=$run"
}

# get environment variable, return default value if not defined
proc getenv {varname {defvalu ""}} {
    return [expr {[info exists ::env($varname)] ? $::env($varname) : $defvalu}]
}

# get character sent by pdp to tty printer
proc getttypr {} {
    if {([bus set armraddr 040 get armrdata] & 0xFFFFF000) != 0x54541000} {error "bad tty device"}
    set pr [bus set armraddr 042 get armrdata]
    if {! ($pr & 0x40000000)} {return -1}
    bus set armwaddr 042 armwdata 0x80000000 armwrite 1
    return [expr {$pr & 07777}]
}

# reset to power-up state
proc hardreset {} {
    global swrowpends swrowrcvds swrowsents usemcp

    ;# power-on reset for 10uS
    bus set reset 1
    clk 100
    bus set reset 0

    if {$usemcp} {

        ;# reset leaves iicsel = 1111, ie, using console board internal counter

        ;# save toggles (SSTEP,SINST) from row 2, assume buttons (CONT,DEPOS,EXAM,LDAD,START,STOP) are off
        set savetogs [expr {[lindex $swrowpends 2] & 0060}]

        ;# set START and SSTEP switches which asserts BUSINIT without starting processor
        ;# leave them on so processor won't start while flipping switches
        iic wr 0x40 wr 0x14 wr 0240 wr 0240 ;# select switch row 2, data 4040
        while {[iic] == ""} clk
        iic wr 0x40 wr 0x00 wr 0000 wr 0000 ;# set all pins to outputs
        while {[iic] == ""} clk
        iic wr 0x40 wr 0x14 wr 0240 wr 0340 ;# select switch row 3, data 4040
        while {[iic] == ""} clk             ;# (clocks 1s into swSSTEP,START, 0s into swCONT,DEPOS,EXAM,LDAD,SINST,STOP)

        ;# turn off START switch, leave SSTEP on so it won't start on a glitch
        iic wr 0x40 wr 0x14 wr 0240 wr 0200 ;# select switch row 2, data 0040
        while {[iic] == ""} clk
        iic wr 0x40 wr 0x14 wr 0240 wr 0300 ;# select switch row 3, data 0000
        while {[iic] == ""} clk             ;# (clocks 0 into swSTART)

        ;# restore row 2 toggles (SSTEP,SINST)
        set r2a [expr {$savetogs | 0200}]
        iic wr 0x40 wr 0x14 wr $r2a wr 0200 ;# select switch row 2, data 00x0
        while {[iic] == ""} clk
        iic wr 0x40 wr 0x14 wr $r2a wr 0300 ;# select switch row 3, data 00x0
        while {[iic] == ""} clk             ;# (clocks restored values into swSSTEP,START)

        ;# switch row 2 is just the toggles now
        lset swrowpends 2 $savetogs
        lset swrowrcvds 2 $savetogs
        lset swrowsents 2 $savetogs
    }
    return ""
}

# print help for commands defined herein
proc helpini {} {
    puts ""
    puts "  assem <addr> <args...>           - assemble instruction and deposit into memory"
    puts "  chartoint <cc>                   - convert one-character string to integer"
    puts "  disas <loaddr> <<hiaddr \"\">>     - disassemble instruction(s)"
    puts "  dumpit                           - dump processor registers"
    puts "  getenv <varname> <<defvalu \"\">>  - read environment variable"
    puts "  getttypr                         - read tty printer char"
    puts "  hardreset                        - do power-on reset"
    puts "  inttochar <ii>                   - convert integer to one-character string"
    puts "  isztest                          - deposit simple isz test program & start it"
    puts "  light <args...>                  - read given lights via gpio connector"
    puts "  lights                           - read all lights via gpio connector"
    puts "  loadbin <fname>                  - load bin tape file"
    puts "  loadverify <verify>              - verify loadbin"
    puts "  octal <n>                        - convert number to 4-digit octal string"
    puts "  rdmem <addr>                     - read memory location via examine"
    puts "  runloop <<n \"\">>                 - run <n> cpu cycles, update lights & switches"
    puts "  runstep                          - run single cpu cycle, update lights & switches"
    puts "  startat <addr>                   - reset processor and start at given address"
    puts "  swtch <args...>                  - access switches via gpio connector"
    puts "  swtchwait <name> <valu>          - set switch value, wait for it to soak in"
    puts "  waithalt <<n \"\">>                - run cpu cycles until halted"
    puts "  waitrun <<n 20000>>              - run cpu cycles until running"
    puts "  wrmem <addr> <data>              - write memory location via deposit"
    puts ""
}

# convert integer to character
proc inttochar {ii} {
    if {$ii < 0} {return ""}
    return [format "%c" [expr {$ii & 0377}]]
}

# deposit simple test program in memory
# followed with 'runloop' command to run it
proc isztest {} {
    hardreset
    assem 0100 ISZ 0110
    assem 0101 JMP 0100
    assem 0102 IAC
    assem 0103 JMP 0100
    disas 0100 0103
    startat 0100
}

# read a light bulb
set lightrows {0 0 0 0 0 0 0 0}
proc light {args} {
    global lightrows

    set retval ""
    set len [llength $args]

    set lbrow5 [lindex $lightrows 5]
    set lbrow6 [lindex $lightrows 6]
    set lbrow7 [lindex $lightrows 7]

    for {set i 0} {$i < $len} {incr i} {
        set lb [lindex $args $i]
        switch $lb {
            ac {lappend retval [lindex $lightrows 3]}
            df {
                lappend retval [expr {($lbrow7 >> 9) & 7}]
            }
            get { }
            if {
                lappend retval [expr {($lbrow7 >> 6) & 7}]
            }
            ion {
                lappend retval [expr {($lbrow6 >> 9) & 1}]
            }
            ir {
                set opcd ""
                if {$lbrow5 & 0x800} {append opcd "AND"}
                if {$lbrow5 & 0x400} {append opcd "TAD"}
                if {$lbrow5 & 0x200} {append opcd "ISZ"}
                if {$lbrow5 & 0x100} {append opcd "DCA"}
                if {$lbrow5 & 0x080} {append opcd "JMS"}
                if {$lbrow5 & 0x040} {append opcd "JMP"}
                if {$lbrow5 & 0x020} {append opcd "IOT"}
                if {$lbrow5 & 0x010} {append opcd "OPR"}
                lappend retval $opcd
            }
            l {
                lappend retval [expr {($lbrow7 >> 5) & 1}]
            }
            ma {lappend retval [lindex $lightrows 1]}
            mb {lappend retval [lindex $lightrows 2]}
            mq {lappend retval [lindex $lightrows 4]}
            pau {
                lappend retval [expr {($lbrow6 >> 8) & 1}]
            }
            pc {lappend retval [lindex $lightrows 0]}
            run {
                lappend retval [expr {($lbrow6 >> 7) & 1}]
            }
            sc {
                lappend retval [expr {($lbrow6 >> 2) & 31}]
            }
            st {
                set stat ""
                if {$lbrow5 & 0x008} {append stat "FET"}
                if {$lbrow5 & 0x004} {append stat "EXE"}
                if {$lbrow5 & 0x002} {append stat "DEF"}
                if {$lbrow5 & 0x001} {append stat "WCT"}
                if {$lbrow6 & 0x800} {append stat "CAD"}
                if {$lbrow6 & 0x400} {append stat "BRK"}
                lappend retval $stat
            }
            default {
                error "bad light $lb"
            }
        }
    }
    return $retval
}

# get all lights in formatted string
proc lights {} {
    set deco [light pc ma mb ac mq ir st ion pau run sc df if l]
    set pctr [octal [lindex $deco 0]]
    set madr [octal [lindex $deco 1]]
    set mbuf [octal [lindex $deco 2]]
    set acum [octal [lindex $deco 3]]
    set mquo [octal [lindex $deco 4]]
    set opcd [lindex $deco 5]
    set stat [lindex $deco 6]
    set ion  [lindex $deco 7]
    set pau  [lindex $deco 8]
    set run  [lindex $deco 9]
    set sc   [format "%02o" [lindex $deco 10]]
    set dfld [lindex $deco 11]
    set ifld [lindex $deco 12]
    set link [lindex $deco 13]
    if {$opcd == ""} {set opcd "---"}
    if {$stat == ""} {set stat "---"}
    return "PC=$pctr MA=$madr MB=$mbuf L=$link AC=$acum MQ=$mquo IR=$opcd ST=$stat ION=$ion PAU=$pau RUN=$run SC=$sc DF=$dfld IF=$ifld"
}

# load bin format tape file, return start address
# uses front panel load address, deposit
#  returns
#       -1: successful, no start address
#     else: successful, start address
proc loadbin {fname} {
    set fp [open $fname rb]

    hardreset

    set rubbingout 0
    set inleadin 1
    set state -1
    set addr 0
    set data 0
    set chksum 0
    set offset -1
    set start -1
    set field 0
    set nextaddr -1
    set verify [dict create]

    puts "loadbin: loading $fname..."

    while {true} {
        if {[ctrlcflag]} {
            close $fp
            error "control-C"
        }

        # read byte from tape
        incr offset
        set ch [read $fp 1]
        if {[eof $fp]} {
            close $fp
            error "eof reading loadfile at $offset"
        }
        set ch [chartoint $ch]

        # ignore anything between pairs of rubouts
        if {$ch == 0377} {
            set rubbingout [expr 1 - $rubbingout]
            continue
        }
        if $rubbingout continue

        # 03x0 sets field to 'x'
        # not counted in checksum
        if {($ch & 0300) == 0300} {
            set field [expr {($ch & 0070) >> 3}]
            continue
        }

        # leader/trailer is just <7>
        if {$ch == 0200} {
            if $inleadin continue
            break
        }
        set inleadin 0

        # no other frame should have <7> set
        if {$ch & 0200} {
            close $fp
            error [format "bad char %03o at %d" $ch $offset]
        }

        # add to checksum before stripping <6>
        incr chksum $ch

        # state 4 means we have a data word assembled ready to go to memory
        # it also invalidates the last address as being a start address
        # and it means the next byte is the first of a data pair
        if {$state == 4} {
            dict set verify $addr $data
            puts -nonewline [format "  %05o / %04o\r" $addr $data]
            flush stdout

            # deposit the data
            if {$addr != $nextaddr} {
                swtchwait reg $addr
                swtchwait ldad 1
                swtchwait ldad 0
                waitrun
                waithalt
            }
            swtchwait reg $data
            swtchwait depos 1
            swtchwait depos 0
            waitrun
            waithalt

            # verify resultant lights
            set actma [bus oMADR]
            set actmb [bus oMBUF]
            if {($actma != ($addr & 007777)) || ($actmb != $data)} {
                close $fp
                error [format "%04o %04o showed %04o %04o" $addr $data $actma $actmb]
            }

            # set up for next byte
            set addr [expr {($addr & 070000) | (($addr + 1) & 007777)}]
            set nextaddr $addr
            set start -1
            set state 2
        }

        # <6> set means this is first part of an address
        if {$ch & 0100} {
            set state 0
            incr ch -0100
        }

        # process the 6 bits
        switch $state {
            -1 {
                close $fp
                error [format "bad leader char %03o at %d" $ch $offset]
            }

            0 {
                # top 6 bits of address are followed by bottom 6 bits
                set addr [expr {($field << 12) | ($ch << 6)}]
                set state 1
            }

            1 {
                # bottom 6 bits of address are followed by top 6 bits data
                # it is also the start address if it is last address on tape and is not followed by any data other than checksum
                incr addr $ch
                set start $addr
                set state 2
            }

            2 {
                # top 6 bits of data are followed by bottom 6 bits
                set data [expr {$ch << 6}]
                set state 3
            }

            3 {
                # bottom 6 bits of data are followed by top 6 bits of next word
                # the data is stored in memory when next frame received,
                # as this is the checksum if it is the very last data word
                incr data $ch
                set state 4
            }

            default abort
        }
    }

    close $fp
    puts ""

    # trailing byte found, validate checksum
    set chksum [expr {$chksum - ($data & 63)}]
    set chksum [expr {$chksum - ($data >> 6)}]
    set chksum [expr {$chksum & 07777}]
    if {$chksum != $data} {
        error [format "checksum calculated %04o, given on tape %04o" $chksum $data]
    }

    # verify what was loaded
    loadverify $verify

    return $start
}

# verify memory loaded by bin/rim
#  input:
#   verify = dictionary of addr => data as written to memory
proc loadverify {verify} {
    puts "loadverify: verifying..."
    dict for {xaddr expect} $verify {
        if {[ctrlcflag]} {
            error "control-C"
        }
        set actual [rdmem $xaddr]
        puts -nonewline [format "  %05o / %04o\r" $xaddr $actual]
        flush stdout
        if {$actual != $expect} {
            puts ""
            error [format "%05o was %04o expected %04o" $xaddr $actual $expect]
        }
    }
    puts ""
    puts "loadverify: verify ok"
}

# convert integer 0..4095 to 4-digit octal string
proc octal {n} {
    return [format "%04o" $n]
}

# read word from memory using front-panel switches
proc rdmem {addr} {
    if {($addr < 0) || ($addr > 07777)} {
        error "bad address $addr"
    }
    waithalt 20000
    swtchwait reg $addr
    swtchwait ldad 1
    swtchwait ldad 0
    waitrun
    waithalt 20000
    set data [bus oMBUF]
    for {set i 0} {[light mb] != $data} {incr i} {
        if {$i > 20000} {error "timed out waiting for mb lights"}
        runstep
    }
    return $data
}

# keep clocking processor, interpret changes in gpio
set runquiet 1
proc runloop {{n ""}} {
    if {$n == ""} {
        while {! [ctrlcflag]} {
            runstep
        }
    } else {
        for {set i 0} {($i < $n) && ! [ctrlcflag]} {incr i} {
            runstep
        }
    }
}

# single-step processor, interpret changes in gpio and mcp23017
set lastgpio  0
set mcpltime  0
set mcpltrow -1
set mcpstate  0
set mcpswrow -1
set usemcp    0 ;# 0=gpio only; 1=mcp only; 2=both
proc runstep {} {
    global lastgpio lightrows runquiet
    global mcpltime mcpltrow mcpstate mcpswrow usemcp
    global swrowgpios swrowpends swrowrcvds swrowsents

    ;# kerchunk the 10MHz clock and get cycle count
    set c [clk]

    ;# process a row of lights and switches
    if {$usemcp != 0} {
        ;# use iic/mcp to access lights and switches
        switch $mcpstate {
            0 {
                ;# select next light row for display
                set mcpltrow [expr {($mcpltrow + 1) & 7}]
                ;# set data pins to input mode: 0x00 <= 0x3F3F
                iic wr 0x40 wr 0x00 wr 0x3F wr 0x3F
                set mcpltime 0
                set mcpstate 1
            }

            1 {
                incr mcpltime
                if {[iic] != ""} {
                    ;# keep gpio panel connector data pins from munging bGPIO bus
                    gpio 07777
                    ;# set iicsel selection pins to the row
                    ;#  0x14 <= 1'b0 row<2> 6'b000000
                    ;#  0x15 <=    row<1:0> 6'b000000
                    ;# asserts lb<row>sel and bGPOUT_2<row>
                    ;#  lb<row>sel gates register onto bGPIO
                    ;#  bGPOUT_2<row> tells panel to display on leds
                    set aout [expr {($mcpltrow & 4) << 4}]
                    set bout [expr {($mcpltrow & 3) << 6}]
                    iic wr 0x40 wr 0x14 wr $aout wr $bout
                    set mcpstate 2
                }
            }

            2 {
                incr mcpltime
                if {[iic] != ""} {
                    ;# read light pins from bGPIO: 0x12,0x13
                    iic wr 0x40 wr 0x12 rs wr 0x41 rd rd
                    set mcpstate 3
                }
            }

            3 {
                incr mcpltime
                set val [iic]
                if {$val != ""} {
                    if {$usemcp == 1} {
                        ;# usemcp == 1: save value read from mcp23017
                        lset lightrows $mcpltrow [expr {((($val>>8)&63)|(($val&63)<<6))^07777}]
                    } else {
                        ;# usemcp == 2: value gets read from gpio pins below
                    }
                    set mcpstate 4
                }
            }

            4 {
                ;# wait for light row displayed for 200uS
                if {[incr mcpltime] >= 2000} {
                    switch $usemcp {
                        1 {
                            ;# usemcp == 1: mcp23017 only
                            ;#  swrowpends -> swrowsents -> swrowrcvds
                            ;# maybe update like-numbered switch row
                            ;#  if just displayed light row 0, check switch row 0
                            ;#  if just displayed light row 1, check switch row 1
                            ;#  if just displayed light row 2, check switch row 2
                            if {($mcpltrow <= 2) && ([lindex $swrowpends $mcpltrow] != [lindex $swrowsents $mcpltrow])} {
                                ;# at this point, ldswrow0,1,2 are all high
                                ;# like-numbered switch row needs updating
                                ;# handle it then do next light row
                                set mcpswrow $mcpltrow
                                set swval [lindex $swrowpends $mcpswrow]
                                lset swrowsents $mcpswrow $swval
                                ;# set data pins value to switch row and value:
                                ;#  0x14 <=    2'b10 val<11:06>
                                ;#  0x15 <= row<1:0> val<05:00>
                                ;# only changes one iicsel bit (sets iicsel_3) to avoid glitching ldswrow<n>
                                ;#  smoothly drives ldswrow<n> low
                                set aout [expr {0x80 | ($swval & 63)}]
                                set bout [expr {($mcpswrow << 6) | ($swval >> 6)}]
                                iic wr 0x40 wr 0x14 wr $aout wr $bout
                                set mcpstate 5
                            } else {
                                ;# no switches, do next light row
                                set mcpstate 0
                            }
                        }

                        2 {
                            ;# usemcp == 2: both gpio and mcp23017
                            ;#  swrowpends -> swrowsents -> swrowgpios -> swrowrcvds
                            set mcpswrow [expr {$mcpltrow - 4}]
                            if {($mcpswrow >= 0) && ($mcpswrow <= 2) && ([lindex $swrowpends $mcpswrow] != [lindex $swrowsents $mcpswrow])} {
                                ;# like-numbered switch row needs updating
                                ;# handle it then do next light row
                                set swval [lindex $swrowpends $mcpswrow]
                                lset swrowsents $mcpswrow $swval
                                ;# tell gpio connector to request switch value from panel
                                ;# aout<5:4> is 01, transition to 11.
                                ;# bout<5:4> has light row = switch row
                                iic wr 0x40 wr 0x14 wr 0xC0
                                set mcpstate 10
                            } else {
                                ;# no switches, do next light row
                                set mcpstate 0
                            }
                        }
                    }
                }
            }

            5 {
                ;# waiting for mcp to get the switch value to be sent to flipflops
                ;# and for ldswrow<n> to go low
                if {[iic] != ""} {
                    ;# set data pins to output mode: 0x00 <= 0x0000
                    ;# gates data pins to flipflop inputs
                    iic wr 0x40 wr 0x00 wr 0x00 wr 0x00
                    set mcpstate 6
                }
            }

            6 {
                ;# waiting for mcp to turn output data pins on so flipflops will get data
                if {[iic] != ""} {
                    ;# data outputs turned on, kerchunk value into flipflops
                    set swval [lindex $swrowsents $mcpswrow]
                    if {$swval < 0} {set swval 0}
                    set bout [expr {($mcpswrow << 6) | ($swval >> 6)}]
                    if {$mcpswrow == 0} {
                        ;# doing swrow 0, transition iicsel from 1000 to 1011 might glitch
                        ;# so transition iicsel from 1000 to 1010 first
                        ;# by doing 0x15 <= 2'b10 val<05:00>
                        ;# driving ldswrow0 high (clocking data into swrow0)
                        ;#  with side-effect of driving ldswrow2 low
                        iic wr 0x40 wr 0x15 wr [expr {$bout | 0x80}]
                        set mcpstate 8
                    } else {
                        ;# doing swrow 1 or 2, transition iicsel from 1001 or 1010 to 1011 won't glitch
                        ;# drives ldswrow<n> high
                        ;# so do 0x15 <= 2'b11 val<05:00>
                        iic wr 0x40 wr 0x15 wr [expr {$bout | 0xC0}]
                        set mcpstate 7
                    }
                }
            }

            7 {
                if {[iic] != ""} {
                    ;# new switch value has been clocked into switch flipflops
                    set swval [lindex $swrowsents $mcpswrow]
                    lset swrowrcvds $mcpswrow $swval
                    ;# resume doing lights
                    set mcpstate 0
                }
            }

            8 {
                if {[iic] != ""} {
                    set swval [lindex $swrowsents 0]
                    lset swrowrcvds 0 $swval

                    ;# ldswrow2 is now low after driving ldswrow0 high
                    ;# we must clock in proper swrow2 contents to drive ldswrow2 high
                    ;# ...as idle state of ldswrow0,1,2 is high
                    set mcpswrow 2
                    set swval [lindex $swrowpends 2]
                    set aout [expr {0x80 | ($swval & 63)}]
                    set bout [expr {0x80 | ($swval >> 6)}]
                    iic wr 0x40 wr 0x14 wr $aout wr $bout
                    set mcpstate 5
                }
            }

            10 {
                ;# waiting to finish telling gpio to request switch row from panel
                if {[iic] != ""} {
                    ;# gpio requesting switch row from panel, start reading switch pins: 0x12
                    iic wr 0x40 wr 0x12 rs wr 0x41 rd rd
                    set mcpstate 11
                }
            }

            11 {
                ;# waiting for switch row from gpio connector
                set val [iic]
                if {$val != ""} {
                    ;# it should match what we put on gpio connector
                    set swrcvd [expr {(($val >> 8) & 63) | (($val & 63) << 6)}]
                    set swsent [lindex $swrowsents $mcpswrow]
                    if {$swrcvd != $swsent} {
                        error "received [octal $swrcvd] from gpio, sent [octal $swsent] on sw row $mcpswrow"
                    }
                    ;# start sending that same value back out so it will latch in flipflops
                    ;#  currently have aout = 11xxxxxx; bout = nnxxxxxx  (nn = switch row 0..2)
                    ;#  transition to  aout = 10dddddd; bout = nndddddd
                    ;# only iicsel_2 is changing, so no glitching
                    set aout [expr {0x80 | ($swsent & 63)}]
                    set bout [expr {($mcpswrow << 6) | ($swsent >> 6)}]
                    iic wr 0x40 wr 0x14 wr $aout wr $bout
                    ;# next is to set all pins to output mode
                    set mcpstate 5
                }
            }
        }
    }

    ;# here we pretend to be the panel
    ;# capture what console.kicad_sch is feeding the lights
    ;# send what we want to console.kicad_sch for switches when asked
    set g [gpio]                            ;# read gpio connector contents
    if {$lastgpio != $g} {
        for {set r 0} {$r < 3} {incr r} {   ;# maybe it wants switch contents
            switch $usemcp {
                0 {
                    ;# everything done via gpio - mcp23017 is unused
                    ;# if high-to-low for switch select, capture pending value to be sent
                    if {$lastgpio & ~ $g & (0x1000 << $r)} {
                        set sw [lindex $swrowpends $r]
                        lset swrowsents $r $sw
                    }
                    ;# if low switch select, send the row contents
                    if {~ $g & (0x1000 << $r)} {
                        gpio [lindex $swrowsents $r]
                    }
                    ;# if low-to-high for switch select, console.kicad_sch clocked sent value in
                    if {~ $lastgpio & $g & (0x1000 << $r)} {
                        set sw [lindex $swrowsents $r]
                        lset swrowrcvds $r $sw
                    }
                }
                1 {
                    ;# everything done via mcp23017 - shouldn't ask for switches
                    if {($g & 0x7000) != 0x7000} {
                        error "gpio asking for switches when usemcp == 1"
                    }
                }
                2 {
                    ;# using both - send value via gpio, console.kicad_sch receives into mcp23017
                    ;# if high-to-low for switch select, capture pending value to be sent
                    if {$lastgpio & ~ $g & (0x1000 << $r)} {
                        set sw [lindex $swrowsents $r]
                        lset swrowgpios $r $sw
                    }
                    ;# if low switch select, send the row contents
                    if {~ $g & (0x1000 << $r)} {
                        gpio [lindex $swrowgpios $r]
                    }
                }
            }
        }
        if {($g & 0x7000) == 0x7000} {
            gpio 07777                      ;# if no switches being requested, set to ones to not interfere with lights
        }
        set lastgpio $g                     ;# save gpio to detect edges
        if {$usemcp != 1} {
            set v [expr {~ $g & 07777}]     ;# get the 12-bit row contents
            for {set r 0} {$r < 8} {incr r} {
                if {$g & (0x010000 << $r)} {lset lightrows $r $v}
            }
        }
    }
}

# start processor at the given address
proc startat {addr} {
    if {($addr < 0) || ($addr > 07777)} {
        error "bad address $addr"
    }
    puts "startat: setting swreg $addr"
    swtchwait reg $addr
    puts "startat: pressing ldad"
    swtchwait ldad 1
    puts "startat: releasing ldad"
    swtchwait ldad 0
    puts "startat: pressing start"
    swtchwait start 1
    puts "startat: releasing start"
    swtchwait start 0
    puts "startat: done"
}

# modify and query switch settings
# - set just queues the value, use 'runloop/runstep' to pass them on to processor
# - get retrieves latest value received by processor
set swrowgpios {0 0 0}      ;# passed to gpio connector (usemcp == 2 only)
set swrowpends {0 0 0}      ;# waiting to be sent to processor
set swrowrcvds {0 0 0}      ;# has been received by processor
set swrowsents {-1 -1 -1}   ;# has been sent to processor
set swbuttons {"start" "ldad" "depos" "exam" "cont" "stop" "sstep" "sinst"} 
proc swtch {args} {
    global swbuttons swrowpends swrowrcvds

    set retval ""
    set setmode 0
    set len [llength $args]

    for {set i 0} {$i < $len} {incr i} {
        set sw [lindex $args $i]
        switch $sw {
            df {
                if {$setmode} {
                    set val [lindex $args [incr i]]
                    set row [lindex $swrowpends 1]
                    lset swrowpends 1 [expr {($val << 9) | ($row & 0x1FF)}]
                } else {
                    set row [lindex $swrowrcvds 1]
                    lappend retval [expr {($row >> 9) & 7}]
                }
            }
            get {set setmode 0}
            if {
                if {$setmode} {
                    set val [lindex $args [incr i]]
                    set row [lindex $swrowpends 1]
                    lset swrowpends 1 [expr {($val << 6) | ($row & 0xE3F)}]
                } else {
                    set row [lindex $swrowrcvds 1]
                    lappend retval [expr {($row >> 6) & 7}]
                }
            }
            reg {
                if {$setmode} {
                    set val [lindex $args [incr i]]
                    lset swrowpends 0 [expr {$val + 0}]
                } else {
                    lappend retval [lindex $swrowrcvds 0]
                }
            }
            set {set setmode 1}
            default {
                set bitnum [lsearch $swbuttons $sw]
                if {$bitnum < 0} {
                    error "unknown switch $sw"
                }
                set mask [expr {2048 >> $bitnum}]
                if {$setmode} {
                    set val [lindex $args [incr i]]
                    set row [lindex $swrowpends 2]
                    lset swrowpends 2 [expr {($row & ~ $mask) | ($val ? $mask : 0)}]
                } else {
                    ;# bus sw$sw gets value after debouncing delay
                    lappend retval [bus sw$sw]
                }
            }
        }
    }
    return $retval
}

;# set switch to the given value
;# wait for it to soak through the console circuit
;# ...including any debounce time
proc swtchwait {name valu} {
    swtch set $name $valu
    for {set i 0} {[swtch $name] != $valu} {incr i} {
        if {$i > 50000} {error "timed out setting sw$name to $valu"}
        runstep
    }
}

# wait for processor to halt if it isn't already
proc waithalt {{n ""}} {
    for {set i 0} {[bus oRUN]} {incr i} {
        if {[ctrlcflag]} break
        if {($n != "") && ($i > $n)} {
            error "timed out waiting for halt"
        }
        runstep
    }
}

# wait for processor to run if it isn't already
proc waitrun {{n 20000}} {
    for {set i 0} {! [bus oRUN]} {incr i} {
        if {[ctrlcflag]} break
        if {$i > $n} {
            error "timed out waiting for run"
        }
        runstep
    }
}

# write memory location using front-panel switches
proc wrmem {addr data} {
    if {($addr < 0) || ($addr > 07777)} {
        error "bad address $addr"
    }
    if {($data < 0) || ($data > 07777)} {
        error "bad data $data"
    }
    waithalt 20
    swtchwait reg $addr
    swtchwait ldad 1
    swtchwait ldad 0
    waitrun  20
    waithalt 20
    swtchwait reg $data
    swtchwait depos 1
    swtchwait depos 0
    waitrun
    waithalt 20
    for {set i 0} {[light mb] != $data} {incr i} {
        if {$i > 20000} {error "timed out waiting for mb lights"}
        runstep
    }
}
