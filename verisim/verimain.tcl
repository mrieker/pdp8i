
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

# get environment variable, return default value if not defined
proc getenv {varname {defvalu ""}} {
    return [expr {[info exists ::env($varname)] ? $::env($varname) : $defvalu}]
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
set runquiet 0
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

# single cycle processor
proc singcyc {} {
    if {! [bus oRUN]} {error "processor not running"}
    for {set i 0} {! [bus oTS4]} {incr i} {
        if {$i > 20000} {error "timed out waiting for TS4 asserted"}
        runstep
    }
    for {set i 0} {[bus oTS4]} {incr i} {
        if {$i > 20000} {error "timed out waiting for TS4 negated"}
        runstep
    }
    return [format "PC=%04o MA=%04o MB=%04o L.AC=%o.%04o ST=%x" [bus pctr] [bus oMADR] [bus oMBUF] [bus oLINK] [bus oACUM] [bus majst]]
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
