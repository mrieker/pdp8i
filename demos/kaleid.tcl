
# run kaleidoscope on zynq with real or simulated PDP-8/I
#  [vcsize=1024] ./z8ipanel -real kaleid.tcl e|i    real PDP-8/I
#  [vcsize=1024] ./z8ipanel -sim  kaleid.tcl e|i    simulator

set vt [lindex $argv 0]
if {($vt != "e") && ($vt != "i")} {
    puts "bad or missing 'e' or 'i' argument"
    exit 1
}
exec -ignorestderr make kaleid-$vt.bin
set startaddr [loadbinptr kaleid-$vt.bin]
set nowtv [clock microseconds]
set initx [expr {$nowtv % 1000 + 1234}]
set inity [expr {$nowtv / 1000 % 1000 + 2345}]
puts "kaleid: initx=[octal $initx] inity=[octal $inity]"
wrmem 020 $initx
wrmem 021 $inity
setsw reg 0
startat $startaddr
relsw reg
exec -ignorestderr $Z8IHOME/z8ivc8 -killit -pms 120 -size [getenv vcsize 720] $vt
exit
