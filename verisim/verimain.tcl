
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
        puts [format "  %04o:  %s" $addr [disop $addr $opcd]]
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
    set pr [bus set armraddr 042 get armrdata]
    if {! ($pr & 0x40000000)} {return -1}
    bus set armwaddr 042 armwdata 0x80000000 armwrite 1
    return [expr {$pr & 07777}]
}

# reset to power-up state
# make sure verimain sees a 0->1 edge on reset
proc hardreset {} {
    bus set reset 1
    clk 10
    bus set reset 0
    clk 10
    bus set reset 1
    clk 980
    bus set reset 0
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
    puts "  mcprd16 <reg>                    - read mcp23017 register pair"
    puts "  mcpwr16 <reg> <val>              - write mcp23017 register pair"
    puts "  mcprdltrow <row>                 - read light row via mcp23017"
    puts "  mcpwrswrow <row> <val>           - write switch row via mcp23017"
    puts "  mcprelease                       - release mcp23017 from lights & switches"
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
            ac {lappend retval [unscramgpio [lindex $lightrows 3]]}
            df {
                set dfld 0
                if {$lbrow7 & 0x400} {incr dfld 4}
                if {$lbrow7 & 0x800} {incr dfld 2}
                if {$lbrow7 & 0x001} {incr dfld 1}
                lappend retval $dfld
            }
            get { }
            if {
                set ifld 0
                if {$lbrow7 & 0x002} {incr ifld 4}
                if {$lbrow7 & 0x004} {incr ifld 2}
                if {$lbrow7 & 0x008} {incr ifld 1}
                lappend retval $ifld
            }
            ion {
                set ion 0
                if {$lbrow6 & 0x001} {incr ion}
                lappend retval $ion
            }
            ir {
                set opcd ""
                if {$lbrow5 & 0x400} {append opcd "AND"}
                if {$lbrow5 & 0x800} {append opcd "TAD"}
                if {$lbrow5 & 0x001} {append opcd "ISZ"}
                if {$lbrow5 & 0x002} {append opcd "DCA"}
                if {$lbrow5 & 0x004} {append opcd "JMS"}
                if {$lbrow5 & 0x008} {append opcd "JMP"}
                if {$lbrow5 & 0x010} {append opcd "IOT"}
                if {$lbrow5 & 0x020} {append opcd "OPR"}
                lappend retval $opcd
            }
            l {
                set link 0
                if {$lbrow7 & 0x010} {incr link}
                lappend retval $link
            }
            ma {lappend retval [unscramgpio [lindex $lightrows 1]]}
            mb {lappend retval [unscramgpio [lindex $lightrows 2]]}
            mq {lappend retval [unscramgpio [lindex $lightrows 4]]}
            pau {
                set pau 0
                if {$lbrow6 & 0x002} {incr pau}
                lappend retval $pau
            }
            pc {lappend retval [unscramgpio [lindex $lightrows 0]]}
            run {
                set run 0
                if {$lbrow6 & 0x004} {incr run}
                lappend retval $run
            }
            sc {
                set sc 0
                if {$lbrow6 & 0x008} {incr sc 16}
                if {$lbrow6 & 0x010} {incr sc  8}
                if {$lbrow6 & 0x020} {incr sc  4}
                if {$lbrow6 & 0x040} {incr sc  2}
                if {$lbrow6 & 0x080} {incr sc  1}
                lappend retval $sc
            }
            st {
                set stat ""
                if {$lbrow5 & 0x040} {append stat "FET"}
                if {$lbrow5 & 0x080} {append stat "EXE"}
                if {$lbrow5 & 0x100} {append stat "DEF"}
                if {$lbrow5 & 0x200} {append stat "WCT"}
                if {$lbrow6 & 0x400} {append stat "CAD"}
                if {$lbrow6 & 0x800} {append stat "BRK"}
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

# read console mcp23017 register pair
#  reg = even register number
# returns:
#  val[15:08] = even register value
#  val[07:00] = odd register value
proc mcprd16 {reg} {
    iic wr 0x40 wr $reg rs wr 0x41 rd rd
    for {set i 0} {[iic] == ""} {incr i} {
        if {$i > 9999} {error "mcprd16: timed out reading register"}
        runstep
    }
    return [iic]
}

# write console mcp23017 register pair
#  reg = even register number
#  val[15:08] = even register value
#  val[07:00] = odd register value
proc mcpwr16 {reg val} {
    iic wr 0x40 wr $reg wr [expr {$val >> 8}] wr [expr {$val & 255}]
    for {set i 0} {[iic] == ""} {incr i} {
        if {$i > 9999} {error "mcpwr16: timed out writing register"}
        runstep
    }
}

# read light row via console mcp23017
#  input:
#   row = light row 0..3
#  output:
#   returns 12-bit light row contents
proc mcprdltrow {row} {

    ;# set data pins to input mode
    mcpwr16 0x00 0x3F3F

    ;# set selection pins to the row
    set iicsel_10 [expr {$row & 3}]
    set iicsel_2 [expr {($row >> 2) & 1}]
    mcpwr16 0x14 [expr {($iicsel_2 << 14) | ($iicsel_10 << 6)}]

    ;# read light pins
    ;#  [15]    = iicsel_3 = 0
    ;#  [14]    = iicsel_2 = row[2]
    ;#  [13:08] = data[05:00]
    ;#  [07:06] = iicsel_1 = row[1:0]
    ;#  [05:00] = data[11:06]
    set val [mcprd16 0x12]
    return [expr {((($val>>8)&63)|(($val&63)<<6))^07777}]
}

# write switch row via console mcp23017
#  input:
#   row = switch row 0..2
#   val = 12-bit row value
# row 0:
#   val[11:00] = register
# row 1:
#   val[11:09] = 0n000 = DFLD n
#   val[08:06] = 00n00 = IFLD n
# row 2:
#   val[04] = 00020 = SINST
#   val[05] = 00040 = SSTEP
#   val[06] = 00100 = STOP
#   val[07] = 00200 = CONT
#   val[08] = 00400 = EXAM
#   val[09] = 01000 = DEPOS
#   val[10] = 02000 = LDAD
#   val[11] = 04000 = START
proc mcpwrswrow {row val} {

    ;# select switch row and output data
    ;#  [15]    = iicsel_3 = 1
    ;#  [14]    = iicsel_2 = 0
    ;#  [13:08] = data[05:00]
    ;#  [07:06] = iicsel_1 = row[1:0]
    ;#  [05:00] = data[11:06]
    set scram [expr {(($val & 63) << 8) | (($val >> 6) & 63)}]
    mcpwr16 0x14 [expr {0x8000 | $scram | ($row << 6)}]

    ;# set all pins to output mode
    mcpwr16 0x00 0x0000

    ;# select switch row '3' - clocks data into flipflops
    mcpwr16 0x14 [expr {0x80C0 | $scram}]
}

# release mcp23017 control of console
# normal lights & switches take over
proc mcprelease {} {

    ;# set data pins to input mode so they don't jam data lines
    mcpwr16 0x00 0x3F3F

    ;# set select pins to 1111 to let normal counters take over
    mcpwr16 0x14 0xC0C0
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

# single-step processor, interpret changes in gpio
set runstep_lastg 0
proc runstep {} {
    global lightrows runquiet runstep_lastg swrowpends swrowrcvds swrowsents

    set c [clk]                             ;# kerchunk the 10MHz clock and get cycle count
    set g [gpio]                            ;# read gpio connector contents
    if {$runstep_lastg != $g} {
        for {set r 0} {$r < 3} {incr r} {   ;# maybe it wants switch contents
            ;# if high-to-low for switch select, capture pending value to be sent
            if {$runstep_lastg & ~ $g & (0x1000 << $r)} {
                set sw [lindex $swrowpends $r]
                lset swrowsents $r $sw
            }
            ;# if low switch select, send the row contents
            if {~ $g & (0x1000 << $r)} {
                set sw [lindex $swrowsents $r]
                gpio [expr {($g & 0xFFF000) | $sw}]
            }
            ;# if low-to-high for switch select, processor clocked sent value in
            if {~ $runstep_lastg & $g & (0x1000 << $r)} {
                set sw [lindex $swrowsents $r]
                lset swrowrcvds $r $sw
            }
        }
        set runstep_lastg $g                ;# save gpio to detect edges
        set v [expr {~ $g & 07777}]         ;# get the 12-bit row contents
        set newlbrows $lightrows            ;# update any possible lb row
        for {set r 0} {$r < 8} {incr r} {
            if {$g & (0x010000 << $r)} {lset newlbrows $r $v}
        }
        if {$lightrows != $newlbrows} {     ;# see if any change in lb row contents
            set lightrows $newlbrows
            if {! $runquiet} {
                puts [format "%12d: %s" $c [lights]]
            }
        }
    }
}

# start processor at the given address
proc startat {addr} {
    if {($addr < 0) || ($addr > 07777)} {
        error "bad address $addr"
    }
    puts "startat*: setting swreg $addr"
    swtchwait reg $addr
    puts "startat*: pressing ldad"
    swtchwait ldad 1
    puts "startat*: releasing ldad"
    swtchwait ldad 0
    puts "startat*: pressing start"
    swtchwait start 1
    puts "startat*: releasing start"
    swtchwait start 0
    puts "startat*: done"
}

# modify and query switch settings
# - set just queues the value, use 'runloop/runstep' to pass them on to processor
# - get retrieves latest value received by processor
set swrowpends {0 0 0}      ;# waiting to be sent to processor
set swrowrcvds {0 0 0}      ;# has been received by processor
set swrowsents {0 0 0}      ;# has been sent to processor
proc swtch {args} {
    global swrowpends swrowrcvds

    set retval ""
    set setmode 0
    set len [llength $args]

    for {set i 0} {$i < $len} {incr i} {
        set sw [lindex $args $i]
        switch $sw {
            df {
                if {$setmode} {
                    set val [lindex $args [incr i]]
                    set row [expr {[lindex $swrowpends 1] & 0x3FE}]
                    if {$val & 4} {incr row 0x400}
                    if {$val & 2} {incr row 0x800}
                    if {$val & 1} {incr row 0x001}
                    lset swrowpends 1 $row
                } else {
                    set row [lindex $swrowrcvds 1]
                    set val 0
                    if {$row & 0x400} {incr val 4}
                    if {$row & 0x800} {incr val 2}
                    if {$row & 0x001} {incr val 1}
                    lappend retval $val
                }
            }
            get {set setmode 0}
            if {
                if {$setmode} {
                    set val [lindex $args [incr i]]
                    set row [expr {[lindex $swrowpends 1] & 0xFF1}]
                    if {$val & 4} {incr row 0x002}
                    if {$val & 2} {incr row 0x004}
                    if {$val & 1} {incr row 0x008}
                    lset swrowpends 1 $row
                } else {
                    set row [lindex $swrowrcvds 1]
                    set val 0
                    if {$row & 0x002} {incr val 4}
                    if {$row & 0x004} {incr val 2}
                    if {$row & 0x008} {incr val 1}
                    lappend retval $val
                }
            }
            reg {
                if {$setmode} {
                    set val [lindex $args [incr i]]
                    lset swrowpends 0 [unscramgpio $val]
                } else {
                    lappend retval [unscramgpio [lindex $swrowrcvds 0]]
                }
            }
            set {set setmode 1}
            default {
                set bitnum [lsearch {"depos" "exam" "cont" "stop" "sstep" "sinst" "" "" "" "" "start" "ldad"} $sw]
                if {$bitnum < 0} {
                    error "unknown switch $sw"
                }
                set mask [expr {1 << $bitnum}]
                if {$setmode} {
                    set val [lindex $args [incr i]]
                    set row [expr {[lindex $swrowpends 2] & ~ $mask}]
                    if {$val} {incr row $mask}
                    lset swrowpends 2 $row
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
        if {$i > 2000000} {error "timed out setting sw$name to $valu}
        runstep
    }
}

# unscramble data bits from gpio connector
# symmectrical so it can scramble data bits to gpio
proc unscramgpio {row} {
    set val 0
    if {$row & 0x400} {incr val 0x800}
    if {$row & 0x800} {incr val 0x400}
    if {$row & 0x001} {incr val 0x200}
    if {$row & 0x002} {incr val 0x100}
    if {$row & 0x004} {incr val 0x080}
    if {$row & 0x008} {incr val 0x040}
    if {$row & 0x010} {incr val 0x020}
    if {$row & 0x020} {incr val 0x010}
    if {$row & 0x040} {incr val 0x008}
    if {$row & 0x080} {incr val 0x004}
    if {$row & 0x100} {incr val 0x002}
    if {$row & 0x200} {incr val 0x001}
    return $val
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
    waithalt 20000
    swtchwait reg $addr
    swtchwait ldad 1
    swtchwait ldad 0
    waitrun
    waithalt 20000
    swtchwait reg $data
    swtchwait depos 1
    swtchwait depos 0
    waitrun
    waithalt 20000
    for {set i 0} {[light mb] != $data} {incr i} {
        if {$i > 20000} {error "timed out waiting for mb lights"}
        runstep
    }
}
