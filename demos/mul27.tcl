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
set sa [loadbinptr mul27.bin]
startat $sa
for {set n 0} {![ctrlcflag]} {incr n} {

    ;# print test number then wait for mul27.pal '>' prompt char
    puts -nonewline [format "%9u  " $n]
    while true {
        set repch [readwithecho]
        if {$repch == ""} {
            error "timed out reading prompt"
        }
        if {$repch == ">"} break
    }

    ;# generate random test case then send numbers to mul27.pal
    set rand1 [randbits 27]
    set rand2 [randbits 27]
    set probstr [format "%o*%o=" $rand1 $rand2]
    set problen [string length $probstr]
    for {set i 0} {$i < $problen} {incr i} {
        set ch [string index $probstr $i]
        sendchartottykb $ch
        set ec [readwithecho]
        if {$ch == ""} {
            error "timed out reading echo"
        }
        if {$ec != $ch} {
            error "char [escapechr $ch] echoed as [escapechr $ch]"
        }
    }

    ;# read reply that mul27.pal prints to the tty
    set reply 0
    while true {
        set repch [readwithecho]
        if {$repch == ""} {
            error "timed out reading reply"
        }
        if {$repch == "\r"} continue
        if {$repch == "\n"} break
        if {($repch < "0") || ($repch > "7")} {
            error "bad reply char [escapechr $repch]"
        }
        set reply [expr {$reply * 8 + [chartoint $repch] - 48}]
    }

    ;# verify product received from mul27.pal with what we calculate
    set prod [expr {$rand1 * $rand2}]
    if {$prod != $reply} {
        error [format "BAD  expected=%024o received=%024o" $prod $reply]
    }
}
