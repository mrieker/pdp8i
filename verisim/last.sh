#!/bin/bash
#
#  run simtest, print ever 100 instructions
#  if failure, save whole of last 4M output
#
id=$$
rm -f ~/last.err.$id ~/last.out.$id
time ./simtest.sh 2>&1 | ./last16k.`uname -m` 2> ~/last.err.$id | ./bgrep.`uname -m` '00 : L' | tee ~/last.out.$id
echo output: ~/last.err.$id ~/last.out.$id
