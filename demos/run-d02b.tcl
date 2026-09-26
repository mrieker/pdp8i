#
#  z8ipanel run-d02b.tcl
#
loadbin ../../pdp8l/alltapes/maindec-8i-d02b-pb.bin
puts "d02b: starting program"
setsw reg 00201
domemcyc ldad
setsw reg 07777
domemcyc start
puts "d02b: <BEL> about every 5 seconds"
exec -ignorestderr $Z8IHOME/z8itty -killit -nokb < /dev/tty > /dev/tty
