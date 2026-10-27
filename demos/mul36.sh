#!/bin/bash
#
#  run mul36 for autotesting
#
set -e
if [ mul36.bin -ot mul36.pal ]
then
    ../ccode/pdp8v/asm/assemble -pal mul36.pal mul36.obj > mul36.lis
    ../ccode/pdp8v/asm/link -o mul36.oct mul36.obj > mul36.map
    ../ccode/pdp8v/asm/octtobin < mul36.oct > mul36.bin
    rm mul36.obj mul36.map mul36.oct
fi
unamem=`uname -m`
if [ mul36tst.$unamem -ot mul36tst.cc ]
then
    g++ -O2 -Werror -std=c++11 -g -Wall -o mul36tst.$unamem -I../ccode mul36tst.cc ../ccode/lib.$unamem.a
fi
../ccode/z8ipanel -sim mul36.tcl
exec ./mul36tst.$unamem
