
# run doubleroll on zynq with real or simulated PDP-8/I

exec -ignorestderr make doubleroll.bin
hardreset
set startaddr [loadbinptr doubleroll.bin]
setsw sr $startaddr
domemcyc ldad
setsw sr 0140
flicksw start
