#
# initialization file for z8ipanel
#

# help for commands defined herein
proc helpini {} {
    puts ""
    puts "  alloff                  - flip all switches off"
    puts "  assem <addr> <opcd> ... - assemble and write to memory"
    puts "  chartoint               - convert character to integer"
    puts "  checkttymatch           - check for matching tty printer characters"
    puts "  checkttyprompt          - check tty for prompt and send reply string"
    puts "  clearmem                - clear all 32KW memory"
    puts "  disas <start> <stop>    - disassemble given range"
    puts "  domemcyc <switch>       - do switch-initiated memory cycle"
    puts "  dumpit                  - dump registers and switches"
    puts "  dumpmem <start> <stop>  - dump memory in octal"
    puts "  escapechr               - convert character to escape"
    puts "  flicksw <switch>        - flick momentary switch on then off"
    puts "  fpfpgascan              - enable fpga console i2c scanning counters"
    puts "  fpselfscan              - enable console board self-scanning counters"
    puts "  getenv                  - get environment variable"
    puts "  getrestofttyline        - read rest of line from tty"
    puts "  hardreset               - reset the processor"
    puts "  inttochar               - convert integer to character"
    puts "  isziactest              - deposit isz/iac test in memory"
    puts "  loadbin <filename>      - load bin file via console, verify, return start address"
    puts "  loadbinptr <filename>   - load bin file via paper tape reader, return start address"
    puts "  loadrim <filename>      - load rim file via console, verify"
    puts "  loop52                  - set up and start 5252: jmp 5252"
    puts "  octal <val>             - convert value to 4-digit octal string"
    puts "  postinc <var>           - increment var but return its previous value"
    puts "  rdmem <addr>            - read memory at the given address"
    puts "  readloop <addr> ...     - continuously read the addresses until CTRLC"
    puts "  rimloader <lo|hi>       - deposit rim loader in memory"
    puts "  sendchartottykb         - send char to tty kb, don't check for echo"
    puts "  sendtottykb             - send string to tty keyboard and check echo"
    puts "  shadowoff               - turn shadowing off"
    puts "  shadowon                - turn shadowing on"
    puts "  simoff                  - set to real mode"
    puts "  simon                   - set to simulation mode"
    puts "  startat <addr>          - load pc and start at given address"
    puts "  stepit                  - step one cycle then dump"
    puts "  steploop                - step one cycle, dump, then loop on enter key"
    puts "  ttykbtest               - deposit simple tty keyboard test in memory"
    puts "  ttyprtest               - deposit simple tty printer test in memory"
    puts "  wait                    - wait for CTRLC or STOP"
    puts "  waitforttypr            - wait for prompt string on tty"
    puts "  wrmem <addr> <data>     - write memory at the given address"
    puts "  zeromem <start> <stop>  - zero the given address range"
    puts ""
}

# turn all switches off
proc alloff {} {
    setsw dfld 0
    setsw ifld 0
    setsw ldad 0
    setsw start 0
    setsw cont 0
    setsw stop 0
    setsw sinst 0
    setsw sstep 0
    setsw exam 0
    setsw depos 0
    setsw reg 0
}

# assemble instruction and write to memory
# - assem 0200 tadi 0376
# - assem 0201 sna cla
proc assem {addr opcd args} {
    wrmem $addr [assemop $addr $opcd $args]
}

# convert character to integer
proc chartoint {cc} {
    if {$cc == ""} {return -1}
    scan $cc "%c" ii
    return [expr {$ii & 0377}]
}

# check tty output for match
# - ignores control characters and whitespace
# - skips up to nskip printables at the beginning
# - returns string skipped over
proc checkttymatch {nskip line {tmsec 30000}} {

    set len [string length $line]
    set nowtsp ""
    for {set i 0} {$i < $len} {incr i} {
        set ch [string index $line $i]
        if {$ch > " "} {append nowtsp $ch}
    }

    set len [string length $nowtsp]
    set nmatched 0
    set skipped ""
    while {$nmatched < $len} {
        set ch [readttychartimed $tmsec]
        if {$ch == ""} {
            puts ""
            error "checkttymatch: timed out waiting for '$line'"
        }
        puts -nonewline $ch
        flush stdout
        if {$ch <= " "} continue
        if {$ch == [string index $nowtsp $nmatched]} {
            incr nmatched
            continue
        }
        append skipped [string range $nowtsp 0 [expr {$nmatched - 1}]]
        append skipped $ch
        if {[string length $skipped] > $nskip} {
            while true {
                set ch [readttychartimed $tmsec]
                if {$ch == ""} break
                puts -nonewline $ch
                flush stdout
                if {$ch == "\n"} break
            }
            puts ""
            error "checkttymatch: failed to match '$line'"
        }
    }
    return $skipped
}

# check tty prompt string for match then send given reply followed by <CR>
# - always ignore control and whitespace characters in prompt string
proc checkttyprompt {prompt reply {tmsec 30000}} {
    # check prompt string
    checkttymatch 0 $prompt $tmsec
    # there may be a CR/LF following the prompt (like 'READY' in BASIC)
    # so wait for a brief time with no characters printed
    while {true} {
        set rb [readttychartimed 1234]
        if {$rb == ""} break
        puts -nonewline $rb
        flush stdout
        if {$rb > " "} {
            puts "checkttyprompt: extra char [escapechr $rb] after prompt"
        }
    }
    # send reply string to keyboard incl spaces
    # check for each of each one
    set len [string length $reply]
    for {set i 0} {$i < $len} {incr i} {
        after 456
        set ch [string index $reply $i]
        sendchartottykb $ch
        set rb [readttychartimed 1234]
        puts -nonewline $rb
        flush stdout
        if {$rb != $ch} {
            puts ""
            error "checkttyprompt: char [escapechr $ch] echoed as [escapechr $rb]"
        }
    }
    # send CR at the end, don't bother checking echo in case it echoes something different
    after 456
    sendchartottykb "\r"
}

# set all 32KW memory to known values
proc clearmem {} {
    hardreset
    assem 000 iot 06201 ;# CDF set DFLD
    assem 001 dcai 020  ;# clear mem location
    assem 002 isz  020  ;# on to next location
    assem 003 jmp  001
    assem 004 tad  000  ;# increment field
    assem 005 tad  015  ;# 0010
    assem 006 dca  000
    assem 007 tad  000  ;# see if done all fields
    assem 010 and  016  ;# 0100
    assem 011 sna
    assem 012 jmp  000  ;# change field if not
    assem 013 hlt       ;# all done
    assem 014 jmp  013
    wrmem 015 0010
    wrmem 016 0100
    wrmem 017 0000
    wrmem 020 0021
    set begmc [pin memcycctr]
    startat 0
    while {! [ctrlcflag]} {
        if {! [pin orun]} break
        set nowmc [pin memcycctr]
        set delmc [expr {($nowmc - $begmc) & 0xFFFFFFFF}]
        ;# usually 196603 cycles
        if {$delmc > 250000} {error "clearmem: too many cycles"}
        after 100
    }
}

# disassemble block of memory
# - disas addr         ;# disassemble in vacinity of given address
# - disas start stop   ;# disassemble the given range
proc disas {start {stop ""}} {
    # if just one arg, make the range start-8..start+8
    if {$stop == ""} {
        set stop  [expr {(($start & 007777) > 07767) ? ($start | 000007) : ($start + 010)}]
        set start [expr {(($start & 007777) < 00010) ? ($start & 077770) : ($start - 010)}]
    }
    # loop through the range, inclusive
    for {set pc $start} {$pc <= $stop} {incr pc} {
        set op [rdmem $pc]
        set as [disasop $op $pc]
        puts [format "%04o  %04o  %s" $pc $op $as]
    }
}

# do memory cycle initiated by a switch (depos, exam, ldad, start, cont)
proc domemcyc {sw} {
    set oldmc [pin memcycctr]
    flicksw $sw
    ;# memcycctr increments on posedge TS3
    set started [pin 10mhz]
    while {[pin memcycctr] == $oldmc} {
        set elapsed [expr {([pin 10mhz] - $started) & 0xFFFFFFFF}]
        if {$elapsed > 1000000} {error "$sw cycle timed out"}
        after 1
    }
    ;# loop until TS3 and TS4 are complete (or yet another cycle runs)
    set midmc [expr {($oldmc + 1) & 0xFFFFFFFF}]
    while {[pin ots3] || [pin ots4]} {
        if {[pin memcycctr] != $midmc} break
        set elapsed [expr {([pin 10mhz] - $started) & 0xFFFFFFFF}]
        if {$elapsed > 1000000} {error "$sw cycle timed out"}
        after 1
    }
}

# dump block of memory
# - dumpmem start stop
proc dumpmem {start stop} {
    set start [expr {$start & 077770}]
    for {set addr $start} {$addr <= $stop} {incr addr 8} {
        puts -nonewline [format "  %05o " $addr]
        for {set i 0} {$i < 8} {incr i} {
            puts -nonewline [format " %04o" [rdmem [expr {$addr+$i}]]]
        }
        puts ""
    }
}

# dump light bulbs and switches
proc dumpit {} {
    set lbs [getlb ac ea ion ir link ma mb mq ms pc run sc]
    set ac   [lindex $lbs  0]
    set ea   [lindex $lbs  1]
    set ion  [lindex $lbs  2]
    set ir   [lindex $lbs  3]
    set link [lindex $lbs  4]
    set ma   [lindex $lbs  5]
    set mb   [lindex $lbs  6]
    set mq   [lindex $lbs  7]
    set ms   [lindex $lbs  8]
    set pc   [lindex $lbs  9]
    set run  [lindex $lbs 10]
    set sc   [lindex $lbs 11]

    set sws [getsw reg dfld ifld cont depos exam ldad sinst sstep start stop]

    set sw "SR=[octal [lindex $sws 0]] DF=[lindex $sws 1] IF=[lindex $sws 2]"
    if {[lindex $sws  3]} {append sw " CONT"}
    if {[lindex $sws  4]} {append sw " DEPOS"}
    if {[lindex $sws  5]} {append sw " EXAM"}
    if {[lindex $sws  6]} {append sw " LDAD"}
    if {[lindex $sws  7]} {append sw " SINST"}
    if {[lindex $sws  8]} {append sw " SSTEP"}
    if {[lindex $sws  9]} {append sw " START"}
    if {[lindex $sws 10]} {append sw " STOP"}

    set mne [string range "ANDTADISZDCAJMSJMPIOTOPR" [expr {$ir * 3}] [expr {$ir * 3 + 2}]]

    return [format "%s %s MS=%-5s AC=%o.%04o MA=%o.%04o MB=%04o MQ=%04o PC=%04o SC=%02o IR=%s  %s" \
        [expr {$run ? "RUN" : "   "}] [expr {$ion ? "ION" : "   "}] $ms $link $ac $ea $ma $mb $mq $pc $sc $mne $sw]
}

;# convert given character to escaped form if necessary
proc escapechr {ch} {
    if {$ch == ""} {return "\\d"}
    set ii [chartoint $ch]
    if {$ii == 10} {return "\\n"}
    if {$ii == 13} {return "\\r"}
    if {($ii <= 31) || ($ii >= 127)} {return [format "\\%03o" $ii]}
    return [string range $ch 0 0]
}

# flick momentary switch on then off
proc flicksw {swname} {
    setsw $swname 1
    setsw $swname 0
}

proc fpfpgascan {} {
    # tell pdp8ifpi2c.v to start scanning console
    pin set fp_manual 0
}

proc fpselfscan {} {
    # tell pdp8ifpi2c.v to stop scanning console
    pin set fp_manual 1
    # wait for it to stop
    set beg100 [pin 100mhz]
    while {[pin fp_mcpstate] != 0} {
        set del100 [expr {([pin 100mhz] - $beg100) & 0xFFFFFFFF}]
        if {$del100 > 3300000} {error "pdp8ifpi2c timed out"}
        after 123
    }
    # set all mcp23017 pins to input mode
    # pullups will set iicsel = 1111 so board will scan on its own
    # command <= { WR, 8'h40,     WR, 8'h00,     WR, 8'hFF,     WR,  8'hFF,     24'b0 };
    #              11  01.0000.00 11. 0000.0000. 11  11.1111.11 11.  1111.1111. 0...
    pin set fp_cmdlo 0xFF000000 fp_cmdhi 0xD0300FFF
    set beg100 [pin 100mhz]
    while {[set stshi [pin fp_stshi]] & 0xF0000000} {
        if {! ($stshi & 0x80000000)} {error [format "pdp8ifpi2c error %08X" $stshi]}
        set del100 [expr {([pin 100mhz] - $beg100) & 0xFFFFFFFF}]
        if {$del100 > 3300000} {error "pdp8ifpi2c timed out"}
        after 123
    }
}

# get environment variable, return default value if not defined
proc getenv {varname {defvalu ""}} {
    return [expr {[info exists ::env($varname)] ? $::env($varname) : $defvalu}]
}

# read rest of line from tty printer, terminated by <CR> or <LF>
proc getrestofttyline {{tmsec 30000}} {
    set skipped ""
    while true {
        set ch [readttychartimed $tmsec]
        if {$ch == ""} {
            error "getrestofttyline: timed out reading to end of line"
        }
        puts -nonewline $ch
        flush stdout
        if {$ch == "\r"} break
        if {$ch == "\n"} break
        append skipped $ch
    }
    return $skipped
}

# halt and reset the CPU
proc hardreset {} {
    pin set fp_manual 0                     ;# make sure pdp8ifpi2c.v scanning is enabled
    pin set fp_ovrsstep 1 fp_setsstep 1     ;# stop at end of current cycle
    pin set arm_iRESET 1 arm_iRESET 0       ;# pulse power-on reset to get pdp8ifpi2c.v scanning
    pin set sh_clearit 1 sh_clearit 0       ;# clear shadow error so clock will run
    setsw start 1                           ;# sstep + start holds processor in reset state
    pin set arm_iRESET 1 arm_iRESET 0       ;# pulse power-on reset
    setsw start 0                           ;# release START
    setsw sstep 0                           ;# release SSTEP
    relsw sstep
}

# convert integer to character
proc inttochar {ii} {
    if {$ii < 0} {return ""}
    return [format "%c" [expr {$ii & 0377}]]
}

# deposit simple isz/iac test in memory
#  then do 'startat 020' to start it
proc isziactest {} {
    hardreset
    assem 020 isz 030
    assem 021 jmp 020
    assem 022 iac
    assem 023 jmp 020
    wrmem 030 01234
    disas 020 023
    puts "do 'startat 020' to start it"
}

proc isziactest2 {} {
    hardreset
    assem 0320 isz 0330
    assem 0321 jmp 0320
    assem 0322 iac
    assem 0323 jmp 0320
    wrmem 0330 01234
    disas 0320 0323
    puts "do 'startat 0320' to start it"
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
    set nextaddr -1
    set verify [dict create]

    set field 0

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

            # deposit data
            if {$addr != $nextaddr} {
                setsw ifld [expr {$addr >> 12}] \
                      dfld [expr {$addr >> 12}] \
                     reg [expr {$addr & 07777}]
                domemcyc ldad
            }
            setsw reg $data
            domemcyc depos

            # set up for next byte
            set addr [expr {($addr & 070000) | (($addr + 1) & 007777)}]
            set start -1
            set state 2
            set nextaddr $addr
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

# load bin format tape file, return start address
# uses rim loader, bin loader, high-speed paper tape reader
proc loadbinptr {fname} {
    global Z8IHOME

    hardreset
    setsw ifld 0 dfld 0

    puts "loadbinptr: toggling in rim loader"
    rimloader hi

    puts "loadbinptr: reading in bin loader"
    if {! [file exists $Z8IHOME/binloader.rim]} {
        exec make -C $Z8IHOME binloader.rim
    }
    set ptrpid [exec $Z8IHOME/z8iptr -killit $Z8IHOME/binloader.rim &]
    after 123
    setsw reg 07756 ; domemcyc ldad
    setsw reg 00000 ; domemcyc start
    while true {
        set exst [waitpid $ptrpid]
        if {$exst != ""} break
        if {[ctrlcflag]} {error "control-C"}
        after 100
    }
    if {$exst != 0} {error "error $exst reading binloader.rim"}
    flicksw stop

    puts "loadbinptr: reading in $fname"
    set ptrpid [exec $Z8IHOME/z8iptr -killit $fname &]
    after 123
    setsw reg 07777 ; domemcyc ldad
    setsw reg 00000 ; domemcyc start
    while {[getlb run]} {
        if {[ctrlcflag]} {error "control-C"}
        after 100
    }
    exec kill $ptrpid
    waitpid $ptrpid
    puts ""
    if {[getlb ac] != 0} {error "checksum error"}
    return [rdmem 07616]
}

# load rim format tape file
proc loadrim {fname} {
    set fp [open $fname rb]

    hardreset

    set addr 0
    set data 0
    set offset -1
    set nextaddr -1
    set verify [dict create]

    setsw ifld 0 dfld 0

    puts "loadrim: loading $fname..."

    while {true} {
        if {[ctrlcflag]} {
            close $fp
            error "control-C"
        }

        # read byte from tape
        incr offset
        set ch [read $fp 1]
        if {[eof $fp]} break
        set ch [chartoint $ch]

        # ignore rubouts
        if {$ch == 0377} continue

        # keep skipping until we have an address
        if {! ($ch & 0100)} continue

        set addr [expr {($ch & 077) << 6}]

        incr offset
        set ch [read $fp 1]
        if {[eof $fp]} {
            close $fp
            error "eof reading loadfile at $offset"
        }
        set ch [chartoint $ch]
        set addr [expr {$addr | ($ch & 077)}]

        incr offset
        set ch [read $fp 1]
        if {[eof $fp]} {
            close $fp
            error "eof reading loadfile at $offset"
        }
        set ch [chartoint $ch]
        set data [expr {($ch & 077) << 6}]

        incr offset
        set ch [read $fp 1]
        if {[eof $fp]} {
            close $fp
            error "eof reading loadfile at $offset"
        }
        set ch [chartoint $ch]
        set data [expr {$data | ($ch & 077)}]

        dict set verify $addr $data
        puts -nonewline [format "  %04o / %04o\r" $addr $data]
        flush stdout

        # do 'load address' if not sequential
        if {$nextaddr != $addr} {
            setsw reg $addr
            domemcyc ldad
        }

        # deposit the data
        setsw reg $data
        domemcyc depos

        # verify resultant lights
        set actma [getlb ma]
        set actmb [getlb mb]
        if {($actma != $addr) || ($actmb != $data)} {
            close $fp
            error [format %04o %04o showed %04o %04o" $addr $data $actma $actmb]
        }

        set nextaddr [expr {($addr + 1) & 07777}]
    }

    close $fp
    puts ""

    # verify what was loaded
    loadverify $verify
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

# set up 5252: jmp 5252 and start it
proc loop52 {} {
    hardreset
    setsw reg 05252
    domemcyc ldad
    domemcyc depos
    domemcyc ldad
    flicksw start
}

# convert integer to 4-digit octal string
proc octal {val} {
    return [format %04o $val]
}

# increment a variable but return its previous value
# useful for doing series of assem commands
# http://www.tcl.tk/man/tcl8.6/TclCmd/upvar.htm
proc postinc name {
    upvar $name x
    set oldval $x
    incr x
    return $oldval
}

;# read character from tty with timeout
proc readttychartimed {msec} {
    for {set i 0} {$i < $msec} {incr i} {
        after 1
        set prfull [pin get pr_full]
        if {$prfull} {
            set prchar [pin get pr_char set pr_full 0 pr_flag 1]
            set prchar [expr {$prchar & 0177}]
            if {$prchar != 0} {
                return [inttochar $prchar]
            }
        }
    }
    return ""
}

# deposit rim loader in memory
# returns start address
#  speed = "lo" or "hi"
proc rimloader {speed} {
    hardreset
    switch $speed {
        "lo" {
            setsw reg 07756 ; domemcyc ldad
            setsw reg 06032 ; domemcyc depos
            setsw reg 06031 ; domemcyc depos
            setsw reg 05357 ; domemcyc depos
            setsw reg 06036 ; domemcyc depos
            setsw reg 07106 ; domemcyc depos
            setsw reg 07006 ; domemcyc depos
            setsw reg 07510 ; domemcyc depos
            setsw reg 05357 ; domemcyc depos
            setsw reg 07006 ; domemcyc depos
            setsw reg 06031 ; domemcyc depos
            setsw reg 05367 ; domemcyc depos
            setsw reg 06034 ; domemcyc depos
            setsw reg 07420 ; domemcyc depos
            setsw reg 03776 ; domemcyc depos
            setsw reg 03376 ; domemcyc depos
            setsw reg 05356 ; domemcyc depos
            setsw reg 00000 ; domemcyc depos
        }
        "hi" {
            setsw reg 07756 ; domemcyc ldad
            setsw reg 06014 ; domemcyc depos    ;# 7756 IOT  6014   clear flag, start reading
            setsw reg 06011 ; domemcyc depos    ;# 7757 IOT  6011   skip if reader ready
            setsw reg 05357 ; domemcyc depos    ;# 7760 JMP  7757
            setsw reg 06016 ; domemcyc depos    ;# 7761 IOT  6016   read char, clear flag, start reading
            setsw reg 07106 ; domemcyc depos    ;# 7762 CLL RTL     shift char left 4 bits
            setsw reg 07006 ; domemcyc depos    ;# 7763 RTL
            setsw reg 07510 ; domemcyc depos    ;# 7764 SPA
            setsw reg 05374 ; domemcyc depos    ;# 7765 JMP  7774   char<7> was set, skip leader/trailer char
            setsw reg 07006 ; domemcyc depos    ;# 7766 RTL         char<7> was clear, shift over 2 more bits
            setsw reg 06011 ; domemcyc depos    ;# 7767 IOT  6011   skip if reader ready
            setsw reg 05367 ; domemcyc depos    ;# 7770 JMP  7767
            setsw reg 06016 ; domemcyc depos    ;# 7771 IOT  6016   read char into low bits, clear flag, start reading
            setsw reg 07420 ; domemcyc depos    ;# 7772 SNL
            setsw reg 03776 ; domemcyc depos    ;# 7773 DCAI 7776   first char<6> clear, store data word
            setsw reg 03376 ; domemcyc depos    ;# 7774 DCA  7776   first char<6> set, store address word
            setsw reg 05357 ; domemcyc depos    ;# 7775 JMP  7757   read another word
            setsw reg 00000 ; domemcyc depos    ;# 7776 0000        address to write to
        }
        default {
            error "bad speed $speed"
        }
    }
    #disas 07756 07775
    return 07756
}

# read memory location
# - does loadaddress which reads the location
proc rdmem {addr} {
    set fld [expr {$addr >> 12}]
    set adr [expr {$addr & 07777}]
    setsw ifld $fld dfld $fld reg $adr
    if {[getsw ifld dfld reg] != "$fld $fld $adr"} {
        error "ifld dfld reg switches did not load"
    }
    domemcyc ldad
    set mead [pin omead]
    set madr [pin omadr]
    if {($mead != $fld) || ($madr != $adr)} {
        error [format "madr did not load, is %o%04o, expect %o%04o" $mead $madr $fld $adr]
    }
    return [pin ombuf]
}

# - direct access to externmem within zynq.v
proc rdextmem {addr} {
    if {! [pin fpgamemen]} {error "external memory not enabled"}
    pin set extmemaddr $addr extmemread 1
    return [pin extmemrdat]
}

# send character to tty keyboard pipe
# does not wait for echo
proc sendchartottykb {ch} {
    pin set kb_char [chartoint $ch] kb_flag 1
}

;# function to send the given string to the tty
;# also checks for echoing
proc sendtottykb {str} {
    set len [string length $str]
    for {set i 0} {$i < $len} {incr i} {
        after 1500
        set ex [string index $str $i]
        set ix [chartoint $ex]
        set ch [inttochar [expr {$ix | 0200}]]
        sendchartottykb $ch
        while true {
            set ch [readttychartimed 1000]
            if {$ch == ""} {
                error "sendtottykb: timed out receiving echo"
            }
            if {$ch > " "} break
            if {$ch == $ex} break
            if {$i > 0} break
        }
        if {$ch != $ex} {
            error "sendtottykb: sent char [escapechr $ex] to tty kb but echoed as [escapechr $ch]"
        }
    }
}

# turn shadowing on - pdp8ishad.v checks bus cycles to make sure processor is working
proc shadowoff {} {
    ;# clearit 1 - put pdp8ishad.v in reset state
    ;# fpgamemen 0 - turn off zynq.v 32KW ram
    ;# arm_iMEMDIS 0 - turn on extmemory.kicad_sch 32KW ram
    pin set sh_clearit 1 fpgamemen 0 arm_iMEMDIS 0
}

proc shadowon {} {
    ;# clearit 1 - put pdp8ishad.v in reset state
    ;# fpgamemen 1 - turn on zynq.v 32KW ram
    ;# arm_iMEMDIS 1 - turn off extmemory.kicad_sch 32KW ram
    ;# sh_frzonerr 1 - stop clocking processor if shadowing error
    ;# sh_clearit 0 - start shadowing
    pin set sh_clearit 1 fpgamemen 1 arm_iMEMDIS 1 sh_frzonerr 1 sh_clearit 0
}

# put in real mode
proc simoff {} {
    pin set arm_ireset 1 arm_ireset 0
    pin set simit 0
    pin set fp_manual 0
    pin set fp_i2cspeed 149     ;# 333KHz
    pin set fp_ltspeed 19999    ;# 200uS
    pin set sh_clearit 1
    pin set sh_frzonerr 1
    pin set sh_clearit 0
    hardreset
}

# put in simulator mode
proc simon {} {
    pin set arm_ireset 1 arm_ireset 0
    pin set simit 1
    pin set fp_manual 0
    pin set fp_i2cspeed 29
    pin set fp_ltspeed 63
    pin set sh_clearit 1
    pin set sh_frzonerr 1
    pin set sh_clearit 0
    hardreset
}

# load PC and start at given address
# preserves switchregister contents
proc startat {addr} {
    set savesr [getsw reg]
    setsw ifld [expr {$addr >> 12}] \
          dfld [expr {$addr >> 12}] \
         reg [expr {$addr & 07777}]
    domemcyc ldad
    setsw reg $savesr
    flicksw start
}

# step single cycle then dump front panel
proc stepit {} {
    setsw step 1
    flicksw cont
    puts [dumpit]
}

proc steploop {} {
    puts "<enter> to keep stepping, anything<enter> to stop"
    setsw step 1
    while {! [ctrlcflag]} {
        flicksw cont
        puts -nonewline "[dumpit]  > "
        flush stdout
        set line [gets stdin]
        if {$line != ""} break
    }
}

# load a simple tty keyboard test program into memory
proc ttykbtest {} {
    hardreset

    assem 060 iot 06031 ;# skip if keyboard ready
    assem 061 jmp 060   ;# repeat if not ready
    assem 062 and 070   ;# keep top bits only
    assem 063 tad 071   ;# increment top bits
    assem 064 dca 072
    assem 065 iot 06036 ;# read kb char, clear flag
    assem 066 tad 072   ;# re-insert top bits
    assem 067 jmp 060

    wrmem 070 07000
    wrmem 071 01000

    puts "do './z8itty' on another screen"
    puts "do 'startat 060' to start test then type chars on keyboard"
}

# load a simple tty printer test program into memory
proc ttyprtest {} {
    hardreset
    assem 040 tad 060   ;# load 0040 in acum
    assem 041 iot 06046 ;# start printing char
    assem 042 iot 06041 ;# skip if printer ready
    assem 043 jmp 042   ;# repeat if not ready
    assem 044 iac       ;# inc acum
    assem 045 and 061   ;# mask to 7 bits
    assem 046 sza       ;# see if wrapped
    assem 047 jmp 041   ;# no wrap, print next char
    assem 050 jmp 040   ;# wrap, skip control chars
    wrmem 060 00040
    wrmem 061 00177
    disas 040 050
    puts "do './z8itty' on another screen"
    puts "do 'startat 040' to start test"
}

# - same thing but print output inline and verify
proc ttyprtestauto {} {
    hardreset
    assem 040 tad 060   ;# load 0040 in acum
    assem 041 iot 06046 ;# start printing char
    assem 042 iot 06041 ;# skip if printer ready
    assem 043 jmp 042   ;# repeat if not ready
    assem 044 iac       ;# inc acum
    assem 045 and 061   ;# mask to 7 bits
    assem 046 sza       ;# see if wrapped
    assem 047 jmp 041   ;# no wrap, print next char
    assem 050 jmp 040   ;# wrap, skip control chars
    wrmem 060 00040
    wrmem 061 00177
    disas 040 050
    startat 040
    set expect 32
    while {! [ctrlcflag]} {
        set ch [readttychartimed 1000]
        if {$ch == ""} {
            error "ttyprtest: timeout reading char"
        }
        puts -nonewline $ch
        flush stdout
        set actual [chartoint $ch]
        if {$expect != $actual} {
            puts ""
            puts "ttyprtest: expect $expect  actual $actual"
            set expect $actual
        }
        if {[incr expect] == 128} {set expect 32}
    }
}

# wait for control-C or processor stopped
# returns "CTRLC" or "STOP"
proc wait {} {
    while {[getlb run]} {
        after 100
        if [ctrlcflag] {return "CTRLC"}
    }
    return "STOP"
}

;# function to wait for the given string from the tty
proc waitforttypr {msec str} {
    set len [string length $str]
    for {set i 0} {$i < $len} {incr i} {
        while true {
            set ch [readttychartimed $msec]
            if {$ch > " "} break
            if {$i > 0} break
        }
        set ex [string index $str $i]
        if {$ch != $ex} {
            error "waitforttypr: expected char [escapechr $ex] on tty but got [escapechr $ch]"
        }
    }
}

# write memory location
# - does loadaddress, then deposit to write
proc wrmem {addr data} {
    setsw ifld [expr {$addr >> 12}] \
          dfld [expr {$addr >> 12}] \
         reg [expr {$addr & 07777}]
    domemcyc ldad
    setsw reg $data
    domemcyc depos
}

# - direct access to externmem within zynq.v
proc wrextmem {addr data} {
    if {! [pin fpgamemen]} {error "external memory not enabled"}
    pin set extmemaddr $addr extmemwdat $data extmemwrite 1
}

# zero block of memory
# - zeromem start stop
proc zeromem {start stop} {
    setsw reg $start
    domemcyc ldad
    setsw reg 0
    for {set addr $start} {$addr <= $stop} {incr addr} {
        if {$addr % 8 == 0} {puts [format "%04o" $addr]}
        domemcyc depos
    }
}

# maybe initialize real or sim mode
# ...passed from z8ipanel command line
if {$initargs == "-real"} simoff
if {$initargs == "-sim"}  simon

# message displayed as part of help command
return "also, 'helpini' will print help for z8ipanelini.tcl commands"
