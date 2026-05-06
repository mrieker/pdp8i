#!/bin/bash
if [ "$usemcp" == "" ]
then
    export usemcp=0
fi
rm -f last.err.$BASHPID last.out.$BASHPID
time ./simtest.sh 2>&1 | ./last16k.`uname -m` 2> last.err.$BASHPID | ./bgrep '00 : L' | tee last.out.$BASHPID
