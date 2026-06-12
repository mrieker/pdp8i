#
#  Boot OS/8 from DECtape
#    ./z8ipanel bootos8dtape.tcl    ... to run on real pdp
#    ./z8isim bootos8dtape.tcl      ... to run on simulator
#
global Z8IHOME
source $Z8IHOME/os8lib.tcl
os8dtapeloadandboot
exec -ignorestderr $Z8IHOME/z8itty -cps 960 -killit -upcase < /dev/tty > /dev/tty
flicksw stop
exit
