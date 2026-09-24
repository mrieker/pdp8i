#
#  determine light row scanning speed
#  vary the ltspeed parameter and print resulting times
#
set i2cspeed [pin fp_i2cspeed]
for {set lsus 100} {! [ctrlcflag]} {incr lsus 100} {
    set ltspeed [expr {($lsus * 100) - 1}]
    if {$ltspeed > 0xFFFFF} break
    pin set fp_ltspeed $ltspeed
    puts "lsus=$lsus ltspeed=$ltspeed i2cspeed=$i2cspeed"
    set beg [pin fp_mcpassno]
    after 1000
    set end [pin fp_mcpassno]
    set passpersec [expr {($end - $beg) & 037777777}]
    set usecperpass [expr {1000000 / $passpersec}]
    set percenton [expr {$lsus * 100.0 / $usecperpass}]
    puts "  passpersec=$passpersec usecperpass=$usecperpass percenton=$percenton"
}
