
# automatically loaded by './testextmemory.armv6l -tcl' on startup
# provides functions to load registers from edge pins

proc dumpall {} {
    set outs [pin dfld ifld inbus intinh mead]
    return [format "dfld=%o ifld=%o inbus=%04o intinh=%o mead=%o" \
        [lindex $outs 0] [lindex $outs 1] [lindex $outs 2] [lindex $outs 3] [lindex $outs 4]]
}

proc octal {val} {
    return [format "%04o" $val]
}

proc memtest {} {
    ;# fill memory with random values
    pin set memdis 0 reset 0 ts1 0 ts2 0 ts3 0 ts4 0 tp1 0 tp2 0 tp3 0 tp4 0
    for {set f 0} {$f < 8} {incr f} {
        pin set majst 6 dmafld $f ts1 1     ;# majst=6:break
        if {[pin $mead] != $f} {error "bad mead"}
        pin set ts1 0
        for {set a 0} {$a < 4096} {incr a} {
            set x [expr {$f * 4096 + $a}]
            set d [randbits 12]
            set memarray($x) $d
            pin set madr $a mbuf $d ts3 1   ;# posedge TS3 asserts WriteEnable
            pin set tp3 1                   ;# TP3 asserted negates WriteEnable
            pin set ts3 0
            pin set tp3 0
        }
    }
}

# do a bunch of random loads of 12-bit registers and verify
proc randloads {} {
    set oldacum [pin acum]
    set oldmadr [pin madr]
    set oldmbuf [pin mbuf]
    set oldpctr [pin pctr]
    set namelist "acum madr mbuf pctr"
    for {set i 0} {$i < 1000000000} {incr i} {
        set name [lindex $namelist [randbits 2]]
        set valu [randbits 12]
        puts "$i: set $name = [octal $valu]"
        load$name $valu
        set old$name $valu
        set newacum [pin acum]
        set newmadr [pin madr]
        set newmbuf [pin mbuf]
        set newpctr [pin pctr]
        if {($newacum != $oldacum) || ($newmadr != $oldmadr) || ($newmbuf != $oldmbuf) || ($newpctr != $oldpctr)} {
            puts [format "old acum=%04o madr=%04o mbuf=%04o pctr=%04o" $oldacum $oldmadr $oldmbuf $oldpctr]
            puts [format "new acum=%04o madr=%04o mbuf=%04o pctr=%04o" $newacum $newmadr $newmbuf $newpctr]
            break
        }
    }
}

# print prompt and wait for enter
proc pausetty {pmt} {
    set tty [open "/dev/tty" r+]
    puts -nonewline $tty "$pmt> "
    flush $tty
    gets $tty temp
    close $tty
}

# test accumulator, link, bwcov registers
# theoretically tests all conditions where they should and shouldn't load
proc testacum {} {

    ;# get starting acum, link, bwcov values
    pin set busini 1
    pin set busini 0
    set oldacum [pin acum]
    set oldlink [pin link]
    if {($oldacum != 0) || ($oldlink != 0)} {
        puts [format "initial acum=%04o link=%o" $oldacum $oldlink]
        return
    }

    set oldbwcov [pin bwcov]

    pin set tp1 0 tp2 0

    set ntest 0
    while {! [ctrlcflag]} {

        ;# see what major state we are going to do (range 1..9)
        set majst [expr {[randbits 4] % 9 + 1}]

        ;# generate random opcode
        set opcode [randbits 12]

        ;# generate random 12-bit value to load into acum
        set aluq [randbits 12]

        ;# generate random 1-bit link values
        set cout [randbits 1]       ;# TAD instruction
        set lnktog [randbits 1]     ;# extar instructions

        ;# print about the test case
        incr ntest
        puts [format "%9d majst=%X opcode=%04o aluq=%04o cout=%o lnktog=%o oldacum=%o.%04o oldbwcov=%o" \
            $ntest $majst $opcode $aluq $cout $lnktog $oldlink $oldacum $oldbwcov]

        ;# compute what internal signals should be for those random numbers
        set msfetch [expr {$majst == 1}]
        set msexec  [expr {$majst == 3}]
        set mswrdct [expr {$majst == 4}]
        set mbuf_0  [expr {($opcode >> 0) & 1}]
        set mbuf_1  [expr {($opcode >> 1) & 1}]
        set mbuf_2  [expr {($opcode >> 2) & 1}]
        set mbuf_4  [expr {($opcode >> 4) & 1}]
        set mbuf_6  [expr {($opcode >> 6) & 1}]
        set mbuf_7  [expr {($opcode >> 7) & 1}]
        set mbuf_8  [expr {($opcode >> 8) & 1}]
        set group1  [expr {($opcode & 07400) == 07000}]
        set group2  [expr {($opcode & 07401) == 07400}]
        set cla     [expr {$group1 && $msfetch && $mbuf_7}]
        set cll     [expr {$group1 && $msfetch && $mbuf_6}]

        ;# group1 CLA,CLL happen at TP2 so clear the 'old' values before computing what TS3 will see
        set clracum [expr {$cla ? 0 : $oldacum}]
        set clrlink [expr {$cll ? 0 : $oldlink}]

        ;# compute remaining signals valid during TS3
        set iropr   [expr {($opcode & 07000) == 07000}]
        set e67a    [expr {! ($mbuf_8 && $msfetch && $mbuf_0 && $iropr && ! $mbuf_2 && ! $mbuf_1)}]
        set e77a    [expr {! ($iropr && $msexec)}]
        set extarex [expr {! ($e67a && $e77a)}]
        set iop     [expr {($opcode & 07000) == 06000}]
        set iratd   [expr {(($opcode & 06000) == 00000) || (($opcode & 07000) == 03000)}]
        set e88a    [expr {$group1 | $group2}]
        set e58d    [expr {! ($msexec && $iratd)}]
        set e85d    [expr {! ($msfetch && $e88a)}]
        set e86a    [expr {! ($e58d && ! $extarex & $e85d && ! $iop)}]
        set rsel    [expr {($msfetch && $group1) ? (($opcode >> 1) & 7) : 0}]
        set comln   [expr {$mbuf_4 && $group1}]
        set aluq_12 [expr {$cout ^ $clrlink ^ $comln}]
        set irtad   [expr {($opcode & 07000) == 01000}]
        set e58a    [expr {! ($irtad && $msexec)}]
        set e75d    [expr {! ($group1 && $msfetch)}]
        set e76b    [expr {! ($e58a && $e75d && ! $extarex)}]

        switch $rsel {
            0 {
                set rotq $aluq
                set rotq_12 $aluq_12
            }
            1 {
                set rotq [expr {(($aluq >> 6) & 63) | (($aluq & 63) << 6)}]
                set rotq_12 $aluq_12
            }
            2 {
                set rotq [expr {(($aluq << 1) & 4095) | $aluq_12}]
                set rotq_12 [expr {$aluq >> 11}]
            }
            3 {
                set rotq [expr {(($aluq << 2) & 4095) | ($aluq_12 << 1) | ($aluq >> 11)}]
                set rotq_12 [expr {($aluq >> 10) & 1}]
            }
            4 {
                set rotq [expr {($aluq >> 1) | ($aluq_12 << 11)}]
                set rotq_12 [expr {$aluq & 1}]
            }
            5 {
                set rotq [expr {($aluq >> 2) | ($aluq_12 << 10) | (($aluq << 11) & 4095)}]
                set rotq_12 [expr {($aluq >> 1) & 1}]
            }
            default {
                set rotq 0
                set rotq_12 0
            }
        }

        set lndat [expr {$extarex ? $lnktog : $rotq_12}]

        ;# get opcode loaded into IREG and MBUF by doing FETCH TP1
        pin set majst 1 aluq $opcode inbus $opcode
        pin set tp1 1
        set x [pin ireg mbuf]
        if {[lindex $x 0] != $opcode >> 9} {error "ireg did not load opcode"}
        if {[lindex $x 1] != $opcode} {error "mbuf did not load opcode"}
        pin set tp1 0

        ;# set up the random major state and other inputs
        pin set majst $majst aluq $aluq iop $iop cout $cout lnktog $lnktog

        ;# pulse TP2 which possibly clears acum and/or link
        pin set tp2 1
        set x [pin acum link bwcov]
        set newacum  [lindex $x 0]
        set newlink  [lindex $x 1]
        set newbwcov [lindex $x 2]
        if {($newacum != $clracum) || ($newlink != $clrlink)} {
            puts [format "cla=%o cll=%o newacum=%04o clracum=%04o newlink=%o clrlink=%o" $cla $cll $newacum $clracum $newlink $clrlink]
            break
        }

        ;# TP2 pulse loads bwcov from cout if WRDCT or EXEC cycle
        if {$newbwcov != (($mswrdct || $msexec) ? $cout : $oldbwcov)} {
            puts "newbwcov=$newbwcov != ((mswrdct=$mswrdct || msexec=$msexec) ? cout=$cout : oldbwcov=$oldbwcov"
            break
        }

        pin set tp2 0

        ;# say we are in TS3 cuz we are about to pulse TP3
        pin set ts3 1

        ;# all acum,link loading is on posedge TP3
        pin set tp3 1

        ;# verify acum loaded with new value or retained old value
        set x [pin acum link]
        set newacum [lindex $x 0]
        set newlink [lindex $x 1]
        if {($newacum != ($e86a ? $rotq : $clracum)) || ($newlink != ($e76b ? $lndat : $clrlink))} {
            puts ""
            puts [format "bad acum value newacum=%04o != ( e86a=%o ? rotq=%04o : clracum=%04o )" $newacum $e86a $rotq $clracum]
            puts "  msfetch=$msfetch"
            puts "   msexec=$msexec"
            puts "   mbuf_0=$mbuf_0"
            puts "   mbuf_1=$mbuf_1"
            puts "   mbuf_2=$mbuf_2"
            puts "   mbuf_4=$mbuf_4"
            puts "   mbuf_8=$mbuf_8"
            puts "    iropr=$iropr"
            puts "  oldlink=$oldlink"
            puts "    comln=$comln"
            puts "     cout=$cout"
            puts "   lnktog=$lnktog"
            puts "     rsel=$rsel"
            puts "     e67a=$e67a"
            puts "     e77a=$e77a"
            puts "  extarex=$extarex"
            puts "   group1=$group1"
            puts "   group2=$group2"
            puts "      iop=$iop"
            puts "    iratd=$iratd"
            puts "     e88a=$e88a"
            puts "     e58d=$e58d"
            puts "     e85d=$e85d"
            puts "     e86a=$e86a"
            puts ""
            pausetty "pause"
            break
        }

        pin set majst 0 aluq 0 tp3 0 ts3 0

        set oldacum  $newacum
        set oldlink  $newlink
        set oldbwcov $newbwcov
    }
}

# test program counter register
# theoretically tests all conditions where it should and shouldn't load or increment
proc testpctr {} {

    ;# get starting pctr
    set oldpctr [pin pctr]

    pin set tp1 0 tp2 0 run 1
    set run 1

    set ntest 0
    while {! [ctrlcflag]} {

        ;# see what major state we are going to do (range 1..9)
        set majst [expr {[randbits 4] % 9 + 1}]

        ;# generate random opcode
        set opcode [randbits 12]

        ;# generate random 12-bit value to load into pctr
        set aluq [randbits 12]

        ;# generate random 1-bit link values
        set cout [randbits 1]       ;# TAD instruction
        set lnktog [randbits 1]     ;# extar instructions

        ;# print about the test case
        incr ntest
        puts [format "%9d majst=%X opcode=%04o aluq=%04o cout=%o lnktog=%o oldpctr=%04o" \
            $ntest $majst $opcode $aluq $cout $lnktog $oldpctr]

        ;# get opcode loaded into IREG and MBUF by doing FETCH TP1
        pin set majst 1 aluq $opcode inbus $opcode
        pin set tp1 1
        set x [pin ireg mbuf]
        if {[lindex $x 0] != $opcode >> 9} {error "ireg did not load opcode"}
        if {[lindex $x 1] != $opcode} {error "mbuf did not load opcode"}
        pin set tp1 0

        set iop    [expr {($opcode & 07000) == 06000}]
        set ioskip [randbits 1]

        ;# set up the random major state and other inputs
        ;# run is always 1 while doing TS2,TS3
        pin set majst $majst aluq $aluq iop $iop cout $cout lnktog $lnktog ioskip $ioskip run 1
        set run 1

        ;# make sure console switches all off (so _ldadclk = 1)
        pin set swexam 0 swdepos 0 swldad 0
        set _ldadclk 1

        ;# test pctr updates during TS2 then TS3
        for {set ts 2} {$ts <= 3} {incr ts} {
            for {set pulse 0} {$pulse <= 1} {incr pulse} {
                set bwcov [pin bwcov]
                set acum  [pin acum]
                set link  [pin link]

                ;# send updated ts,tp signals to the physical board
                set ts2 [expr {$ts == 2}]
                set ts3 [expr {$ts == 3}]
                set tp2 [expr {$ts2 & $pulse}]
                set tp3 [expr {$ts3 & $pulse}]
                pin set tp2 $tp2 tp3 $tp3 ts2 $ts2 ts3 $ts3

                ;# compute what internal signals should be for the random numbers and timestate, timepulse
                set msfetch [expr {$majst == 1}]
                set msdefer [expr {$majst == 2}]
                set msexec  [expr {$majst == 3}]
                set msintak [expr {$majst == 7}]

                set iropr   [expr {($opcode & 07000) == 07000}]
                set group2  [expr {($opcode & 07401) == 07400}]
                set iop     [expr {($opcode & 07000) == 06000}]
                set irisz   [expr {($opcode & 07000) == 02000}]
                set irjms   [expr {($opcode & 07000) == 04000}]
                set irjmp   [expr {($opcode & 07000) == 05000}]
                set dirjmp  [expr {($opcode & 07400) == 05000}]

                set mbuf_3  [expr {($opcode >> 3) & 1}]
                set mbuf_4  [expr {($opcode >> 4) & 1}]
                set mbuf_5  [expr {($opcode >> 5) & 1}]
                set mbuf_6  [expr {($opcode >> 6) & 1}]

                set skipneg [expr {$mbuf_6 & ($acum >> 11)}]
                set skipzer [expr {$mbuf_5 & ($acum == 0)}]
                set skiplnk [expr {$mbuf_4 & $link}]
                set g2skip  [expr {$mbuf_3 ^ ($skipneg | $skipzer | $skiplnk)}]

                set e76c    [expr {! ($ioskip && $msexec && $iropr)}]
                set e76a    [expr {! ($g2skip && $msfetch && $group2)}]
                set e75c    [expr {! ($iop && $ioskip)}]
                set e48b    [expr {! ($irisz && $bwcov && $msexec)}]
                set e66b    [expr {! ($e76c && $e76a && $e75c && $e48b)}]
                set e85a    [expr {! ($msfetch && $ts2)}]
                set e75a    [expr {! ($ts3 & $e66b)}]
                set pcinc   [expr {! ($e85a && $e75a)}]

                set e84d    [expr {! ($tp2 && $msfetch)}]
                set pcclk   [expr {! ($_ldadclk && ! $tp3 && $e84d)}]

                set e57b    [expr {! ($dirjmp && $msfetch)}]
                set e57c    [expr {! ($msexec && $irjms)}]
                set e77d    [expr {! ($msdefer && $irjmp)}]
                set e66a    [expr {! ($e57b && $e57c && ! $msintak && $e77d)}]
                set e55b    [expr {! ($ts3 && $e66a)}]
                set _pcld   [expr {$run && $e55b}]

                ;# if pctr was clocked, update what the value should be
                set updpctr $oldpctr
                if {$pcclk &   $pcinc} {set updpctr [expr {($updpctr + 1) & 4095}]}
                if {$pcclk & ! $_pcld} {set updpctr $aluq}

                ;# make sure actual pc matches
                set newpctr [pin pctr]
                if {$newpctr != $updpctr} {
                    error [format "newpctr=%04o updpctr=%04o oldpctr=%04o" $newpctr $updpctr $oldpctr]
                }

                set oldpctr $newpctr
            }
            pin set tp2 0 tp3 0
            pin set ts2 0 ts3 0
        }

        ;# set up random number to possibly load into pctr via switches
        ;# not running while testing switches (all of TS1,2,3,4 and TP1,2,3,4 are 0)
        set aluq [randbits 12]
        set run 0

        ;# test console switch loading
        ;# loads for ldad switch in any state
        ;#           exam switch when already in exam state
        ;#           depos switch when already in depos state
        ;#   for the exam,depos cases, processor would set aluq=pctr+1 to increment pctr
        ;#   ... but here we just use a random number for aluq
        set msdepos [expr {$majst == 8}]
        set msexam  [expr {$majst == 9}]
        set swtch   [randbits 2]
        set swexam  [expr {$swtch == 1}]
        set swdepos [expr {$swtch == 2}]
        set swldad  [expr {$swtch == 3}]
        set ldpcen  [expr {($swexam & $msexam) | ($swdepos & $msdepos) | $swldad}]

        puts [format "          majst=%X swtch=%o     aluq=%04o                 oldpctr=%04o" \
            $majst $swtch $aluq $oldpctr]
        pin set aluq $aluq run 0 swexam $swexam swdepos $swdepos swldad $swldad

        ;# pulse memacsw, it will pulse pcclk if enabled by ldpcen
        pin set memacsw 1
        set newpctr [pin pctr]
        if {$newpctr != ($ldpcen ? $aluq : $oldpctr)} {
            error [format "majst=%X swtch=%o newpctr=%04o ldpcen=%o aluq=%04o oldpctr=%04o" \
                $majst $swtch $newpctr $ldpcen $aluq $oldpctr]
        }

        pin set memacsw 0 swexam 0 swdepos 0 swldad 0

        set oldpctr $newpctr
    }
}

# test memory address register
# theoretically tests all conditions where it should and shouldn't load
proc testmadr {} {

    ;# get starting madr
    set oldmadr [pin madr]

    pin set tp1 0 tp2 0 run 1
    set run 1

    set ntest 0
    while {! [ctrlcflag]} {

        ;# see what major state we are going to do (range 1..9)
        set majst [expr {[randbits 4] % 9 + 1}]

        ;# generate random 12-bit value to load into madr
        set aluq [randbits 12]

        ;# print about the test case
        incr ntest
        puts [format "%9d majst=%X   TP4   aluq=%04o oldmadr=%04o" $ntest $majst $aluq $oldmadr]

        ;# set up major state and random number to load
        pin set majst $majst set aluq $aluq

        ;# make sure console switches all off (so _ldadclk = 1)
        pin set memacsw 0 swexam 0 swdepos 0 swldad 0

        ;# pulse TP4 to maybe load madr
        pin set tp4 1
        set newmadr [pin madr]
        if {$newmadr != (($majst & 8) ? $oldmadr : $aluq)} {error "madr TP4 mismatch"}
        pin set tp4 0
        set oldmadr $newmadr

        ;# set up random number to possibly load into madr via switches
        set aluq [randbits 12]

        ;# test console switch loading
        ;# loads for ldad switch in any state
        ;#           exam switch when already in exam state
        ;#           depos switch when already in depos state
        set msdepos [expr {$majst == 8}]
        set msexam  [expr {$majst == 9}]
        set swtch   [randbits 2]
        set swexam  [expr {$swtch == 1}]
        set swdepos [expr {$swtch == 2}]
        set swldad  [expr {$swtch == 3}]
        set ldmaen  [expr {($swexam & $msexam) | ($swdepos & $msdepos) | $swldad}]

        puts [format "          majst=%X swtch=%o aluq=%04o oldmadr=%04o" $majst $swtch $aluq $oldmadr]
        pin set aluq $aluq swexam $swexam swdepos $swdepos swldad $swldad

        ;# pulse memacsw, it will pulse maload if enabled by ldmaen
        pin set memacsw 1
        set newmadr [pin madr]
        if {$newmadr != ($ldmaen ? $aluq : $oldmadr)} {
            error [format "majst=%X swtch=%o newmadr=%04o ldmaen=%o aluq=%04o oldmadr=%04o" \
                $majst $swtch $newmadr $ldmaen $aluq $oldmadr]
        }

        pin set memacsw 0 swexam 0 swdepos 0 swldad 0

        set oldmadr $newmadr
    }
}

# test memory buffer register
# theoretically tests all conditions where it should and shouldn't load
proc testmbuf {} {

    ;# get starting mbuf
    set oldpctr [pin mbuf]

    pin set tp1 0 tp2 0 run 1
    set run 1

    set ntest 0
    while {! [ctrlcflag]} {

        ;# see what major state we are going to do (range 1..9)
        set majst [expr {[randbits 4] % 9 + 1}]

        ;# if doing defer state, load a random address in madr
        set madr -1
        if {$majst == 2} {
            set madr [randbits 12]
            loadmadr $madr
        }

        ;# generate random opcode
        set opcode [randbits 12]

        ;# generate random 12-bit value to load into mbuf
        set aluq [randbits 12]

        ;# generate random 1-bit link values
        set brkwrm [randbits 1]
        set cainc  [randbits 1]

        ;# print about the test case
        incr ntest
        puts [format "%9d majst=%X opcode=%04o aluq=%04o" $ntest $majst $opcode $aluq]

        ;# get opcode loaded into IREG and MBUF by doing FETCH TP1
        pin set majst 1 aluq $opcode inbus $opcode
        pin set tp1 1
        set x [pin ireg mbuf]
        if {[lindex $x 0] != $opcode >> 9} {error "ireg did not load opcode"}
        if {[lindex $x 1] != $opcode} {error "mbuf did not load opcode"}
        pin set tp1 0

        ;# set input pins to the random values
        pin set majst $majst aluq $aluq brkwrm $brkwrm cainc $cainc

        ;# mbuf current has 12-bit opcode in it
        set oldmbuf $opcode

        ;# see if loading at TP2 is enabled by the state and opcode
        set irisz   [expr {($opcode & 07000) == 02000}]
        set irdca   [expr {($opcode & 07000) == 03000}]
        set irjms   [expr {($opcode & 07000) == 04000}]
        set msfetch [expr {$majst == 1}]
        set msdefer [expr {$majst == 2}]
        set msexec  [expr {$majst == 3}]
        set mswrdct [expr {$majst == 4}]
        set mscurad [expr {$majst == 5}]
        set msbreak [expr {$majst == 6}]
        set msintak [expr {$majst == 7}]
        set msdepos [expr {$majst == 8}]
        set autoinc [expr {($madr >> 3) == 1}]
        set e48a    [expr {$irisz | $irjms | $irdca}]
        set e58b    [expr {! ($e48a && $msexec)}]
        set e92a    [expr {! ($brkwrm && $msbreak)}]
        set e93c    [expr {! ($cainc && $mscurad)}]
        set e77c    [expr {! ($msdefer && $autoinc)}]
        set e96a    [expr {! ($e58b && ! $msintak && ! $mswrdct && ! $msdepos && $e92a && $e93c && $e77c)}]

        ;# don't test loading mbuf in fetch again here so opcode doesn't get messed up
        if {! $msfetch} {
            ;# not doing fetch, test TP1 mbuf load for other states
            pin set tp1 1
            set newmbuf [pin mbuf]
            if {$newmbuf != $aluq} {error "mbuf tp1 mismatch"}
            pin set tp1 0
            ;# mbuf now has aluq in it
            set oldmbuf $aluq
            ;# get new random value for TP2
            set aluq [randbits 12]
            pin set aluq $aluq
        }

        ;# test loading at TP2
        pin set tp2 1
        set newmbuf [pin mbuf]
        if {$newmbuf != ($e96a ? $aluq : $oldmbuf)} {error "mbuf tp2 mismatch"}
        pin set tp2 0
    }
}

# test brkcyc flipflop
proc testbrkcyc {} {

    ;# reset the flipflop
    pin set busini 1 majst 0 ts1 0 ts2 0 ts3 0 ts4 0 tp1 0 tp2 0 tp3 0 tp4 0
    pin set busini 0

    if {[pin brkcyc]} {error "brkcyc not clear on startup"}

    set ntest 0
    while {! [ctrlcflag]} {

        ;# see what major state we are going to do (range 1..9)
        set majst [expr {[randbits 4] % 9 + 1}]
        incr ntest
        puts [format "%9d majst=%X" $ntest $majst]
        pin set majst $majst
        if {[pin brkcyc]} {error "brkcyc not clear after setting majst $majst"}

        ;# TS1 sets the flipflop only if majst == 6
        pin set ts1 1
        if {$majst == 6} {
            if {! [pin brkcyc]} {error "brkcyc not set after setting TS1 of majst $majst"}
        } else {
            if {[pin brkcyc]} {error "brkcyc not clear after setting TS1 of majst $majst"}
        }
        pin set ts1 0

        ;# TS4 always clears the flipflop
        pin set ts4 1
        if {[pin brkcyc]} {error "brkcyc not clear after setting TS4"}
        pin set ts4 0
    }
}

# madr loads on posedge maload
#  inputs:
#   swexam  : exam switch pressed
#   msexam  : currently in exam state
#   swdepos : depos switch pressed
#   msdepos : currently in depos state
#   swldad  : ldad switch pressed
#   tp4     : 100nS pulse for TP4
#   majst_3 : currently in exam or depos state
#   memacsw : 100nS pulse 500nS after ldad, exam, depos switch pressed
# compute maload:
#   e84b    = ~ (swexam & msexam)
#   e84a    = ~ (swdepos & msdepos)
#   e74c    = ~ (e84b & e84a & ~ swldad)
#   _ldaclk = ~ (memacsw & e74c)
#   e92d    = ~ (tp4 & ~ majst_3)
#   maload  = ~ (_ldaclk & e92d)

# mbuf loads on posedge mbload
#  input:
#   irisz    : ireg holds ISZ
#   irjms    : ireg holds JMS
#   irdca    : ireg holds DCA
#   cainc    : curad increment
#   autoinc  : defer autoinc
#   msdefer  : major state DEFER
#   msexec   : major state EXEC
#   _mswrdct : major state WRDCT
#   mscurad  : major state CURAD
#   msbreak  : major state BREAK
#   _msintak : major state INTAK
#   _msdepos : major state DEPOS
#   tp1      : 100nS pulse for TP1
#   tp2      : 100nS pulse for TP2
#  compute mbload:
#   e48a   =   irisz | irjms | irdca
#   e58b   = ~ (e48a & msexec)
#   e92a   = ~ (brkwrm & msbreak)
#   e93c   = ~ (cainc & mscurad)
#   e77c   = ~ (msdefer & autoinc)
#   e96a   = ~ (e58b & _msintak & _mswrdct & _msdepos & e92a & e93c & e77c)
#   e85b   = ~ (tp2 & e96a)
#   mbload = ~ (~ tp1 & e85b)

# pctr

