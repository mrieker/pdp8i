;# compute light/switch scan pass time
proc lightime {} {
    ;# see what pass number we are on now
    set begmcpassno [pin fp_mcpassno]
    ;# wait 10 seconds
    after 10000
    ;# see what pass number we are on now
    set endmcpassno [pin fp_mcpassno]
    ;# compute time per pass
    puts "[expr {($endmcpassno-$begmcpassno)/10.0}] pass/sec"
    puts "[expr {10000000.0/($endmcpassno-$begmcpassno)}] us/pass"
}
