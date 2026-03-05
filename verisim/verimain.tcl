
# assemble the given opcode and deposit in memory
proc assem {addr args} {
    wrmem $addr [asmop $addr $args]
}

# disassemble the given range of memory
proc disas {loaddr {hiaddr ""}} {
    if {$hiaddr == ""} {set hiaddr $loaddr}
    for {set addr $loaddr} {$addr <= $hiaddr} {incr addr} {
        set opcd [rdmem $addr]
        puts [format "  %04o:  %s" $addr [disop $addr $opcd]]
    }
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

proc octal {n} {
    return [format "%04o" $n]
}

# read word from memory using front-panel switches
proc rdmem {addr} {
    if {($addr < 0) || ($addr > 07777)} {
        error "bad address $addr"
    }
    swtch set reg $addr
    runloop 240
    swtch set ldad 1
    runloop 240
    swtch set ldad 0
    runloop 240
    return [light mb]
}

# keep clocking processor, interpret changes in gpio
set runquiet 0
proc runloop {{n ""}} {
    if {$n == ""} {
        while {! [ctrlcflag]} {
            runstep
        }
    } else {
        for {set i 0} {$i < $n} {incr i} {
            runstep
        }
    }
}
proc runstep {} {
    global lightrows runquiet swrowpends swrowsents

    set c [clk]                         ;# kerchunk the 100MHz clock and get cycle count
    set g [gpio]                        ;# read gpio connector contents
    for {set r 0} {$r < 3} {incr r} {   ;# maybe it wants switch contents
        if {! ($g & (0x1000 << $r))} {
            set sw [lindex $swrowpends $r]
            gpio [expr {($g & 0xFFF000) | $sw}]
            lset swrowsents $r $sw
        }
    }
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

# start processor at the given address
proc startat {addr} {
    if {($addr < 0) || ($addr > 07777)} {
        error "bad address $addr"
    }
    swtch set reg $addr
    runloop 240
    swtch set ldad 1
    runloop 240
    swtch set ldad 0
    runloop 240
    swtch set start 1
    runloop 960
    swtch set start 0
}

# modify and query switch settings
# - set just queues the value, use 'runloop/runstep' to pass them on to processor
# - get retrieves latest value sent to processor
set swrowpends {0 0 0}      ;# waiting to be sent
set swrowsents {0 0 0}      ;# has been sent
proc swtch {args} {
    global swrowpends swrowsents

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
                    set row [lindex $swrowsents 1]
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
                    set row [lindex $swrowsents 1]
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
                    lappend retval [unscramgpio [lindex $swrowsents 0]]
                }
            }
            set {set setmode 1}
            default {
                set bitnum [lsearch {"dep" "exam" "cont" "stop" "sstep" "sinst" "" "" "" "" "start" "ldad"} $sw]
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
                    lappend retval [expr {([lindex $swrowsents 2] & $mask) != 0}]
                }
            }
        }
    }
    return $retval
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

# write memory location using front-panel switches
proc wrmem {addr data} {
    if {($addr < 0) || ($addr > 07777)} {
        error "bad address $addr"
    }
    if {($data < 0) || ($data > 07777)} {
        error "bad data $data"
    }
    swtch set reg $addr
    runloop 240
    swtch set ldad 1
    runloop 240
    swtch set ldad 0
    runloop 240
    swtch set reg $data
    runloop 240
    swtch set dep 1
    runloop 960
    swtch set dep 0
    runloop 240
}

# start out with an hard reset
hardreset
