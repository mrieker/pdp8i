
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
    return "MS=$majst PC=$pctr MA=$madr MB=$mbuf L.AC=$link.$acum MQ=$mquo RUN=$run"
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
set usefpi2c 0
proc hardreset {} {
    global usefpi2c

    ;# power-on reset for 10uS
    bus set reset 1
    clk 100
    bus set reset 0

    ;# maybe use pdp8ifpi2c.v to scan panel
    ;# switch and light access very slow
    ;# otherwise console.kicad_sch internal counters scan panel quickly
    if {$usefpi2c} {
        set fpat [arm find FP]
        ;# turn pdp8ifpi2c.v scanning on
        arm set [expr {$fpat +  5}] 0       ;# fp_manual=0
        ;# tell it to scan quickly (sim mcp23017 is fast and we don't use gpio lights)
        arm set [expr {$fpat + 13}] 0x3C0F  ;# fp_ltspeed=15; fp_i2cspeed=15
        ;# wait for state 2 meaning the mcp23017 has received a command,
        ;#  shutting off console.kicad_sch internal scanners
        for {set i 0} {true} {incr i} {
            set fp7 [arm [expr {$fpat + 7}]]
            if {($fp7 & 15) == 2} break     ;# fp_mcpstate==2
            if {$i > 2000} {                ;# usually takes 914
                error "pdp8ifpi2c startup timed out"
            }
        }
    }
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

# single-step processor, interpret changes in gpio
set lastgpio  0
proc runstep {} {
    global lastgpio lightrows runquiet
    global swrowpends

    ;# kerchunk the 10MHz clock and get cycle count
    set c [clk]

    ;# here we pretend to be the pidp panel
    ;# capture what console.kicad_sch is feeding the lights
    ;# send what we want to console.kicad_sch for switches when asked
    set g [gpio]                                ;# read gpio connector contents
    if {$lastgpio != $g} {
        if {($g & 0x7000) == 0x7000} {
            gpio 07777                          ;# if no switches being requested, set to ones to not interfere with lights
        } else {
            for {set r 0} {$r < 3} {incr r} {   ;# maybe it wants switch contents
                if {~ $g & (0x1000 << $r)} {    ;# if low switch select, send the row contents
                    set sw [lindex $swrowpends $r]
                    gpio $sw
                }
            }
        }
        if {($g & 0xFF0000) != 0} {             ;# see if any lights being sent
            set v [expr {~ $g & 07777}]         ;# get the 12-bit row contents
            for {set r 0} {$r < 8} {incr r} {   ;# save light row
                if {$g & (0x010000 << $r)} {lset lightrows $r $v}
            }
        }
        set lastgpio $g                         ;# save gpio to detect edges
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
# - set just queues the value, use 'runloop/runstep' to pass them on to console.kicad_sch
# - get retrieves values currently latched into console.kicad_sch flipflops
set swrowpends {0 0 0}      ;# waiting to be sent to processor
set swrowsents {-1 -1 -1}   ;# has been sent to processor
set swbuttons {"start" "ldad" "depos" "exam" "cont" "stop" "sstep" "sinst"} 
proc swtch {args} {
    global swbuttons swrowpends

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
                    lappend retval [bus swdf]
                }
            }
            get {set setmode 0}
            if {
                if {$setmode} {
                    set val [lindex $args [incr i]]
                    set row [lindex $swrowpends 1]
                    lset swrowpends 1 [expr {($val << 6) | ($row & 0xE3F)}]
                } else {
                    lappend retval [bus swif]
                }
            }
            reg {
                if {$setmode} {
                    set val [lindex $args [incr i]]
                    lset swrowpends 0 [expr {$val + 0}]
                } else {
                    lappend retval [bus swreg]
                }
            }
            set {set setmode 1}
            default {
                if {$setmode} {
                    set bitnum [lsearch $swbuttons $sw]
                    if {$bitnum < 0} {
                        error "unknown switch $sw"
                    }
                    set mask [expr {2048 >> $bitnum}]
                    set val [lindex $args [incr i]]
                    set row [lindex $swrowpends 2]
                    lset swrowpends 2 [expr {($row & ~ $mask) | ($val ? $mask : 0)}]
                } else {
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
    for {set i 0} {$i < 200000} {incr i} {
        set actual [swtch $name]
        if {$actual == $valu} return
        runstep
    }
    error "timed out setting sw$name to $valu (is $actual)"
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
