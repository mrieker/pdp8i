puts ""
puts "d01b: instruction test 1"

;# load program
loadbin ../../pdp8i/alltapes/maindec-8i-d01b-pb.bin

;# program starts at 0144, halts at 0146 with ac=0000
puts "d01b: starting program"
swtchwait reg 00144
swtchwait ldad 1
swtchwait ldad 0
swtchwait reg 07777
swtchwait start 1
swtchwait start 0
waitrun
puts "d01b: waiting for halt at 0146"
for {set i 0} {[bus oRUN] || ([bus oMADR] != 0147)} {incr i} {
    if {$i > 100} {
        puts "d01b: failed to halt at 0146"
        exit 1
    }
    runstep
}
if {[bus oACUM] != 0} {
    puts "d01b: failed to halt at 0146 with 0000 in accumulator"
    exit 1
}
swtchwait cont 1
swtchwait cont 0
waitrun

;# then program runs forever outputting a BEL every second
puts "d01b: waiting for 3 bells, should be about 15 minutes"
set nbells 0
for {set i 0} {[bus oRUN] && ($i < 60000000)} {incr i} {
    runstep
    set ch [getttypr]
    if {$ch < 0} continue
    if {$ch != 135} {
        puts "d01b: ignoring unexpected output char $ch"
    } else {
        puts [format "%*sDING!" $nbells ""]
        incr nbells
        if {$nbells > 2} {
            puts "SUCCESS!"
            return
        }
    }
}
puts "d01b: took too long for 3 bells"
puts [dumpit]
exit 1
