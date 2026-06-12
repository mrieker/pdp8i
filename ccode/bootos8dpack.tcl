#
#  Boot OS/8 from RK05
#
#    real PDP:  ./z8ipanel -real bootos8dpack.tcl
#    simulator: ./z8ipanel -sim  bootos8dpack.tcl
#
global Z8IHOME
source $Z8IHOME/os8lib.tcl
os8dpackloadandboot
exec -ignorestderr $Z8IHOME/z8itty -cps 960 -killit -upcase < /dev/tty > /dev/tty
flicksw stop
exit
