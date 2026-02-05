
;# random instruction test for simulator
;#  $ ./verimain.x86_64
;#  > source simtest.tcl
;#  > simtest

set acum         0
set brkrequest   0
set dma3cycle    0
set dmaaddr      0
set dmacainc     0
set dmadatain    0
set dmafield     0
set dmawdata     0
set fullreal     0
set halfreal     0
set intdelayed   0
set intenabled   0
set intrequest   0
set linc         0
set memcycwcover 0
set perclock     0
set realmode     0
set pctr         0

set xmem_dfld                 0
set xmem_ifld                 0
set xmem_ifldafterjump        0
set xmem_intdisableduntiljump 0
set xmem_saveddfld            0
set xmem_savedifld            0

set MS_FETCH 1   ;# memory cycle is fetching instruction
set MS_DEFER 2   ;# memory cycle is reading pointer
set MS_EXEC  3   ;# memory cycle is for executing instruction
set MS_WRDCT 4   ;# memory cycle is for incrementing dma word count
set MS_CURAD 5   ;# memory cycle is for reading dma address
set MS_BREAK 6   ;# memory cycle is for dma data word transfer
set MS_INTAK 7   ;# memory cycle is for interrupt acknowledge
set MS_DEPOS 8   ;# memory cycle is for deposit switch
set MS_EXAM  9   ;# memory cycle is for examine switch

set runquiet 1

proc simtest {} {
    global acum
    global brkrequest
    global dma3cycle
    global dmaaddr
    global dmacainc
    global dmadatain
    global dmafield
    global dmawdata
    global fullreal
    global halfreal
    global intdelayed
    global intenabled
    global intrequest
    global linc
    global memcycwcover
    global perclock
    global realmode
    global pctr
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
    for {set i 0} {! [bus oTS1]} {incr i} {
        if {$i > 1000} {error "timed out clocking to TS1"}
        runstep
    }
    verify12 [bus oMADR] 0 "bad start PC"
    set acum [bus oACUM]
    set linc [bus link]

    ;# run random instructions, verifying the cycles
    set contforcesfetch 0
    set lastiszptr -1
    set lastwasisz -1
    set instrno 0

    set TESTOS8ZAP 0

    while true {

        ;# once through this loop per instruction, dma transfer or interrupt acknowledge
        ;# processor should be at beginning of TS1 in FETCH, WDCNT, BREAK or INTAK cycle

        puts -nonewline [format "%10u : L.AC=%o.%04o PC=%o%04o : " [incr instrno] $linc $acum $xmem_ifld $pctr]

        set startclockno [clk 0]

        set effaddr 0
        set opcode  0
        set randsr  0
        set execst $MS_EXEC

        ;# maybe do a dma cycle
        if {$brkrequest && ! $contforcesfetch &&
            (! $realmode || ($dma3cycle ? ! [bus o_SP_CYC_NEXT] :
                                        ! [bus o_BF_ENABLE]))} {

            puts -nonewline [format "DMA %d-cycle" [expr {($dma3cycle ? 3 : 1)}]]
            if {$dma3cycle} {

                ;# WC state reads wordcount from dmaaddr, increments it and writes it back
                ;# make wordcount overflow somewhat common for testing
                set oldwordcount [randbits 12]
                if {$oldwordcount & 04000} {set oldwordcount [expr {$oldwordcount | 07770}]}
                set newwordcount [expr {($oldwordcount + 1) & 07777}]
                puts -nonewline [format "  WC:%04o / %04o => %04o" $dmaaddr $oldwordcount $newwordcount]
                memorycycle $MS_WRDCT 0 $dmaaddr $oldwordcount $newwordcount

                if {! $realmode} {
                    set wcshouldover [expr {$newwordcount == 0}]
                    if {$memcycwcover != $wcshouldover} {
                        error [format "BWC OVERFLOW is %o should be %o" $memcycwcover $wcshouldover]
                    }
                }

                ;# CA state reads pointer from dmaaddr + 1, increments it and writes it back
                ;# then we use the incremented pointer for the transfer address
                set dmaaddr [expr {($dmaaddr + 1) & 07777}]
                set oldcuraddr [randbits 12]
                set newcuraddr [expr {($oldcuraddr + $dmacainc) & 07777}]
                puts -nonewline [format "  CA:%04o / %04o => %04o" $dmaaddr $oldcuraddr $newcuraddr]
                memorycycle $MS_CURAD 0 $dmaaddr $oldcuraddr $newcuraddr
                set dmaaddr $newcuraddr
            }

            ;# transfer word at address dmafield:dmaaddr
            set dmardata [randbits 12]                  ;# random value that will be sent to processor as content of memory location dmafield:dmaaddr
            if {! $dmadatain} {set dmawdata $dmardata}  ;# if writing, write will be value written to CM_DATA; if reading, write will be same as dmardata

            puts -nonewline [format "  BRK:%o%04o / %04o => %04o" $dmafield $dmaaddr $dmardata $dmawdata]
            memorycycle $MS_BREAK $dmafield $dmaaddr $dmardata $dmawdata

            set lastiszptr -1
            set lastwasisz -1
        } else {

            set os8stepbeforefetch -1 ;#???? [expr {($xmemat[3] & XM3_OS8STEP) / XM3_OS8STEP0}]

            ;# maybe interrupt request is next
            set extfetaddr -1
            set datafield $xmem_ifld
            if {$intrequest && ! $xmem_intdisableduntiljump && $intenabled && ! $contforcesfetch &&
                (! $realmode || ! [bus o_LOAD_SF])} {
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

                ;# we are about to do the fetch after the cont switch
                set contforcesfetch 0

                ;# delayed ION active now that we are about to do a fetch
                set intenabled $intdelayed

                ;# send random opcode
                ;# for IOs, only allow processor (600x) and xmem (62xx)
                while true {
                    set opcode [randbits 12]
                    if {($opcode & 07400) == 07400} {
                        set opcode [expr {$opcode & 07770}]     ;# don't do OSR,HLT,Group 3
                    }
                    if {($opcode & 07400) == 07000} {
                        if {($opcode & 016) == 002} continue    ;# bsw
                        if {($opcode & 014) == 014} continue    ;# 6,7
                    }
                    if {($opcode & 07000) != 06000} break
                    if {$opcode == 06001} break
                    if {$opcode == 06002} break
                    if {($opcode & 07704) == 06200} break
                    if {($opcode & 07707) == 06204} break
                }
                puts -nonewline [format "OP=%04o  %s" $opcode [disop $pctr $opcode]]

                ;# set random switch register contents if about to do an OSR instruction
                if {(($opcode & 07401) == 07400) && ($opcode & 0004)} {
                    set randsr [randbits 12]
                    swtch set reg $randsr
                }

                ;# perform fetch memory cycle
                set extfetaddr [expr {($xmem_ifld << 12) | $pctr}]
                if {$TESTOS8ZAP && (($lastwasisz + 1) == (($xmem_ifld << 12) | $pctr)) && ($opcode == (05200 | ($lastwasisz & 00177)))} {
                    ;# pdp8lxmem.v is changing the fetch JMP .-1 to fetch NOP, writeback ISZ value with 0
                    puts -nonewline " os8zapped"
                    memorycyclx $MS_FETCH \
                        $xmem_ifld $pctr \  ;# pdp8lxmem.v reads opcode from usual ifld:pctr
                        $opcode,         \  ;# it gets the the JMP .-1 opcode from memory
                        07000,           \  ;# it sends a NOP to the processor
                        07000,           \  ;# the processor sends a NOP as writeback for the fetch
                        $lastiszptr 0       ;# pdp8lxmem.v writes a zero to the ISZs counter
                    set opcode 07000        ;# process the NOP just like the processor is
                } else {
                    ;# anything else, fetch from ifld/pctr
                    memorycycle $MS_FETCH $xmem_ifld $pctr $opcode $opcode
                }
                set effaddr [expr {(($opcode & 00200) ? ($pctr & 07600) : 0) | ($opcode & 00177)}]
                set pctr [expr {($pctr + 1) & 07777}]

                ;# maybe do a defer cycle
                if {($opcode & 07000) < 06000} {
                    puts -nonewline " ="
                    if {$opcode & 0400} {
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
            set lastiszptr -1
            set lastwasisz -1
            switch [expr {$opcode >> 9}] {

                4 {             ;# jms
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
                    for {set m 1} {$m <= 4} {incr m $m} {
                        if {$opcode & $m} {

                            ;# if -half or -real, the processor is waiting just before TP4 so has already performed the I/O instruction
                            ;#    so we can't wait for the IOPm pulses because they have already gone by
                            ;# for full simulator mode, we manually clock it so will see the IOPm pulses
                            if {! $realmode} {

                                ;# wait for processor to assert IOPm
                                for {set i 0} {! [bus oIOP$m]} {incr i} {
                                    if {$i > 1000} {error [format "timed out waiting for IOP%u asserted" $m]}
                                    runstep
                                }

                                ;# it should be sending the accumulator out
                                verify12 [bus oACUM] $acum "AC invalid going out during IOP"
                            }

                            ;# maybe it is an io opcode that some fpga device we have enabled processes
                            set acclear 0
                            set ioskip  0
                            set acbits  0

                            ;# - pdp8lsim.v itself processes these io opcodes
                            if {$opcode == 06001} {
                                set intdelayed 1
                            } elseif {$opcode == 06002} {
                                set intdelayed 0
                                set intenabled 0
                            } elseif {($opcode & 07700) == 06200} {

                                ;# - pdp8lxmem.v processes these io opcodes (manipulate memory field bits)
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

                            puts -nonewline [format " => IOP%o => %s%s%04o" $m [expr {$acclear ? "C" : " "}] [expr {$ioskip ? "S" : " "}] $acbits]

                            if {! $realmode} {

                                ;# wait for processor to drop IOPm
                                for {set i 0} {[bus oIOP$m]} {incr i} {
                                    if {$i > 1000} {error "timed out waiting for IOP$m negated"}
                                    runstep
                                }

                                ;# clear the random bits so it won't clock them again during nulled-out io pulses
                                bus set iACCLEAR 0 iIOSKIP 0 iINBUS 0
                            }

                            ;# update our shadow registers
                            if {$acclear} {set acum 0}
                            if {$ioskip}  {set pctr [expr {($pctr + 1) & 07777}]}
                            set acum [expr {$acum | $acbits}]
                        }
                    }
                }

                7 {             ;# opr
                    if {! ($opcode & 0400)} {
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
                        if {[g2skip $opcode]} {
                            puts -nonewline " skip"
                            set pctr [expr {($pctr + 1) & 07777}]
                        }
                        if {$opcode & 0200} {set acum 0}
                        if {$opcode & 0004} {set acum [expr {$acum | randsr}]}
                        puts -nonewline [format " => %04o" $acum]
                        if {$opcode & 0002} {
                            for {set i 0} {bus oB_RUN} {incr i} {
                                if {$i > 1000} {error "timed out waiting for RUN negated after HLT instruction"}
                                runstep
                            }
                            puts -nonewline " cont"
                            docont
                            set contforcesfetch 1   ;# cont switch in pdp8lsim.v always does fetch next (no brk, irq, etc)
                            ASSERT [expr {! $realmode}]
                        }
                    }
                }

                default {               ;# and, tad, isz, dca
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

                            ;# if ISZ direct page, save operand 15-bit address and opcode 15-bit address
                            ;# but if last instruction had an exec cycle that read something that looked like an ISZ instruction,
                            ;# ...pdp8lxmem.v won't detect this ISZ so skip this test in that case
                            ;#   TAD xxxx ; last instruction, xxxx contained 2347 so it sets os8step=1 cuz it thinks 2347 might be an ISZ opcode
                            ;#   ISZ yyyy ; this instruction, the fetch doesn't do read/modify+1/write so it knows the 2347 isn't an opcode and sets os8step=0
                            ;#   JMP .-1  ; next instruction, will be processed as normal cuz os8step=0
                            ;# the TAD could be an ISZ in which case we get os8step=2 with the same result
                            ;#   ISZ xxxx ; last instruction, sets os8step=2 cuz it is an ISZ and looking for JMP next
                            ;#   ISZ yyyy ; this instruction, not a JMP so it sets os8step=0
                            ;#   JMP .-1  ; next instruction, will be processed as normal cuz os8step=0
                            ;# in either case, it should successfully zap after JMP .-1 is taken cuz the JMP .-1 leaves os8step=0
                            if {($os8stepbeforefetch == 0) && (($opcode & 07600) == 02200) && (($extfetaddr & 0177) != 0177)} {
                                set lastiszptr [expr {($datafield << 12) | $effaddr}]
                                set lastwasisz $extfetaddr
                            }
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

        if {$realmode} {
            puts ""
        } else {

            ;# step to TS1 so we know everything has been updated
            for {set i 0} {! [bus oTS1]} {incr i} {
                if {$i > 1000} {error "timed out clocking to TS1"}
                runstep
            }

            ;# the accumulator and link should be up to date
            verify12  [bus pctr] $pctr "PC mismatch at end of instruction"
            verify12  [bus oACUM] $acum "AC mismatch at end of instruction"
            verifybit [bus link] $linc "LINK mismatch at end of instruction"

            ;# print how many cycles it took (each clock is 10nS)
            set clocks [expr {[clk 0] - $startclockno}]
            puts [format "  (%u.%02u uS)" [expr {$clocks / 100}] [expr {$clocks % 100}]]
        }
    }

    puts "stopping for control-C"
}

;# do a 'continue' operation
proc docont {} {

    ;# press continue switch
    swtch set cont 1

    ;# clock some cycles to arm the debounce circuit
    runloop 2000

    ;# release continue switch
    swtch set cont 0

    ;# clock until the run flipflop sets
    for {set i 0} {! [bus oB_RUN]} {incr i} {
        if {$i > 1000} {error "timed out waiting for RUN after flicking CONT switch"}
        runstep
    }
}

;# clock through a memory cycle, verifying the address and data
;#  input:
;#   state = "state"
;#   addr  = address it should be accessing
;#   rdata = data to send it for the read
;#   wdata = data it should send for writing
;#   processor could possibly be somewhere near end of previous memory cycle
;#  output:
;#   returns with processor just exited TS3
;#   memcycwcover = processor's oBWCOV at beg of TS3
;#
;# steps through:
;#   TS1 = reading memory location
;#   TS2 = computing any modification to value
;#   TS3 = writing memory location
;# after that:
;#   IOP1,2,4 = only if this was a fetch of an io instruction
;#   TS4 = any post-processing for the cycle
proc memorycycle {state field addr rdata wdata} {
    memorycyclx $state $field $addr $rdata $rdata $wdata [expr {($field << 12) | $addr}] $wdata
}

;# - rdbkdata = data sent to processor as result of read
;# - wtbkdata = data received back from processor
;# - vfywaddr = address in extmem[] to verify the write happened
;# - vfywdata = data that should be at vfywaddr
proc memorycyclx {state field addr rdata rdbkdata wtbkdata vfywaddr vfywdata} {
    global memcycwcover realmode

    if {$realmode} {

        ;# holding just before TP4 of previous cycle

        requestdmaorint $state $rdata

        ;# write the read data to the given address so PDP can read it
        set xaddr [expr {($field << 12) | addr}]
        mem $xaddr $rdata

        ;# let the PDP execute TP4 of the previous cycle up to just before TP4 of this cycle
        for {set i 0} {[bus oTS4]} {incr i} {
            if {$i > 1000} {error "timed out waiting for TS4 to clear"}
            runstep
        }
        for {set i 0} {[bus oTP3 oTS4] != "0 1"} {incr i} {
            if {$i > 1000} {error "timed out waiting for TS4 to set"}
            runstep
        }

        ;# holding just before TP4 of this cycle

        ;# verify the memory contents after writeback
        set vdata [mem $vfywaddr]
        if {$vdata != $vfywdata} {
            error [format "address %05o contained %04o at end of cycle, should be %04o" $vfywaddr $vdata $vfywdata]
        }
    } else {

        ;# clock until we see TS1
        for {set i 0} {! [bus oTS1]} {incr i} {
            if {$i > 1000} {error "timed out waiting for TS1 asserted"}
            runstep
        }

        ;# cpu should be outputting address we expect
        verify15 [expr {([bus memfield] << 12) | [bus oMADR]}] [expr {($field << 12) | $addr}] "XMA bad at beginning of mem cycle"

        ;# should now be fully transitioned to the major state
        verify12 [bus majst] $state "bad state during mem cycle"

        ;# write the read data to the given address so cpu can read it
        set xaddr [expr {($field << 12) | $addr}]
        mem $xaddr $rdata

        ;# end of TS1 means it finished reading that memory location into MB
        for {set i 0} {[bus oTS1]} {incr i} {
            if {$i > 1000} {error "timed out waiting for TS1 negated"}
            runstep
        }

        ;# MB should now have the value we wrote to the memory location
        verify12 [bus oMBUF] $rdbkdata "MB during read"

        requestdmaorint $state $rdata

        ;# wait for it to enter TS3, meanwhile cpu should possibly be modifying
        ;# the value and sending the value (modified or not) back to the memory
        for {set i 0} {! [bus oTS3]} {incr i} {
            if {$i > 1000} {error "timed out waiting for TS3 asserted"}
            runstep
        }

        ;# beginning of TS3, MB should now have the possibly modified value
        verify12 [bus oMBUF] $wtbkdata "MB during writeback"

        ;# BWC_OVERFLOW is valid
        ;# - clocked with TP2 (vol 2, p5 D-5)
        ;# - cleared with TP3
        set memcycwcover [bus oBWCOV]

        ;# wait for TP3 asserted then negated indicating value written to memory
        for {set i 0} {! [bus oTP3]} {incr i} {
            if {$i > 1000} {error "timed out waiting for TP3 asserted"}
            runstep
        }
        for {set i 0} {[bus oTP3]} {incr i} {
            if {$i > 1000} {error "timed out waiting for TP3 negated"}
            runstep
        }

        ;# verify the memory contents
        set vdata [mem $vfywaddr]
        if {$vdata != $vfywdata} {
            error [format "address %05o contained %04o at end of cycle, should be %04o" $vfywaddr $vdata $vfywdata]
        }
    }
}

;# maybe request dma or interrupt
;# processor samples it at end of TS3
proc requestdmaorint {state rdata} {
    global brkrequest dmafield dmaaddr dmadatain dmawdata dma3cycle dmacainc intenabled intrequest
    global MS_FETCH MS_WRDCT MS_CURAD MS_BREAK

    if {($state == $MS_WRDCT) || ($state == $MS_CURAD) || ($state == $MS_BREAK)} {
        set brkrequest 0
    } elseif {! $brkrequest} {
        set brkrequest [expr {[randbits 8] == 0}]
        if {$brkrequest} {
            set dmafield  [randbits 3]
            set dmaaddr   [randbits 12]
            set dmadatain [randbits 1]          ;# 0=read memory; 1=write memory
            set dmawdata  [randbits 12]
            set dma3cycle [expr {[randbits 2] == 0}]
            set dmacainc  [expr {$dma3cycle && [randbits 1]}]
            puts -nonewline [format "  <<brkreq=1 3cycle=%o addr=%o%04o" $dma3cycle $dmafield $dmaaddr]
            if {$dmadatain} {puts -nonewline [format " wdata=%04o" $dmawdata]}
            puts -nonewline ">> "
            bus set iBRKWRM $dmadatain iDMAADDR [expr {($dmafield << 12) | $dmaaddr}] \
                iDMADATA $dmawdata i3CYCLE $dma3cycle iCAINC $dmacainc iBRKRQST 1
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

set randseed 0x123456789ABCDEF
proc randbits {nbits} {
    global randseed

    set randval 0
    while {[incr nbits -1] >= 0} {
        set xnor [expr {~ (($randseed >> 63) ^ ($randseed >> 62) ^ ($randseed >> 60) ^ ($randseed >> 59))}]
        set randseed [expr {($randseed << 1) | ($xnor & 1)}]
        incr randval [expr {$randval + ($randseed & 1)}]
    }
    return $randval
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
