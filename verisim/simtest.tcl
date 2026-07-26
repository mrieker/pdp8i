
;# random instruction test for simulator
;#  $ ./verimain.x86_64
;#  > source simtest.tcl
;#  > simtest

set acum         0
set cmat1        0
set cmat2        0
set cmdmarqst    0
set dmarqst      0
set dmawdata     0
set haltdelay    0
set haltwhy      ""
set instrno      0
set intdelayed   0
set intenabled   0
set intrequest   0
set linc         0
set memdis       0
set memcycno     0
set memcycwcover 0
set mquo         0
set opcode       0
set panelhalt    0
set perclock     0
set pctr         0
set sctr         0
set shat1        0
set ttat1        0
set ttat2        0
set ttinten      1
set ttkbchar     0
set ttkbflag     0
set ttprchar     0
set ttprflag     0
set ttprfull     0
set wfitests     0

set xmem_dfld                 0
set xmem_ifld                 0
set xmem_ifldafterjump        0
set xmem_intdisableduntiljump 0
set xmem_saveddfld            0
set xmem_savedifld            0

set MS_FETCH 1  ;# memory cycle is fetching instruction
set MS_DEFER 2  ;# memory cycle is reading pointer
set MS_EXEC  3  ;# memory cycle is for executing instruction
set MS_WRDCT 4  ;# memory cycle is for incrementing dma word count
set MS_CURAD 5  ;# memory cycle is for reading dma address
set MS_BREAK 6  ;# memory cycle is for dma data word transfer
set MS_INTAK 7  ;# memory cycle is for interrupt acknowledge
set MS_DEPOS 8  ;# memory cycle is for deposit switch
set MS_EXAM  9  ;# memory cycle is for examine switch

set testcons [getenv testcons 1]  ;# test console functions
set testdma  [getenv testdma  1]
set testexar [getenv testexar 1]  ;# test extended arithmetic
set testxmem [getenv testxmem 1]  ;# test extended memory
set runquiet [getenv runquiet 1]  ;# tell runstep command to keep quiet

proc simtest {} {
    global acum
    global begclkns
    global cmat1
    global cmat2
    global cmdmarqst
    global dmarqst
    global dma3cycle
    global dmacainc
    global dmawrmem
    global dmawdata
    global dmaaddr
    global dmafield
    global instrno
    global intdelayed
    global intenabled
    global intrequest
    global linc
    global memcycwcover
    global mquo
    global opcode
    global perclock
    global pctr
    global sctr
    global shat1
    global swdfldpend
    global swifldpend
    global swregpend
    global testcons
    global testdma
    global testexar
    global testxmem
    global ttat1 ttat2 ttinten ttkbchar ttkbflag ttprchar ttprflag ttprfull
    global usefpi2c
    global wfitests
    global xmem_dfld
    global xmem_ifld
    global xmem_ifldafterjump
    global xmem_intdisableduntiljump
    global xmem_saveddfld
    global xmem_savedifld
    global MS_FETCH
    global MS_DEFER
    global MS_EXEC
    global MS_WRDCT
    global MS_CURAD
    global MS_BREAK
    global MS_INTAK
    global MS_DEPOS
    global MS_EXAM

    ;# usefpi2c=0: use console.kicad_sch internal counters to scan lights/switches
    ;#          1: use pdp8ifpi2c.v fpga counters to scan lights/switches
    set usefpi2c [getenv usefpi2c 0]
    puts "simtest: usefpi2c=$usefpi2c"

    ;# clkratm1: clock pdp at 100MHz / (clkratm1 + 1)
    set clkratm1 [getenv clkratm1 9]
    puts "simtest: clkratm1=$clkratm1"
    arm set 4 $clkratm1     ;# 4 = zynq.v regctld
                            ;# also asserts hdw_poweron

    ;# reset then start processor
    hardreset
    puts "simtest: hardreset complete"

    set shat0 [arm find SH]
    set shat1 [expr {$shat0 + 1}]
    arm set $shat1 0x80000000   ;# sh_frzonerr : freeze clocking on error

    set cmat0 [arm find CM]
    set ttat0 [arm find TT]
    startat 0
    waitassert TS1
    puts "simtest: startat 0 complete"
    verify12 [bus oMADR] 0 "bad start PC"
    set acum [bus oACUM]
    set linc [bus oLINK]

    ;# pdp8icmem.v ARM-side register indices in the 4K page
    set cmat1 [expr {$cmat0 + 1}]
    set cmat2 [expr {$cmat0 + 2}]
    ;# pdp8itty.v ARM-side register indices in the 4K page
    set ttat1 [expr {$ttat0 + 1}]
    set ttat2 [expr {$ttat0 + 2}]

    ;# set switches for OSR/LDAD testing
    set swdfldpend  [expr {$testxmem ? [randbits 3] : 0}]
    set swifldpend  [expr {$testxmem ? [randbits 3] : 0}]
    set swregpend [randbits 12]
    swtch set dfld $swdfldpend ifld $swifldpend reg $swregpend

    ;# run random instructions, verifying the cycles
    set instrno 0
    set lastopc -1
    set nextfetch 0
    set begclkns -1
    set needmqsca 0

    while {! [ctrlcflag]} {
        set ercode [catch {

            ;# once through this loop per instruction, dma transfer or interrupt acknowledge
            ;# processor should be at beginning of TS1 in FETCH, WDCNT, BREAK or INTAK cycle

            set oldttintrq [ttintrq]
            if {($wfitests & 4) && ([randbits 6] == 0)} {
                set r [randbits 2]
                switch $r {
                    0 {
                        verify32 [arm $ttat1] [expr {($ttkbflag << 31) | 0x40000000 | $ttkbchar}] "arm ttkb register"
                    }
                    1 {
                        verify32 [arm $ttat2] [expr {($ttprflag << 31) | ($ttprfull << 30) | $ttprchar}] "arm ttpr register"
                    }
                    2 {
                        set ttkbchar [randbits 12]
                        set ttkbflag 1
                        puts [format "                                                       ttkbflag <= 1; ttkbchar <= %04o" $ttkbchar]
                        arm set $ttat1 [expr {0xC0000000 | $ttkbchar}]
                    }
                    3 {
                        set ttprflag 1
                        set ttprfull 0
                        puts "                                                       ttprflag <= 1; ttprfull <= 0"
                        arm set $ttat2 0x80000000
                    }
                }
            }

            startline

            set effaddr 0
            set randsr  0
            set execst $MS_EXEC

            ;# maybe do a dma cycle
            if {! $nextfetch && $cmdmarqst && [arm $cmat2]} {

                ;# dma requested via arm interface of pdp8icmem.v
                puts -nonewline "         CMDMA"
                set rd [dodmacycle \
                        [expr {($cmdmarqst >> 29)    & 1}] \
                        [expr { $cmdmarqst        & 4095}] \
                        [expr {($cmdmarqst >> 28)    & 1}] \
                        [expr {($cmdmarqst >> 15)    & 1}] \
                        [expr {($cmdmarqst >> 16) & 4095}] \
                        [expr {($cmdmarqst >> 12) &    7}]]
                if {! ($cmdmarqst & 0x8000)} {
                    set cmdmarqst [arm $cmat1]
                    verify12 $rd [expr {($cmdmarqst >> 16) & 4095}] "pdp8icmem capture read data"
                }
                set cmdmarqst 0
            } elseif {! $nextfetch && $dmarqst && [bus oBRKGNTO]} {

                ;# dma requested via pins at top of backplane.v
                puts -nonewline "         DMA  "
                dodmacycle $dma3cycle $dmaaddr $dmacainc $dmawrmem $dmawdata $dmafield
            } else {

                ;# maybe interrupt request is next
                set datafield $xmem_ifld
                if {! $xmem_intdisableduntiljump && $intenabled && ! $nextfetch && ($intrequest || $oldttintrq)} {
                    puts -nonewline "INTAK"

                    set intrequest 0        ;#TODO: drop request random number of cycles later
                    bus set iINTRQST 0

                    ;# save and reset fields
                    set xmem_saveddfld $xmem_dfld
                    set xmem_savedifld $xmem_ifld
                    set xmem_dfld 0
                    set xmem_ifld 0
                    set xmem_ifldafterjump 0

                    ;# disable interrupts then execute a JMS 0 instruction
                    set intdelayed 0
                    set intenabled 0
                    set opcode 04000
                    set execst $MS_INTAK
                } else {

                    ;# delayed ION active now that we are about to do a fetch
                    set intenabled $intdelayed

                    switch $needmqsca {
                        0 {
                            if {! ($wfitests & 4) && $ttinten && ! ($acum & 1)} {
                                set opcode 06035                                ;# maybe disable tty interrupt cuz it's almost always on
                                                                                ;# ...so we can test WFI waiting a few cycles
                            } else {
                                ;# send random opcode
                                while true {
                                    set opcode [randbits 12]
                                    if {($opcode & 06000) != 06000} break       ;# and,tad,isz,dca,jms,jmp
                                    if {$opcode == 06001} break                 ;# ION
                                    if {$opcode == 06002} break                 ;# IOF
                                    if {$opcode == 06004} break                 ;# used to test skip/acclr
                                    if {($opcode & 07770) == 06310} {
                                        set opcode 06313                        ;# WFI
                                        break
                                    }
                                    if {$testxmem && ($lastopc != 06001)} {     ;# don't do memext opcodes if instruction after ION
                                        if {($opcode & 07704) == 06200} break
                                        if {($opcode & 07707) == 06204} break
                                    }
                                    if {($opcode & 07770) == 06030} break       ;# tty keyboard opcodes
                                    if {($opcode & 07770) == 06040} break       ;# tty printer opcodes
                                    if {($opcode & 07400) == 07000} {           ;# group 1
                                        ##if {($opcode & 016) == 002} continue    ;# bsw
                                        if {($opcode & 014) == 014} continue    ;# 6,7
                                        break
                                    }
                                    if {($opcode & 07401) == 07400} {           ;# group 2
                                        if {($opcode & 2) && (! $testcons || ([randbits 2] != 0))} {
                                            incr opcode -2                      ;# don't do HLT
                                        }
                                        set swregsent [swtch reg]
                                        if {$swregsent != $swregpend} {         ;# see if processor has absorbed switches
                                            set opcode [expr {$opcode & 07773}] ;# if not, don't do OSR
                                        }
                                        break
                                    }
                                    if {$testexar && (($opcode & 07401) == 07401)} {  ;# group 3 (extended arithmetic)
                                        ;# follow SCL,MUY,DVI,NMI,SHL,ASR,LSR with CLA MQA then CLA SCA so pdp8ishad.v can verify MQ and SC
                                        if {$opcode & 14} {
                                            set needmqsca 1
                                        }
                                        break
                                    }
                                }
                            }
                        }
                        1 {
                            set opcode 07501                                ;# CLA MQA - read MQ into AC
                            set needmqsca 2
                        }
                        2 {
                            set opcode 07441                                ;# CLA SCA - read SC into AC
                            set needmqsca 0
                        }
                    }
                    puts -nonewline [format "OP=%04o  %s" $opcode [disop $pctr $opcode]]
                    set lastopc $opcode

                    ;# perform fetch memory cycle
                    memorycycle $MS_FETCH $xmem_ifld $pctr $opcode $opcode

                    ;# compute effective address then increment program counter
                    set effaddr [expr {(($opcode & 00200) ? ($pctr & 07600) : 0) | ($opcode & 00177)}]
                    set pctr [expr {($pctr + 1) & 07777}]

                    ;# maybe do a defer cycle
                    if {($opcode & 07000) < 06000} {
                        puts -nonewline " ="
                        if {$opcode & 0400} {
                            checkhalted
                            set pointer [randbits 12]
                            set autoinc [expr {($pointer + (($effaddr & 07770) == 00010)) & 07777}]
                            puts -nonewline [format " %o%04o /" $xmem_ifld $effaddr]
                            memorycycle $MS_DEFER $xmem_ifld $effaddr $pointer $autoinc
                            set effaddr $autoinc
                            set datafield $xmem_dfld
                        }
                    }
                }

                ;# do the exec cycle
                switch [expr {$opcode >> 9}] {

                    4 {             ;# jms
                        set xmem_intdisableduntiljump 0     ;# done at end of fetch or defer
                        set xmem_ifld $xmem_ifldafterjump   ;# ditto
                        checkhalted                         ;# maybe halt, maybe abort instruction
                        set operand [randbits 12]
                        puts -nonewline [format " %o%04o / %04o <= %04o" $xmem_ifld $effaddr $operand $pctr]
                        memorycycle $execst $xmem_ifld $effaddr $operand $pctr
                        set pctr [expr {($effaddr + 1) & 07777}]
                    }

                    5 {             ;# jmp
                        set xmem_intdisableduntiljump 0
                        set xmem_ifld $xmem_ifldafterjump
                        set pctr $effaddr
                        puts -nonewline [format " %o%04o" $xmem_ifld $pctr]
                    }

                    6 {             ;# iot
                        puts -nonewline [format " / %04o" $acum]
                    }

                    7 {             ;# opr
                        if {! ($opcode & 0400)} {
                            ;# group 1
                            if {$opcode & 00200} {set acum 0}
                            if {$opcode & 00100} {set linc 0}
                            if {$opcode & 00040} {set acum [expr {$acum ^ 07777}]}
                            if {$opcode & 00020} {set linc [expr {$linc ^ 1}]}
                            if {$opcode & 00001} {
                                set acum [expr {($acum + 1) & 07777}]
                                if {$acum == 0} {set linc [expr {$linc ^ 1}]}
                            }
                            switch [expr {($opcode >> 1) & 7}] {
                                1 {                                 ;# BSW
                                    set acum [expr {(($acum & 077) << 6) | ($acum >> 6)}]
                                }
                                2 {                                 ;# RAL
                                    set acum [expr {($acum << 1) | $linc}]
                                    set linc [expr {($acum & 010000) != 0}]
                                    set acum [expr {$acum & 07777}]
                                }
                                3 {                                 ;# RTL
                                    set acum [expr {($acum << 2) | ($linc << 1) | ($acum >> 11)}]
                                    set linc [expr {($acum & 010000) != 0}]
                                    set acum [expr {$acum & 07777}]
                                }
                                4 {                                 ;# RAR
                                    set oldac $acum
                                    set acum [expr {($acum >> 1) | ($linc << 11)}]
                                    set linc [expr {($oldac & 1) != 0}]
                                }
                                5 {                                 ;# RTR
                                    set acum [expr {($acum >> 2) | ($linc << 10) | (($acum & 3) << 11)}]
                                    set linc [expr {($acum & 010000) != 0}]
                                    set acum [expr {$acum & 07777}]
                                }
                            }
                            puts -nonewline [format " => %o.%04o" $linc $acum]
                        } elseif {! ($opcode & 0001)} {
                            ;# group 2
                            if {[g2skip $opcode]} {
                                puts -nonewline " skip"
                                set pctr [expr {($pctr + 1) & 07777}]
                            }
                            if {$opcode & 0200} {set acum 0}
                            if {$opcode & 0004} {
                                puts -nonewline [format " sr:%04o" $swregpend]
                                set acum [expr {$acum | $swregpend}]
                            }
                            puts -nonewline [format " => %04o" $acum]
                        } else {
                            ;# group 3 (extended arithmetic)
                            if {$opcode & 6} {
                                checkhalted
                                ;# group 3 with memory operand
                                ;# supply a random value for value fetched from (PC)+
                                ;# then perform the extended arithmetic as part of the EXEC cycle
                                set operand [randbits 12]
                                puts -nonewline [format " %o%04o / %04o" $xmem_ifld $pctr $operand]
                                memorycycle $MS_EXEC $xmem_ifld $pctr $operand $operand
                                set pctr [expr {($pctr + 1) & 07777}]
                            }
                            ;# for non-memory operand instructions, the arithmetic was done as part of the FETCH
                            ;# in any case, we are now past TP3 and so can drop the extended arithmetic results
                            bus set iACCLEAR 0 iINBUS 0
                        }
                    }

                    default {               ;# and, tad, isz, dca
                        checkhalted
                        set operand [randbits 12]
                        puts -nonewline [format " %o%04o / %04o" $datafield $effaddr $operand]
                        switch [expr {$opcode >> 9}] {
                            0 {
                                memorycycle $MS_EXEC $datafield $effaddr $operand $operand
                                set acum [expr {$acum & $operand}]
                                puts -nonewline [format " => %04o" $acum]
                            }
                            1 {
                                memorycycle $MS_EXEC $datafield $effaddr $operand $operand
                                set sum [expr {$acum + ($linc ? 010000 : 0) + $operand}]
                                set acum [expr {$sum & 07777}]
                                set linc [expr {($sum >> 12) & 1}]
                                puts -nonewline [format " => %o.%04o" $linc $acum]
                            }
                            2 {
                                set incd [expr {($operand + 1) & 07777}]
                                puts -nonewline [format " => %04o" $incd]
                                memorycycle $MS_EXEC $datafield $effaddr $operand $incd
                                if {$incd == 0} {set pctr [expr {($pctr + 1) & 07777}]}
                            }
                            3 {
                                puts -nonewline [format " <= %04o" $acum]
                                memorycycle $MS_EXEC $datafield $effaddr $operand $acum
                                set acum 0
                            }
                            default {error "ABORT"}
                        }
                    }
                }
            }
            checkhalted

            ;# if did an OSR, set up new SR contents for next one
            ;# wait until after checkhalted call so processor used old SR
            if {($opcode & 07405) == 07404} {
                set swregpend [randbits 12]
                swtch set reg $swregpend
            }

        } errmsg]

        ;# get 0 if it worked normally
        ;# get 47 if halted and did ldad/depos/exam
        if {($ercode != 0) && ($ercode != 47)} {
            return -code $ercode "$errmsg $::errorInfo"
        }

        ;# print elapsed time for the instruction
        finishline

        ;# the accumulator and link should be up to date
        verifybit [bus oTS1]  1     "TS1 mismatch at end of instruction"
        verify12  [bus pctr]  $pctr "PC mismatch at end of instruction"
        verify12  [bus oACUM] $acum "AC mismatch at end of instruction"
        verifybit [bus oLINK] $linc "LINK mismatch at end of instruction"
        verify12  [bus mquo]  $mquo "MQ mismatch at end of instruction"
        verify12  [bus sctr]  $sctr "SC mismatch at end of instruction"

        ;# if halted and did ldad/depos/exam, next cycle will be a fetch, not wrdct/break/intak
        set nextfetch [expr {$ercode == 47}]
    }

    puts "stopping for control-C"
}

proc startline {} {
    global acum begclkns instrno linc mquo pctr sctr xmem_dfld xmem_ifld

    puts -nonewline [format "%10u : L.AC=%o.%04o MQ=%04o PC=%o%04o SC=%02o DF=%o : " \
        [incr instrno] $linc $acum $mquo $xmem_ifld $pctr $sctr $xmem_dfld]

    if {$begclkns < 0} {
        set begclkns [clk simns]
    }
}

;# print how much time it took
proc finishline {} {
    global begclkns
    set endclkns [clk simns]
    set deltclkns [expr {$endclkns - $begclkns}]
    puts [format "  (%u.%03u uS)" [expr {$deltclkns / 1000}] [expr {$deltclkns % 1000}]]
    set begclkns $endclkns
}

;# perform DMA (1 or 3) cycle
proc dodmacycle {dma3cycle dmaaddr dmacainc dmawrmem dmawdata dmafield} {
    global MS_WRDCT MS_CURAD MS_BREAK
    global memcycwcover

    if {$dma3cycle} {

        ;# WC state reads wordcount from dmaaddr field 0, increments it and writes it back
        ;# make wordcount overflow somewhat common for testing
        set oldwordcount [randbits 12]
        if {$oldwordcount & 04000} {set oldwordcount [expr {$oldwordcount | 07770}]}
        set newwordcount [expr {($oldwordcount + 1) & 07777}]
        puts -nonewline [format " WCT:%04o / %04o => %04o" $dmaaddr $oldwordcount $newwordcount]
        memorycycle $MS_WRDCT 0 $dmaaddr $oldwordcount $newwordcount
        checkhalted

        set wcshouldover [expr {$newwordcount == 0}]
        verifybit $memcycwcover $wcshouldover "BWC OVERFLOW mismatch"

        ;# CA state reads pointer from dmaaddr + 1 field 0, increments it and writes it back
        ;# then we use the incremented pointer for the transfer address
        set dmaaddr [expr {($dmaaddr + 1) & 07777}]
        set oldcuraddr [randbits 12]
        set newcuraddr [expr {($oldcuraddr + $dmacainc) & 07777}]
        puts -nonewline [format " CAD:%04o / %04o => %04o" $dmaaddr $oldcuraddr $newcuraddr]
        memorycycle $MS_CURAD 0 $dmaaddr $oldcuraddr $newcuraddr
        checkhalted
        set dmaaddr $newcuraddr
    }

    ;# transfer word at address dmafield:dmaaddr
    set dmardata [randbits 12]                  ;# random value that will be sent to processor as content of memory location dmafield:dmaaddr
    if {! $dmawrmem} {set dmawdata $dmardata}   ;# if writing, write will be value from dmastat2; if reading, write will be same as dmardata

    puts -nonewline [format " BRK:%o%04o / %04o" $dmafield $dmaaddr $dmardata]
    if {$dmawrmem} {
        puts -nonewline [format " => %04o" $dmawdata]
    }
    memorycycle $MS_BREAK $dmafield $dmaaddr $dmardata $dmawdata

    return $dmardata
}

;# clock through a memory cycle, verifying the address and data
;#  input:
;#   state = MS_state
;#   addr  = address it should be accessing
;#   rdata = data to send it for the read
;#   wdata = data it should send for writing
;#  output:
;#   returns with processor just exited TS4
;#   memcycwcover = processor's oBWCOV at beg of TS3
;#
;# steps through:
;#   TS1 = reading memory location
;#   TS2 = computing any modification to value
;#   TS3 = writing memory location
;#         update accumulator
;#   TS4 = update to next state
proc memorycycle {state field addr rdata wdata} {
    global cmat1 cmdmarqst
    global dma3cycle dmacainc dmarqst dmawrmem dmawdata dmaaddr dmafield
    global memcycwcover opcode
    global MS_BREAK MS_CURAD MS_DEPOS MS_EXAM MS_EXEC MS_FETCH MS_INTAK MS_WRDCT
    global haltdelay haltwhy memcycno memdis panelhalt testcons

    incr memcycno

    ;# maybe flip memdis flag
    ;#  memdis = 0 : extmemory.kicad_sch ram chips read data will be gated onto inbus during ts1
    ;#           1 : the ram chip data will not be gated onto inbus
    ;#               ...this tcl code must put read data directly on inbus during ts1
    if {$memcycno % 1024 == 0} {
        set memdis [randbits 1]
        arm set 1 [expr {$memdis << 24}]    ;# arm_iMEMDIS
        puts -nonewline " <<memdis=$memdis>>"
    }

    ;# maybe flip on an halt switch if none flipped on already
    ;# takes several cycles to soak through console board
    ;# don't do for exam/depos cycles so we don't interfere with subsequent start switch
    if {$testcons && ($panelhalt == 0) && ($state != $MS_DEPOS) && ($state != $MS_EXAM) && ($memcycno % 16 == 0)} {
        set panelhalt [randbits 2]
        switch $panelhalt {
            1 { swtch set sinst 1 }
            2 { swtch set sstep 1 }
            3 { swtch set stop  1 }
        }
    }

    ;# clock until we see TS1
    waitassert TS1

    ;# should now be fully transitioned to the major state
    verify12 [bus majst] $state "bad state at start of mem cycle"

    ;# get the read data on the INBUS so cpu can read it
    set expaddr [expr {($field << 12) | $addr}]
    if {$memdis} {
        ;# this script is the memory, so put read data directly on the INBUS
        arm set 1 [expr {(1 << 24) | ($rdata << 10)}]   ;# [24]=arm_iMEMDIS, [21:10]=arm_iINBUS
        ;# put unrelated number in extmemory.kicad_sch chip in case it is interfering
        mem $expaddr [randbits 12]
    } else {
        ;# extmemory.kicad_sch memory chip enabled, so put read data directly in chip
        ;# it should then soak onto INBUS
        mem $expaddr $rdata
    }

    ;# maybe generate a dma request via pdp8icmem.v
    ;# these have higher priority than plain dmarqsts
    if {! $cmdmarqst && ([randbits 6] == 0)} {
        set cmdmarqst [expr {[randbits 30] | 0x80000000}]
        arm set $cmat1 $cmdmarqst
        puts -nonewline " <<cmdmarqst>>"
    }

    waitassert TP1

    ;# cpu should be outputting address we expect
    set actaddr [expr {([bus memfield] << 12) | [bus oMADR]}]
    verify15 $actaddr $expaddr "XMA bad at beginning of $state cycle"

    ;# end of TS1 means it finished reading that memory location into MB
    waitnegate TS1

    ;# stop dumping memory read value onto iINBUS
    if {$memdis} {
        arm set 1 [expr {1 << 24}]                      ;# [24]=arm_iMEMDIS, [21:10]=arm_iINBUS
    }

    ;# maybe put dma write data out on the inbus during TS2
    if {$dmarqst && $dmawrmem && ($state == $MS_BREAK) && [bus oBRKGNTO]} {
        bus set iINBUS $dmawdata
    }

    ;# maybe request a dma (break) cycle
    ;# these have lower priority than cmdmarqsts
    if {! $dmarqst && ([randbits 6] == 0)} {
        startdmarequest
    }

    ;# MB should now have the value we wrote to the memory location or to the iINBUS
    verify12 [bus oMBUF] $rdata "MB during read"

    ;# maybe perform extended arithmetic
    if {(($state == $MS_FETCH) && (($opcode & 07407) == 07401)) ||
        (($state == $MS_EXEC)  && (($opcode & 07401) == 07401))} {
        extendedarithmetic $rdata
    }

    ;# wait for it to enter TS3, meanwhile cpu should possibly be modifying
    ;# the value and sending the value (modified or not) back to the memory
    waitassert TS3

    ;# break grant should clear at TP2 of a BREAK cycle
    ;# also time to drop request and dma write data
    if {$state == $MS_BREAK} {
        verifybit [bus oBRKGNTO] 0 "break grant after TP2 of BREAK cycle"
        set dmarqst 0
        bus set iBRKRQST 0 iINBUS 0
    }

    ;# maybe perform i/o
    set doesio [expr {($state == $MS_FETCH) && (($opcode & 07000) == 06000)}]
    verifybit [bus oIOP] $doesio "IOP during IO instruction"
    if $doesio {
        doioinstr $rdata
    }

    ;# beginning of TS3, MB should now have the possibly modified value
    set actaddr [expr {([bus memfield] << 12) | [bus oMADR]}]
    verify15 $actaddr $expaddr "XMA bad at beg TS3 of $state cycle"
    verify12 [bus oMBUF] $wdata "MB during writeback at beg TS3"

    ;# BWC_OVERFLOW is valid (assuming we're in WRDCT) at this TS3 through next cycle TP2
    set memcycwcover [bus oBWCOV]

    ;# processor clocks INTRQST at TP3, so output requests just prior to that
    requestint $state $rdata

    ;# wait for TP3 asserted then negated indicating value written to memory
    ;# also clocks in any io instruction result
    ;# and clocks in the step/stop switches
    waitassert TP3

    ;# MA and MB should still have write memory contents
    set actaddr [expr {([bus memfield] << 12) | [bus oMADR]}]
    verify15 $actaddr $expaddr "XMA bad at end TS3 of $state cycle"
    verify12 [bus oMBUF] $wdata "MB during writeback at end TS3"

    waitnegate TP3

    ;# clear any bits being output by io instruction
    if $doesio {
        verifybit [bus oIOP] 0 "IOP after IO instruction"
        bus set iACCLEAR 0 iIOSKIP 0 iINBUS 0
    }

    ;# verify the extmemory.kicad_sch memory contents
    if {! $memdis} {
        verify12 [mem $expaddr] $wdata [format "address %05o mismatch" $expaddr]
    }

    ;# if requesting break and it is granted, output address during all TS4s
    if {$dmarqst && [bus oBRKGNTO]} {
        bus set iINBUS $dmaaddr
    }

    ;# step to end of cycle
    waitassert TP4
    waitnegate TP4

    ;# stop outputting dma address so it doesn't jam up bus
    bus set iINBUS 0

    ;# check for halted/running
    if {$haltwhy != ""} {error "unprocessed haltwhy $haltwhy}
    set isrunning [bus oRUN]
    set newstate [bus majst]
    set sbhalted 0
    if {($state != $MS_DEPOS) && ($state != $MS_EXAM)} {
        ##set beginst [expr {($newstate == $MS_FETCH) || ($newstate == $MS_INTAK) || ($newstate == $MS_WRDCT) ||
        ##                   (($newstate == $MS_BREAK) && ! [bus iCYCLE3])}]

        if {($state == $MS_FETCH) && (($rdata & 07403) == 07402)} {
            set sbhalted 1
            set haltwhy "hlt"
        } elseif {$panelhalt && (! $isrunning || ([incr haltdelay] > 20000))} {
            set sbhalted 1
            switch $panelhalt {
                1 { set haltwhy "swsinst/$haltdelay" }
                2 { set haltwhy "swsstep/$haltdelay" }
                3 { set haltwhy "swstop/$haltdelay" }
            }
        }
        if {$isrunning == $sbhalted} {
            set is [expr {$isrunning ? "running" : "halted"}]
            set sb [expr {$sbhalted ? "halted" : "running"}]
            error "processor is $is, should be $sb ($haltwhy oldstate=$state newstate=$newstate)"
        }
    } elseif {$isrunning} {
        error "processor is running, should be halted (oldstate=$state newstate=$newstate)"
    } elseif {$newstate != $state} {
        error "processor new state $newstate but old state $state"
    }
}

;# initiate a dma request
proc startdmarequest {} {
    global dma3cycle dmacainc dmarqst dmawrmem dmawdata dmaaddr dmafield

    set dmarqst   1
    set dma3cycle [randbits 1]
    set dmacainc  [randbits 1]
    set dmawrmem  [randbits 1]
    set dmaaddr   [randbits 12]
    set dmafield  [randbits 3]
    if {$dmawrmem} {
        set dmawdata [randbits 12]
    }
    bus set iBRKRQST 1
    puts -nonewline " <<dmarqst>>"
}

;# call after memorycycle to check for halt conditions
;# returns with processor started back up
;# returns with exception if resuming reset processor state, ie,
;#  ldad/exam/depos resets madr, mbuf, pctr contents
;#  then cont sets to FETCH state
;# cont alone should not reset state, should pick up where it left off
proc checkhalted {} {
    global MS_BREAK MS_DEPOS MS_EXAM MS_EXEC MS_FETCH MS_INTAK MS_WRDCT
    global haltdelay haltwhy panelhalt pctr swdfldpend swifldpend swregpend testcons testxmem
    global acum linc mquo sctr xmem_intdisableduntiljump intdelayed intenabled intrequest
    global xmem_dfld xmem_ifld xmem_ifldafterjump xmem_saveddfld xmem_savedifld
    global ttinten ttkbflag ttprflag ttprfull

    ;# if halted, turn off stop/step switches and press continue
    ;# maybe do some ldad/exam/depos
    if {$haltwhy != ""} {
        puts -nonewline " $haltwhy"
        set haltwhy ""
        set wacked 0
        if {$testcons} {
            swtch set sinst 0 sstep 0 stop 0
            set haltdelay 0
            set panelhalt 0
            set addr [bus oMADR]
            set doldad 1
            while {! [ctrlcflag] && ([randbits 1] == 0)} {
                set sw [expr {$doldad ? 1 : [randbits 2]}]
                switch $sw {
                    1 {
                        ;# ldad - only if all 18 switches have soaked through console board
                        finishline
                        for {set i 0} true {incr i} {
                            set busdf [swtch dfld]
                            set busif [swtch ifld]
                            set busda [swtch reg]
                            if {($busdf == $swdfldpend) && ($busif == $swifldpend) && ($busda == $swregpend)} break
                            if {$i > 200000} {
                                error "timed out waiting for switches to soak in"
                            }
                            runsimstep
                        }
                        startline
                        swtchwait ldad 1            ;# press and hold ldad
                        set xmem_dfld $swdfldpend
                        set xmem_ifld $swifldpend
                        set xmem_ifldafterjump $swifldpend
                        set addr $swregpend         ;# madr should be loaded with swreg contents
                        set pctr $addr              ;# circuit also sets pctr to the address
                        set rdata [randbits 12]     ;# get random value for it to examine
                        puts -nonewline [format "         LDAD  %o%04o / %04o" $xmem_ifld $addr $rdata]
                        swtchwait ldad 0            ;# release ldad
                        waitassert RUN              ;# wait for processor to start an exam cycle
                        memorycycle $MS_EXAM $xmem_ifld $addr $rdata $rdata
                        set haltwhy ""
                        verifybit [bus oRUN] 0 "should be halted after LDAD"
                        set wacked 1                ;# processor no longer doing the instruction
                        set swdfldpend [expr {$testxmem ? [randbits 3] : 0}]
                        set swifldpend [expr {$testxmem ? [randbits 3] : 0}]
                        set swregpend [randbits 12] ;# set up new switches for next time
                        swtch set dfld $swdfldpend ifld $swifldpend reg $swregpend
                        set doldad 0
                    }
                    2 {
                        ;# depos - only if 12 data switches have soaked through console board
                        finishline
                        for {set i 0} true {incr i} {
                            set busda [swtch reg]
                            if {$busda == $swregpend} break
                            if {$i > 200000} {
                                error "timed out waiting for switches to soak in"
                            }
                            runsimstep
                        }
                        startline
                        set busda [swtch reg]
                        if {[bus majst] == $MS_DEPOS} {
                            set addr [expr {($addr + 1) & 07777}]
                            set pctr $addr
                        }
                        swtchwait depos 1
                        set rdata [randbits 12]
                        set wdata $swregpend
                        puts -nonewline [format "         DEPOS %o%04o / %04o <= %04o" $xmem_ifld $addr $rdata $wdata]
                        swtchwait depos 0
                        waitassert RUN
                        memorycycle $MS_DEPOS $xmem_ifld $addr $rdata $wdata
                        set haltwhy ""
                        verifybit [bus oRUN] 0 "should be halted after DEPOS"
                        set wacked 1
                        set swregpend [randbits 12]
                        swtch set reg $swregpend
                    }
                    3 {
                        ;# exam
                        finishline
                        startline
                        if {[bus majst] == $MS_EXAM} {
                            set addr [expr {($addr + 1) & 07777}]
                            set pctr $addr
                        }
                        swtchwait exam 1
                        set rdata [randbits 12]
                        puts -nonewline [format "         EXAM  %o%04o / %04o" $xmem_ifld $addr $rdata]
                        swtchwait exam 0
                        waitassert RUN
                        memorycycle $MS_EXAM $xmem_ifld $addr $rdata $rdata
                        set haltwhy ""
                        verifybit [bus oRUN] 0 "should be halted after EXAM"
                        set wacked 1
                    }
                }
            }
        }
        if {[bus oRUN]} {
            error "should be halted"
        }
        ;# do a START from time-to-time
        ;# only if wacked so we know PC==MA
        set needscont 1
        if {$wacked && ([randbits 4] == 0)} {
            puts -nonewline "  start"
            ;# START with SSTEP will just do the reset without starting
            set sstep [expr {[randbits 2] == 0}]
            if $sstep {
                puts -nonewline "/sstep"
                swtchwait sstep 1
            }
            ;# press START button, it should reset a bunch of things
            swtchwait start 1
            dobusinit
            ;# release START button
            swtchwait start 0
            ;# if SSTEP is on, it should remain halted
            if $sstep {
                for {set i 0} {$i < 100} {incr i} {
                    runsimstep
                    if {[bus oRUN]} {
                        error "started running with start/sstep"
                    }
                }
                swtchwait sstep 0
            }
            set needscont $sstep
        }
        if $needscont {
            puts -nonewline "  cont"
            swtchwait cont 1
            swtchwait cont 0
        }
        waitassert RUN
        if $wacked {
            return -code 47
        }
    }
}

;# process IOP pulse
;# it starts 100nS into TS2 and ends at end of TS3
;# acum and pctr mods are clocked at posedge TP3
proc doioinstr {opcode} {
    global acum intdelayed intenabled intrequest linc panelhalt pctr wfitests
    global xmem_dfld xmem_ifld xmem_savedifld xmem_saveddfld xmem_ifldafterjump
    global xmem_intdisableduntiljump
    global ttkbflag ttkbchar ttinten ttprflag ttprchar ttprfull ttprflag

    ;# it should be sending the accumulator out
    verify12 [bus oACUM] $acum "AC invalid going out during IOP"

    ;# maybe it is an io opcode that some fpga device we have enabled processes
    set acclear 0
    set ioskip  0
    set acbits  0

    ;# - processor.v itself processes these io opcodes
    if {$opcode == 06001} {         ;# ION
        set intdelayed 1
    } elseif {$opcode == 06002} {   ;# IOF
        set intdelayed 0
        set intenabled 0
    } elseif {$opcode == 06004} {
        set acclear [randbits 1]    ;# supply random values
        set ioskip  [randbits 1]
        set acbits [randbits 12]
        bus set iACCLEAR $acclear iIOSKIP $ioskip iINBUS $acbits
    } elseif {$opcode == 06313} {   ;# WFI
        incr wfitests
        ;# should be able to break out of WFI with interrupt request, dma requst, stop switch
        set didsomething 0
        for {set i 0} {! [bus intrqst] && ! [bus brkrqst] && ! [swtch sinst] && ! [swtch sstep]} {incr $didsomething} {
            runsimstep
            if {! $didsomething} {
                set r [randbits 7]
                switch $r {
                    11 {incr didsomething ; bus set iINTRQST 1 ; set intrequest 1 ; puts -nonewline " <<intrqst>>"}
                    22 {incr didsomething ; startdmarequest}
                    33 {incr didsomething ; set panelhalt 1 ; swtch set sinst 1 ; puts -nonewline " <<sinst>>"}
                    44 {incr didsomething ; set panelhalt 2 ; swtch set sstep 1 ; puts -nonewline " <<sstep>>"}
                    55 {incr didsomething ; set panelhalt 3 ; swtch set stop  1 ; puts -nonewline " <<stop>>"}
                }
            }
            if {$i > 30000} {error "timed out doing WFI"}
        }
    } elseif {($opcode & 07770) == 06030} {

        ;# - keyboard opcodes (see pdp8itty.v)
        set r [expr {$opcode & 7}]
        switch $r {
            1 {
                set ioskip $ttkbflag
            }
            2 {
                set acclear 1
                set ttkbflag 0
            }
            4 {
                set acbits $ttkbchar
            }
            5 {
                set ttinten [expr {$acum & 1}]
            }
            6 {
                set acclear 1
                set ttkbflag 0
                set acbits $ttkbchar
            }
        }
    } elseif {($opcode & 07770) == 06040} {

        ;# - printer opcodes (see pdp8itty.v)
        set r [expr {$opcode & 7}]
        switch $r {
            1 {
                set ioskip $ttprflag
            }
            2 {
                set ttprflag 0
            }
            4 {
                set ttprchar $acum
                set ttprfull 1
            }
            5 {
                set ioskip [ttintrq]
            }
            6 {
                set ttprflag 0
                set ttprchar $acum
                set ttprfull 1
            }
        }
    } elseif {($opcode & 07700) == 06200} {

        ;# - memext.v processes these io opcodes (manipulate memory field bits)
        if {! ($opcode & 4)} {
            if {$opcode & 1} {set xmem_dfld [expr {($opcode >> 3) & 7}]}
            if {$opcode & 2} {
                set xmem_ifldafterjump [expr {($opcode >> 3) & 7}]
                set xmem_intdisableduntiljump 1
            }
        } elseif {($opcode & 7) == 4} {
            switch [expr {($opcode >> 3) & 3}] {
                1 {                 ;# 6214
                    set acbits [expr {$xmem_dfld << 3}]
                }
                2 {                 ;# 6224
                    set acbits [expr {$xmem_ifld << 3}]
                }
                3 {                 ;# 6234
                    set acbits [expr {($xmem_savedifld << 3) | $xmem_saveddfld}]
                }
            }
            if {$opcode & 040} {    ;# 6244
                puts -nonewline [format " (ifaj=%o dfld=%o)" $xmem_savedifld $xmem_saveddfld]
                set xmem_dfld          $xmem_saveddfld
                set xmem_ifldafterjump $xmem_savedifld
            }
        }
    } else {

        ;# those are the only I/O instructions we know how to process
        error [format "unknown IO opcode %04o" $opcode]
    }

    puts -nonewline [format " => IOP => %s%04o%s" [expr {$acclear ? "=" : "|"}] $acbits [expr {$ioskip ? "+" : " "}]]

    ;# update our shadow registers
    if {$acclear} {set acum 0}
    if {$ioskip}  {set pctr [expr {($pctr + 1) & 07777}]}
    set acum [expr {$acum | $acbits}]
}

proc ttintrq {} {
    global ttinten ttkbflag ttprflag
    return [expr {$ttinten && ($ttkbflag || $ttprflag)}]
}

;# reset everything for a businit
proc dobusinit {} {
    global acum linc mquo sctr
    global xmem_saveddfld xmem_savedifld xmem_intdisableduntiljump 
    global intdelayed intenabled iINTRQST intrequest 
    global ttinten ttkbflag ttprflag ttprfull

    set acum 0
    set linc 0
    set mquo 0
    set sctr 0
    set xmem_saveddfld 0
    set xmem_savedifld 0
    set xmem_intdisableduntiljump 0
    set intdelayed 0
    set intenabled 0
    bus set iINTRQST 0
    set intrequest 0
    set ttinten  1
    set ttkbflag 0
    set ttprflag 0
    set ttprfull 0
}

;# perform extended arithmetic
proc extendedarithmetic {yreg} {
    global acum linc mquo opcode sctr

    ;# step 1
    if {$opcode & 0200} {set acum 0}                        ;# 0200 CLA - clear accumulator

    ;# step 2
    set mqxx $mquo
    if {$opcode & 0020} {set mquo $acum}                    ;# 0020 MQL - load multiplier quotient from accumulator
    if {$opcode & 0020} {set acum 0}
    if {$opcode & 0040} {set acum [expr {$acum | $sctr}]}   ;# 0040 SCA - step counter load into accumulator
    if {$opcode & 0100} {set acum [expr {$acum | $mqxx}]}   ;# 0100 MQA - multiplier quotient load into accumulator

    ;# step 3
    switch [expr {($opcode >> 1) & 7}] {

        1 {     ;# 7403 SCL - step counter load from memory
            set sctr [expr {037 & ~ $yreg}]
        }

        2 {     ;# 7405 MUY - multiply: Y * MQ + AC => AC,MQ
            set prod [expr {$yreg * $mquo + $acum}]
            set acum [expr {$prod >> 12}]
            set mquo [expr {$prod & 07777}]
            set sctr 0
            set linc 0
        }

        3 {     ;# 7407 DVI - divide: AC,MQ / Y => MQ r AC
            set acmq [expr {($acum << 12) | $mquo}]
            if {$acum >= $yreg} {
                set acum [expr {(($acmq >> 11) - $yreg) & 07777}]
                set mquo [expr {(($acmq << 1) + 1) & 07777}]
                set sctr 21
                set linc 1
            } else {
                set acum [expr {$acmq % $yreg}]
                set mquo [expr {($acmq - $acum) / $yreg}]
                set sctr 0
                set linc 0
            }
        }

        4 {     ;# 7411 NMI - normalize
            set acmq [expr {($acum << 12) | $mquo}]
            for {set sctr 0} {$sctr < 31} {incr sctr} {
                if {$acmq == 000000000} break
                if {$acmq == 060000000} break
                if {($acmq & 060000000) == 040000000} break
                if {($acmq & 060000000) == 020000000} break
                set linc [expr {$acmq >> 23}]
                set acmq [expr {($acmq << 1) & 077777777}]
            }
            set acum [expr {$acmq >> 12}]
            set mquo [expr {$acmq & 07777}]
        }

        5 {     ;# 7413 SHL - shift left
            set acmq [expr {($acum << 12) | $mquo}]
            set acmq [expr {$acmq << (($yreg & 31) + 1)}]
            set linc [expr {($acmq >> 24) & 1}]
            set acum [expr {($acmq >> 12) & 07777}]
            set mquo [expr {$acmq & 07777}]
            set sctr 0
        }

        6 {     ;# 7415 ASR - arithmetic shift right
            set acmq [expr {($acum << 12) | $mquo}]
            set linc [expr {$acmq >> 23}]
            set acmq [expr {($acmq ^ 040000000) - 040000000}]
            set acmq [expr {$acmq >> (($yreg & 31) + 1)}]
            set acum [expr {($acmq >> 12) & 07777}]
            set mquo [expr {$acmq & 07777}]
            set sctr 0
        }

        7 {     ;# 7417 LSR - logical shift right
            set acmq [expr {($acum << 12) | $mquo}]
            set linc 0
            set acmq [expr {$acmq >> (($yreg & 31) + 1)}]
            set acum [expr {$acmq >> 12}]
            set mquo [expr {$acmq & 07777}]
            set sctr 0
        }
    }
}

;# wait up to 10uS for signal to assert
proc waitassert {sig {n 100}} {
    for {set i 0} {! [bus o$sig]} {incr i} {
        if {$i > $n} {error "timed out waiting for $sig asserted"}
        runsimstep
    }
}

;# wait up to 10uS for signal to negate
proc waitnegate {sig {n 100}} {
    for {set i 0} {[bus o$sig]} {incr i} {
        if {$i > $n} {error "timed out waiting for $sig negated"}
        runsimstep
    }
}

proc runsimstep {} {
    global dma3cycle dmacainc dmarqst dmawrmem dmafield

    if {$dmarqst && [bus oBRKGNTO]} {
        bus set iCYCLE3 $dma3cycle iCAINC $dmacainc iBRKWRM $dmawrmem iDMAFLD $dmafield
    } else {
        bus set iCYCLE3 0 iCAINC 0 iBRKWRM 0 iDMAFLD 0
    }

    runstep
}

;# maybe request interrupt
;# processor samples it at TP3
proc requestint {state rdata} {
    global intenabled intrequest wfitests
    global MS_FETCH

    if {($wfitests & 4) && ! $intrequest && (($state != $MS_FETCH) || (($rdata & 07403) != 07402))} {
        set intrequest [expr {[randbits 10] == 0}]
        if {$intrequest} {
            puts -nonewline [format "  <<intreq=1 intena=%d>> " $intenabled]
            bus set iINTRQST 1
        }
    }
}

;# compute if a Group 2 instruction would skip
proc g2skip {opcode} {
    global acum linc

    set skip 0
    if {($opcode & 0100) && ($acum & 04000)} {set skip 1}                   ;# SMA
    if {($opcode & 0040) && ($acum ==    0)} {set skip 1}                   ;# SZA
    if {($opcode & 0020) &&           $linc} {set skip 1}                   ;# SNL
    if  {$opcode & 0010}                     {set skip [expr {$skip ^ 1}]}  ;# reverse
    return $skip
}

;# see if actual matches expected
;# if not, print error message then abort
proc verify32 {actual expect msg} {
    set a [expr {$actual & 0xFFFFFFFF}]
    set x [expr {$expect & 0xFFFFFFFF}]
    if {$a != $x} {
        error [format "%s, is %08X should be %08X" $msg $a $x]
    }
}
proc verify15 {actual expect msg} {
    if {$actual != $expect} {
        error [format "%s, is %05o should be %05o" $msg $actual $expect]
    }
}
proc verify12 {actual expect msg} {
    if {$actual != $expect} {
        error [format "%s, is %04o should be %04o" $msg $actual $expect]
    }
}
proc verifybit {actual expect msg} {
    if {$actual != $expect} {
        error [format "%s, is %o should be %o" $msg $actual $expect]
    }
}
