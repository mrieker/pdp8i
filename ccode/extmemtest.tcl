
# test zynq.v externmem by writing to it then reading back

# takes 3 sec running on zynq
#   ./z8ipanel -sim extmemtest.tcl

# takes lt 10 sec running with verizynq.x86_64 on a pc
#   ./verizynq.x86_64 &
#   ./z8ipanel -sim extmemtest.tcl

pin set fpgamemen 1
for {set i 0} {$i < 30000} {incr i} {
    set addr [expr {$i + 123}]
    set data [expr {($i + 234) & 4095}]
    pin set extmemaddr $addr extmemwdat $data extmemwrit 1
    if {[pin extmemwrit] && [pin extmemwrit]} {error "extmem write timed out"}
}
set errors 0
for {set i 0} {$i < 30000} {incr i} {
    set addr [expr {$i + 123}]
    set data [expr {($i + 234) & 4095}]
    pin set extmemaddr $addr extmemread 1
    if {[pin extmemread] && [pin extmemread]} {error "extmem read timed out"}
    set got [pin extmemrdat]
    if {$got != $data} {error [format "extmem %d read %d, should be %d" $addr $got $data]}
}
puts success
