
# run doubleroll on zynq with real or simulated PDP-8/I

exec -ignorestderr make doubleroll.bin
hardreset
set startaddr [loadbin doubleroll.bin]
setsw sr 0140
startat $startaddr
exec -ignorestderr ./z8lpanel -status < /dev/tty > /dev/tty
exit
