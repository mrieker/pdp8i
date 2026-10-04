
# run doubleroll on zynq with real or simulated PDP-8/I
#  z8ipanel -real/-sim doubleroll.tcl
#  z8ipanel -status

exec -ignorestderr make doubleroll.bin
hardreset
clearmem
set startaddr [loadbin doubleroll.bin]
setsw reg $startaddr
domemcyc ldad
setsw reg 0140
flicksw start
