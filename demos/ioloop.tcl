
# test inbus pullups
# looks at pullups on inbus[11:08]
# no pullups needed on inbus[03:00]

# low ac bits don't have pullups so should be on all the time
# high ac bits have pullups so should be off
# - high ac bits will turn on with overclocking cuz pullups not strong enough

# with scope syncd to _IOP, another probe on _TP3 and third probe on _INBUS_11,
# see that _INBUS_11 reaches 4V by the time _TP3 goes low

hardreset

#assem 0100 cla
#assem 0101 iot 06017
#assem 0102 jmp 0100
#assem 0103 jmp 0100

assem 0200 cla
assem 0201 iot 06417 ;# unused io opcode
                     ;# TS1 has 6417 on INBUS
                     ;# pullups needed to get rid of the '1' bits by TP3
assem 0202 nop       ;# in case of ioskip
assem 0203 and 0220  ;# see if pullups failed any top bits
assem 0204 sna
assem 0205 jmp 0201  ;# repeat if no failure
assem 0206 hlt       ;# halt on failure
assem 0207 jmp 0200
wrmem 0220 07400     ;# mask of installed pullups

startat 0200

