#!/bin/bash
if [ "$usemcp" == "" ]
then
    export usemcp=0
fi
rm -f last.err.$usemcp last.out.$usemcp
time ./simtest.sh 2>&1 | ./last16k.`uname -m` 2> last.err.$usemcp | ./bgrep '00 : L' | tee last.out.$usemcp
