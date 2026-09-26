#
#  z8ipanel run-d01b.tcl
#
loadbin ../../pdp8l/alltapes/maindec-8i-d01b-pb.bin
puts "d01b: starting program"
setsw reg 00144
domemcyc ldad
setsw reg 07777
domemcyc start
puts "d01b: waiting for halt at 0146"
for {set i 0} {[getlb run] || ([getlb pc] != 0147)} {incr i} {
    if {$i > 10} {
        puts "d01b: failed to halt at 0146"
        puts [dumpit]
        exit 1
    }
    after 100
}
if {[getlb ac] != 0} {
    puts "d01b: failed to halt at 0146 with 0000 in accumulator"
    puts [dumpit]
    exit 1
}
puts "d01b: resuming"
flicksw cont
puts "d01b: <BEL> every second"
exec -ignorestderr $Z8IHOME/z8itty -killit -nokb < /dev/tty > /dev/tty
