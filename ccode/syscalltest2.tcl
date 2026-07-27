#
# simple loop to test PION/PIOFF syscall instructions
#  ./z8isys.armv7l &
#  ./z8ipanel -sim syscalltest2.tcl
#
pin set clkratm1 7
pin set arm_iclock 0
hardreset
assem 0200 isz 0240
assem 0201 jmp 0200
assem 0202 dca 0241
assem 0203 isz 0207
assem 0204 tad 0207
assem 0205 and 0242
assem 0206 dca 0207
assem 0207 iot 06310    ;# 6310=PIOFF; 6311=PION
assem 0210 tad 0241
assem 0211 iac
assem 0212 jmp 0200
wrmem 0242 07775
startat 0200
