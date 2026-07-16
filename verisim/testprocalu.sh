#!/bin/bash
#
#  run simtest, print every 1000 tests
#  if failure, save whole of last 4M output
#
id=$$
mach=`uname -m`
rm -f ~/testprocalu.err.$id ~/testprocalu.out.$id
time ./testprocalu.$mach 2>&1 | ./last16k.$mach 2> ~/testprocalu.err.$id | ./bgrep.$mach 'ntest=*000$' | tee ~/testprocalu.out.$id
echo output: ~/testprocalu.err.$id ~/testprocalu.out.$id
