
# test pdp8itty.v in the verimain directory
#
#  > tttload
#  > tttloop
#      see char in ttprst with a '4' in top digit
#      press ctrl-C
#  > tttrdch
#      prints char value
#  > tttloop
#      see char in ttprst with a '4' in top digit
#      press ctrl-C
#   ...

set runquiet 1

proc tttload {} {
    hardreset
    assem 0100 cla
    assem 0101 tad 0160
    assem 0102 iot 06046    ;# print char
    assem 0103 iot 06041    ;# wait for ready
    assem 0104 jmp 0103
    assem 0105 iac
    assem 0106 and 0161
    assem 0107 sza
    assem 0110 jmp 0102
    assem 0111 jmp 0100
    wrmem 0160 0040
    wrmem 0161 0177
    disas 0100 0111
    startat 0100
}

proc tttstep {} {
    runstep
    puts [format "TS=%o%o%o%o MS=%x IOP=%o PC=%04o MB=%04o AC=%04o ttver=%08X ttkbst=%08X ttprst=%08X" \
        [bus oTS1] [bus oTS2] [bus oTS3] [bus oTS4] [bus majst] [bus oIOP] [bus pctr] [bus oMBUF] [bus oACUM] \
        [bus set armraddr 040 get armrdata] [bus set armraddr 041 get armrdata] [bus set armraddr 042 get armrdata]]
}

proc tttloop {} {
    while {! [ctrlcflag]} {
        tttstep
    }
}

proc tttrdch {} {
    set ch [bus set armraddr 042 get armrdata set armwaddr 042 armwdata 0x80000000 armwrite 1]
    tttstep
    bus set armwrite 0
    return [expr {$ch & 07777}]
}

