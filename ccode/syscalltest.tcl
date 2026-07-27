#
# simple loop to test syscall interface
#  ./z8ipanel -sim syscalltest.tcl
#  ./z8isys.armv7l &
#  ./z8idump  << should show sy1_counter incrementing quickly
#                and armintreq,armintena bit 00000001 toggling quickly
#
assem 0100 iac
assem 0101 iot 06310
assem 0102 ral
assem 0103 iot 06310
assem 0104 jmp 0100
startat 0100
