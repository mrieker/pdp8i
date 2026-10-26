;# read a char that the pdp is printing and display it to our stdout
proc readwithecho {} {
    set repch [readttychartimed 1000]
    if {$repch == ""} {
        error "timed out reading prompt"
    }
    puts -nonewline $repch
    flush stdout
    return $repch
}

;# main test loop
set sa [loadbinptr mul36.bin]
startat $sa
for {set n 0} {![ctrlcflag]} {incr n} {

    ;# print test number then wait for mul36.pal '>' prompt char
    puts -nonewline [format "%9u  " $n]
    while true {
        set repch [readwithecho]
        if {$repch == ""} {
            error "timed out reading prompt"
        }
        if {$repch == ">"} break
    }

    ;# generate random test case then send numbers to mul36.pal
    set rand1hi [randbits 18]
    set rand1lo [randbits 18]
    set rand2hi [randbits 18]
    set rand2lo [randbits 18]
    set probstr [format "%06o%06o*%06o%06o=" $rand1hi $rand1lo $rand2hi $rand2lo]
    set problen [string length $probstr]
    for {set i 0} {$i < $problen} {incr i} {
        set ch [string index $probstr $i]
        sendchartottykb $ch
        set ec [readwithecho]
        if {$ec != $ch} {
            error "char [escapechr $ch] echoed as [escapechr $ch]"
        }
    }

    ;# read reply that mul36.pal prints to the tty
    set reply ""
    while true {
        set repch [readwithecho]
        if {$repch == "\r"} continue
        if {$repch == "\n"} break
        if {($repch < "0") || ($repch > "7")} {
            error "bad reply char [escapechr $repch]"
        }
        append reply $repch
    }

    ;# compute 72-bit product
    set prod22bin [expr {$rand1lo * $rand2lo}]
    set prod21bin [expr {$rand1lo * $rand2hi}]
    set prod12bin [expr {$rand1hi * $rand2lo}]
    set prod11bin [expr {$rand1hi * $rand2hi}]

    set prod4bin [expr {$prod22bin & 0777777}]
    set prod3bin [expr {($prod22bin >> 18) + $prod21bin + $prod12bin}]
    set prod2bin [expr {($prod3bin >> 18) + $prod11bin}]
    set prod1bin [expr {$prod2bin >> 18}]

    set prod3bin [expr {$prod3bin & 0777777}]
    set prod2bin [expr {$prod2bin & 0777777}]

    set prod [format "%06o%06o%06o%06o" $prod1bin $prod2bin $prod3bin $prod4bin]

    ;# verify product received from mul36.pal with what we calculate
    if {$prod != $reply} {
        error "BAD  expected=$prod received=$reply"
    }
}
