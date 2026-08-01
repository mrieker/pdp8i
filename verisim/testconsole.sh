#!/bin/bash
#
#  run testconsole
#  if failure, save whole of last 4M output
#
id=$$
unamem=`uname -m`
rm -f ~/testconsole.err.$id ~/testconsole.out.$id
time ./testconsole.$unamem "$@" 2>&1 | ./last16k.$unamem 2> ~/testconsole.err.$id | ./bgrep.$unamem '000 acum' | tee ~/testconsole.out.$id
echo output: ~/testconsole.err.$id ~/testconsole.out.$id
