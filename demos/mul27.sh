#!/bin/bash
#
#  run mul27 for autotesting
#
set -e
if [ mul27.bin -ot mul27.pal ]
then
    ../ccode/pdp8v/asm/assemble -pal mul27.pal mul27.obj > mul27.lis
    ../ccode/pdp8v/asm/link -o mul27.oct mul27.obj > mul27.map
    ../ccode/pdp8v/asm/octtobin < mul27.oct > mul27.bin
    rm mul27.obj mul27.map mul27.oct
fi
unamem=`uname -m`
if [ mul27tst.$unamem -ot mul27tst.cc ]
then
    g++ -O2 -Werror -std=c++11 -g -Wall -o mul27tst.$unamem -I../ccode mul27tst.cc ../ccode/lib.$unamem.a
fi
../ccode/z8ipanel -sim mul27.tcl
exec ./mul27tst.$unamem
