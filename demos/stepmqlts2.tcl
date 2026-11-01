#
# step processor to beginning of TS2 of an MQL
# just about to load MQ from AC
#
#  z8ipanel -real stepmqlts2.tcl
#
pin set clkratm1 9
hardreset
assem 0100 cla cma
assem 0101 mql
assem 0102 jmp 0100
setsw reg 0100
domemcyc ldad
pin set clkratm1 0
pin set fp_ovrstart 1 fp_setstart 1
for {set i 0} {! [ctrlcflag]} {incr i} {
    pin set arm_iclock 1 arm_iclock 0
    if {[pin obusini]} break
    if {$i > 1000000} {error "timed out waiting for busini"}
}
pin set fp_setstart 0
for {set i 0} {! [ctrlcflag]} {incr i} {
    pin set arm_iclock 1 arm_iclock 0
    if {[pin orun]} break
    if {$i > 1000000} {error "timed out waiting for run"}
}
for {set i 0} {! [ctrlcflag]} {incr i} {
    pin set arm_iclock 1 arm_iclock 0
    if {([pin omajst] == 1) && ([pin omadr] == 0101) && [pin ots2]} break
    if {[pin obusini]} break
    if {$i > 1000000} {error "timed out waiting for fetch 0101 ts2"}
}
;# do 'pin set clkratm1 9' to resume clocking
