
;# random instruction test for simulator
;#  $ ./verimain.x86_64
;#  > source simtest.tcl
;#  > simtest

set acum         0
set brkrequest   0
set dma3cycle    0
set dmaaddr      0
set dmacainc     0
set dmawrmem     0
set dmafield     0
set dmawdata     0
set fullreal     0
set halfreal     0
set intdelayed   0
set intenabled   0
set intrequest   0
set latsinst     0
set latsstep     0
set latstop      0
set linc         0
set memcycwcover 0
set mulq         0
set opcode       0
set perclock     0
set pctr         0
set sctr         0

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

set testexar 0  ;# test extended arithmetic
set testxmem 0  ;# test extended memory
set runquiet 1  ;# tell runstep command to keep quiet

proc simtest {} {
    global acum
    global brkrequest
    global dma3cycle
    global dmaaddr
    global dmacainc
    global dmawrmem
    global dmafield
    global dmawdata
    global fullreal
    global halfreal
    global instrno
    global intdelayed
    global intenabled
    global intrequest
    global latsinst
    global latsstep
    global latstop
    global linc
    global memcycwcover
    global mulq
    global opcode
    global perclock
    global pctr
    global sctr
    global startclockno
    global swregpend
    global testexar
    global testxmem
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

    ;# reset then start processor
    hardreset
    startat 0
    waitassert TS1
    verify12 [bus oMADR] 0 "bad start PC"
    set acum [bus oACUM]
    set linc [bus oLINK]

    ;# run random instructions, verifying the cycles
    set instrno 0
    set lastopc -1

    while true {
        set ercode [catch {

            ;# once through this loop per instruction, dma transfer or interrupt acknowledge
            ;# processor should be at beginning of TS1 in FETCH, WDCNT, BREAK or INTAK cycle

            ;# occasionally flip switches for OSR testing
            if {$instrno % 1024 == 0} {
                set swregpend [randbits 12]
                swtch set reg $swregpend ;### sinst [randbits 1] sstep [randbits 1] stop [randbits 1]
            }

            startline

            set effaddr 0
            set randsr  0
            set execst $MS_EXEC

            ;# maybe do a dma cycle
            if {$brkrequest} {

                puts -nonewline [format "DMA %d-cycle" [expr {($dma3cycle ? 3 : 1)}]]
                if {$dma3cycle} {

                    ;# WC state reads wordcount from dmaaddr, increments it and writes it back
                    ;# make wordcount overflow somewhat common for testing
                    set oldwordcount [randbits 12]
                    if {$oldwordcount & 04000} {set oldwordcount [expr {$oldwordcount | 07770}]}
                    set newwordcount [expr {($oldwordcount + 1) & 07777}]
                    puts -nonewline [format "  WC:%04o / %04o => %04o" $dmaaddr $oldwordcount $newwordcount]
                    memorycycle $MS_WRDCT 0 $dmaaddr $oldwordcount $newwordcount
                    checkhalted

                    set wcshouldover [expr {$newwordcount == 0}]
                    verifybit $memcycwcover $wcshouldover "BWC OVERFLOW mismatch"

                    ;# CA state reads pointer from dmaaddr + 1, increments it and writes it back
                    ;# then we use the incremented pointer for the transfer address
                    set dmaaddr [expr {($dmaaddr + 1) & 07777}]
                    set oldcuraddr [randbits 12]
                    set newcuraddr [expr {($oldcuraddr + $dmacainc) & 07777}]
                    puts -nonewline [format "  CA:%04o / %04o => %04o" $dmaaddr $oldcuraddr $newcuraddr]
                    memorycycle $MS_CURAD 0 $dmaaddr $oldcuraddr $newcuraddr
                    checkhalted
                    set dmaaddr $newcuraddr
                }

                ;# transfer word at address dmafield:dmaaddr
                set dmardata [randbits 12]                  ;# random value that will be sent to processor as content of memory location dmafield:dmaaddr
                if {! $dmawrmem} {set dmawdata $dmardata}   ;# if writing, write will be value written to CM_DATA; if reading, write will be same as dmardata

                puts -nonewline [format "  BRK:%o%04o / %04o => %04o" $dmafield $dmaaddr $dmardata $dmawdata]
                memorycycle $MS_BREAK $dmafield $dmaaddr $dmardata $dmawdata
                checkhalted
            } else {

                ;# maybe interrupt request is next
                set datafield $xmem_ifld
                if {$intrequest && ! $xmem_intdisableduntiljump && $intenabled} {
                    puts -nonewline "interrupt acknowledge"

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

                    ;# stop when processor is ready to fetch
                    if [ctrlcflag] break

                    ;# delayed ION active now that we are about to do a fetch
                    set intenabled $intdelayed

                    ;# send random opcode
                    ;# for IOs, only allow processor (600x) and xmem (62xx)
                    while true {
                        set opcode [randbits 12]
                        if {($opcode & 06000) != 06000} break       ;# and,tad,isz,dca,jms,jmp
                        if {$opcode == 06001} break                 ;# ION
                        if {$opcode == 06002} break                 ;# IOF
                        if {$opcode == 06004} break                 ;# used to test skip/acclr
                        if {$testxmem && ($lastopc != 06001)} {     ;# don't do memext opcodes if instruction after ION
                            if {($opcode & 07704) == 06200} break
                            if {($opcode & 07707) == 06204} break
                        }
                        if {($opcode & 07400) == 07000} {           ;# group 1
                            ##if {($opcode & 016) == 002} continue    ;# bsw
                            if {($opcode & 014) == 014} continue    ;# 6,7
                            break
                        }
                        if {($opcode & 07401) == 07400} {           ;# group 2
                            set opcode [expr {$opcode & 07775}]     ;# don't do HLT
                            set swregsent [bus swreg]
                            if {$swregsent != $swregpend} {         ;# see if processor has absorbed switches
                                set opcode [expr {$opcode & 07773}] ;# if not, don't do OSR
                            }
                            break
                        }
                        if {$testexar && (($opcode & 07401) == 07401)} break  ;# group 3 (extended arithmetic)
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
                        checkhalted
                        set xmem_intdisableduntiljump 0
                        set xmem_ifld $xmem_ifldafterjump
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
                            bus set iACCLEAR 0 iINBUS 0 iLNKTOG 0
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
                checkhalted
            }

        } errmsg]

        ;# get 0 if it worked normally
        ;# get 47 if halted and did ldad/dep/exam
        if {($ercode != 0) && ($ercode != 47)} {
            return -code $ercode "$errmsg $::errorInfo"
        }

        finishline

        ;# the accumulator and link should be up to date
        verifybit [bus oTS1]  1     "TS1 mismatch at end of instruction"
        verify12  [bus pctr]  $pctr "PC mismatch at end of instruction"
        verify12  [bus oACUM] $acum "AC mismatch at end of instruction"
        verifybit [bus oLINK] $linc "LINK mismatch at end of instruction"
        verify12  [bus mulq]  $mulq "MQ mismatch at end of instruction"
        verify12  [bus sctr]  $sctr "SC mismatch at end of instruction"
    }

    puts "stopping for control-C"
}

proc startline {} {
    global acum instrno linc mulq pctr sctr startclockno xmem_ifld

    puts -nonewline [format "%10u : L.AC=%o.%04o MQ=%04o PC=%o%04o SC=%02o : " \
        [incr instrno] $linc $acum $mulq $xmem_ifld $pctr $sctr]

    set startclockno [clk 0]
}

;# print how many cycles it took (each clock is 100nS)
proc finishline {} {
    global startclockno
    set clocks [expr {[clk 0] - $startclockno}]
    puts [format "  (%u.%u uS)" [expr {$clocks / 10}] [expr {$clocks % 10}]]
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
    global dmawrmem dmawdata memcycwcover opcode
    global MS_BREAK MS_DEPOS MS_EXAM MS_EXEC MS_FETCH MS_INTAK MS_WRDCT
    global haltwhy latsinst latsstep latstop

    ;# clock until we see TS1
    waitassert TS1

    ;# should now be fully transitioned to the major state
    verify12 [bus majst] $state "bad state at start of mem cycle"

    ;# cpu should be outputting address we expect
    set actaddr [expr {([bus memfield] << 12) | [bus oMADR]}]
    set expaddr [expr {($field << 12) | $addr}]
    verify15 $actaddr $expaddr "XMA bad at beginning of $state cycle"

    ;# write the read data to the given address so cpu can read it
    mem $expaddr $rdata

    ;# end of TS1 means it finished reading that memory location into MB
    waitnegate TS1

    ;# MB should now have the value we wrote to the memory location
    verify12 [bus oMBUF] $rdata "MB during read"

    ;# if doing a previously requested DMA cycle that writes to memory,
    ;# output the data to be written during TS2
    ;# processor should pick it up at posedge TP2
    if {($state == $MS_BREAK) && $dmawrmem} {
        bus set iINBUS $dmawdata
    }

    requestdmaorint $state $rdata

    ;# maybe perform extended arithmetic
    if {(($state == $MS_FETCH) && (($opcode & 07407) == 07401)) ||
        (($state == $MS_EXEC)  && (($opcode & 07401) == 07401))} {
        extendedarithmetic $rdata
    }

    ;# wait for it to enter TS3, meanwhile cpu should possibly be modifying
    ;# the value and sending the value (modified or not) back to the memory
    waitassert TS3

    ;# maybe perform i/o
    set doesio [expr {($state == $MS_FETCH) && (($opcode & 07000) == 06000)}]
    verifybit [bus oIOP] $doesio "IOP during IO instruction"
    if $doesio {
        doioinstr $rdata
    }

    ;# beginning of TS3, MB should now have the possibly modified value
    verify12 [bus oMBUF] $wdata "MB during writeback"

    ;# BWC_OVERFLOW is valid
    ;# - clocked with TP2 (vol 2, p5 D-5)
    ;# - cleared with TP3
    set memcycwcover [bus oBWCOV]

    ;# wait for TP3 asserted then negated indicating value written to memory
    ;# also clocks in any io instruction result
    ;# and clocks in the step/stop switches
    for {set i 0} true {incr i} {
        set latsinst [bus swsinst]
        set latsstep [bus swsstep]
        set latstop  [bus swstop]
        if {[bus oTP3]} break
        if {$i > 100} {error "timed out waiting for TP3 asserted"}
        runstep
    }
    waitnegate TP3

    ;# clear any bits being output by io instruction
    if $doesio {
        verifybit [bus oIOP] 0 "IOP after IO instruction"
        bus set iACCLEAR 0 iIOSKIP 0 iINBUS 0 iLNKTOG 0
    }
    if {($state == $MS_BREAK) && $dmawrmem} {
        bus set iINBUS 0
    }

    ;# verify the memory contents
    verify12 [mem $expaddr] $wdata [format "address %05o mismatch" $expaddr]

    ;# step to end of cycle
    waitassert TP4
    waitnegate TP4

    ;# check for halted/running
    set isrunning [bus oRUN]
    set newstate [bus majst]
    set sbhalted 0
    set haltwhy ""
    if {($state != $MS_DEPOS) && ($state != $MS_EXAM)} {
        if {$latsstep} {
            set sbhalted 1
            set haltwhy "sstep"
        } elseif {$latstop} {
            set sbhalted 1
            set haltwhy "stop"
        } elseif {($state == $MS_FETCH) && (($rdata & 07403) == 07402)} {
            set sbhalted 1
            set haltwhy "hlt"
        } elseif {$latsinst && (($newstate == $MS_FETCH) || ($newstate == $MS_INTAK) || ($newstate == $MS_WRDCT) || (($newstate == $MS_BREAK) && ! [bus i3CYCLE]))} {
            set sbhalted 1
            set haltwhy "sinst"
        }
        if {$isrunning == $sbhalted} {
            set is [expr {$isrunning ? "running" : "halted"}]
            set sb [expr {$sbhalted ? "halted" : "running"}]
            error "processor is $is, should be $sb ($haltwhy sinst=$latsinst sstep=$latsstep stop=$latstop oldstate=$state newstate=$newstate)"
        }
    } elseif {$isrunning} {
        error "processor is running, should be halted (oldstate=$state newstate=$newstate)"
    } elseif {$newstate != $state} {
        error "processor new state $newstate but old state $state"
    }
}

proc checkhalted {} {
    global MS_BREAK MS_DEPOS MS_EXAM MS_EXEC MS_FETCH MS_INTAK MS_WRDCT
    global haltwhy latsinst latsstep latstop
    global acum instrno linc mulq pctr sctr swregpend xmem_ifld

    ;# if halted, turn off stop/step switches and press continue
    ;# maybe do some ldad/exam/depos
    if {$haltwhy != ""} {
        puts -nonewline " $haltwhy"
        swtch set sinst 0 sstep 0 stop 0
        set addr [bus oMADR]
        set wacked 0
        while {[randbits 1] == 2} {
            set sw [randbits 2]
            switch $sw {
                1 {
                    if {[bus swreg] == $swregpend} {
                        finishline
                        startline
                        swtch set ldad 1            ;# press and hold ldad
                        runloop 2000                ;# let it soak in good
                        set addr $swregpend         ;# madr should be loaded with swreg contents
                        set rdata [randbits 12]     ;# get random value for it to examine
                        puts -nonewline [format "LDAD  %o%04o / %04o" $xmem_ifld $addr $rdata]
                        set swregpend [randbits 12] ;# flip switches to different random value and release ldad
                        swtch set ldad 0 reg $swregpend
                        waitassert RUN 500          ;# wait for processor to start an exam cycle
                        memorycycle $MS_EXAM $xmem_ifld $addr $rdata $rdata
                        verifybit [bus oRUN] 0 "should be halted after LDAD"
                        set wacked 1
                    }
                }
                2 {
                    if {[bus swreg] == $swregpend} {
                        finishline
                        startline
                        if {[bus majst] == $MS_DEPOS} {set addr [expr {($addr + 1) & 07777}]}
                        swtch set depos 1
                        runloop 2000
                        set rdata [randbits 12]
                        set wdata $swregpend
                        puts -nonewline [format "DEPOS %o%04o / %04o <= %04o" $xmem_ifld $addr $rdata $wdata]
                        set swregpend [randbits 12]
                        swtch set depos 0 reg $swregpend
                        waitassert RUN 500
                        memorycycle $MS_DEPOS $xmem_ifld $addr $rdata $wdata
                        verifybit [bus oRUN] 0 "should be halted after DEPOS"
                        set wacked 1
                    }
                }
                3 {
                    finishline
                    startline
                    if {[bus majst] == $MS_EXAM} {set addr [expr {($addr + 1) & 07777}]}
                    swtch set exam 1
                    runloop 2000
                    set rdata [randbits 12]
                    puts -nonewline [format "EXAM  %o%04o / %04o" $xmem_ifld $addr $rdata]
                    swtch set exam 0
                    waitassert RUN 500
                    memorycycle $MS_EXAM $xmem_ifld $addr $rdata $rdata
                    verifybit [bus oRUN] 0 "should be halted after EXAM"
                    set wacked 1
                }
            }
        }
        puts -nonewline " cont"
        swtch set cont 1
        runloop 2000
        swtch set cont 0
        waitassert RUN 500
        if $wacked {
            set pctr $addr
            return -code 47
        }
    }
}

;# process IOP pulse
;# it starts 100nS into TS2 and ends at end of TS3
;# acum and pctr mods are clocked at posedge TP3
proc doioinstr {opcode} {
    global acum intdelayed intenabled linc pctr
    global xmem_dfld xmem_ifld xmem_savedifld xmem_saveddfld xmem_ifldafterjump
    global xmem_intdisableduntiljump

    ;# it should be sending the accumulator out
    verify12 [bus oACUM] $acum "AC invalid going out during IOP"

    ;# maybe it is an io opcode that some fpga device we have enabled processes
    set acclear 0
    set ioskip  0
    set acbits  0
    set lnktog  0

    ;# - processor.v itself processes these io opcodes
    if {$opcode == 06001} {
        set intdelayed 1
    } elseif {$opcode == 06002} {
        set intdelayed 0
        set intenabled 0
    } elseif {$opcode == 06004} {
        set acclear [randbits 1]    ;# supply random values
        set ioskip  [randbits 1]
        set acbits [randbits 12]
        bus set iACCLEAR $acclear iIOSKIP $ioskip iINBUS $acbits iLNKTOG $lnktog
    } elseif {($opcode & 07700) == 06200} {

        ;# - memext.v processes these io opcodes (manipulate memory field bits)
        if {! ($opcode & 4)} {
            if {$opcode & 1} {set xmem_dfld [expr {($opcode >> 3) & 7}]}
            if {$opcode & 2} {
                set xmem_ifldafterjump [expr {($opcode >> 3) & 7}]
                set xmem_intdisableduntiljump 1
            }
        } elseif {($opcode & 7) == 4} {
            switch [expr {($opcode >> 3) & 7}] {
                1 {             ;# 6214
                    set acbits [expr {$xmem_dfld << 3}]
                }
                2 {             ;# 6224
                    set acbits [expr {$xmem_ifld << 3}]
                }
                3 {             ;# 6234
                    set acbits [expr {($xmem_savedifld << 3) | $xmem_saveddfld}]
                }
                4 {             ;# 6244
                    puts -nonewline [format " (ifaj=%o dfld=%o)" $xmem_savedifld $xmem_saveddfld]
                    set xmem_dfld          $xmem_saveddfld
                    set xmem_ifldafterjump $xmem_savedifld
                }
            }
        }
    } else {

        ;# those are the only I/O instructions we know how to process
        error [format "unknown IO opcode %04o" $opcode]
    }

    puts -nonewline [format " => IOP => %s%s%04o%s" [expr {$lnktog ? "^" : " "}] [expr {$acclear ? "=" : "|"}] $acbits [expr {$ioskip ? "+" : " "}]]

    ;# update our shadow registers
    if {$acclear} {set acum 0}
    if {$ioskip}  {set pctr [expr {($pctr + 1) & 07777}]}
    set linc [expr {$linc ^ $lnktog}]
    set acum [expr {$acum | $acbits}]
}

;# perform extended arithmetic
proc extendedarithmetic {yreg} {
    global acum linc mulq opcode sctr

    ;# step 1
    if {$opcode & 0200} {set acum 0}                        ;# 0200 CLA - clear accumulator

    ;# step 2
    set mqxx $mulq
    if {$opcode & 0020} {set mulq $acum}                    ;# 0020 MQL - load multiplier quotient from accumulator
    if {$opcode & 0020} {set acum 0}
    if {$opcode & 0040} {set acum [expr {$acum | $sctr}]}   ;# 0040 SCA - step counter load into accumulator
    if {$opcode & 0100} {set acum [expr {$acum | $mqxx}]}   ;# 0100 MQA - multiplier quotient load into accumulator

    ;# step 3
    switch [expr {($opcode >> 1) & 7}] {

        1 {     ;# 7403 SCL - step counter load from memory
            set sctr [expr {037 & ~ $yreg}]
        }

        2 {     ;# 7405 MUY - multiply: Y * MQ + AC => AC,MQ
            set prod [expr {$yreg * $mulq + $acum}]
            set acum [expr {$prod >> 12}]
            set mulq [expr {$prod & 07777}]
            set linc 0
        }

        3 {     ;# 7407 DVI - divide: AC,MQ / Y => MQ r AC
            if {$acum >= $yreg} {
                set linc 1
            } else {
                set acmq [expr {($acum << 12) | $mulq}]
                set acum [expr {$acmq % $yreg}]
                set mulq [expr {($acmq - $acum) / $yreg}]
                set linc 0
            }
        }

        4 {     ;# 7411 NMI - normalize
            set acmq [expr {($acum << 12) | $mulq}]
            for {set sctr 0} {$sctr < 31} {incr sctr} {
                if {$acmq == 000000000} break
                if {$acmq == 060000000} break
                if {($acmq & 060000000) == 040000000} break
                if {($acmq & 060000000) == 020000000} break
                set linc [expr {$acmq >> 23}]
                set acmq [expr {($acmq << 1) & 077777777}]
            }
            set acum [expr {$acmq >> 12}]
            set mulq [expr {$acmq & 07777}]
        }

        5 {     ;# 7413 SHL - shift left
            set acmq [expr {($acum << 12) | $mulq}]
            set acmq [expr {$acmq << (($yreg & 31) + 1)}]
            set linc [expr {($acmq >> 24) & 1}]
            set acum [expr {($acmq >> 12) & 07777}]
            set mulq [expr {$acmq & 07777}]
        }

        6 {     ;# 7415 ASR - arithmetic shift right
            set acmq [expr {($acum << 12) | $mulq}]
            set linc [expr {$acmq >> 23}]
            set acmq [expr {($acmq ^ 040000000) - 040000000}]
            set acmq [expr {$acmq >> (($yreg & 31) + 1)}]
            set acum [expr {($acmq >> 12) & 07777}]
            set mulq [expr {$acmq & 07777}]
        }

        7 {     ;# 7417 LSR - logical shift right
            set acmq [expr {($acum << 12) | $mulq}]
            set linc 0
            set acmq [expr {$acmq >> (($yreg & 31) + 1)}]
            set acum [expr {$acmq >> 12}]
            set mulq [expr {$acmq & 07777}]
        }
    }
}

;# wait up to 10uS for signal to assert
proc waitassert {sig {n 100}} {
    for {set i 0} {! [bus o$sig]} {incr i} {
        if {$i > $n} {error "timed out waiting for $sig asserted"}
        runstep
    }
}

;# wait up to 10uS for signal to negate
proc waitnegate {sig {n 100}} {
    for {set i 0} {[bus o$sig]} {incr i} {
        if {$i > $n} {error "timed out waiting for $sig negated"}
        runstep
    }
}

;# maybe request dma or interrupt
;# processor samples it at end of TS3
proc requestdmaorint {state rdata} {
    global brkrequest dmafield dmaaddr dmawrmem dmawdata dma3cycle dmacainc intenabled intrequest
    global MS_FETCH MS_WRDCT MS_CURAD MS_BREAK

    if {($state == $MS_WRDCT) || ($state == $MS_CURAD) || ($state == $MS_BREAK)} {
        set brkrequest 0
    } elseif {! $brkrequest} {
        set brkrequest [expr {[randbits 8] == 0}]
        if {$brkrequest} {
            set dmafield  [randbits 3]
            set dmaaddr   [randbits 12]
            set dmawrmem  [randbits 1]          ;# 0=read memory; 1=write memory
            set dmawdata  [randbits 12]
            set dma3cycle [expr {[randbits 2] == 0}]
            set dmacainc  [expr {$dma3cycle && [randbits 1]}]
            puts -nonewline [format "  <<brkreq=1 3cycle=%o addr=%o%04o" $dma3cycle $dmafield $dmaaddr]
            if {$dmawrmem} {puts -nonewline [format " wdata=%04o" $dmawdata]}
            puts -nonewline ">> "
            bus set iBRKWRM $dmawrmem iDMAADDR [expr {($dmafield << 12) | $dmaaddr}] \
                i3CYCLE $dma3cycle iCAINC $dmacainc iBRKRQST 1
        }
    }
    if {! $brkrequest} {bus set iBRKRQST 0}
    if {! $intrequest && (($state != $MS_FETCH) || (($rdata & 07403) != 07402))} {
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
