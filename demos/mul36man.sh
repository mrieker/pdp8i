#!/bin/bash
#
#  run mul36 program for manual input
#
#  ./mul36man.sh
#    ...
#  >octalnumber*octalnumber=printsproduct
#
set -e
if [ mul36.bin -ot mul36.pal ]
then
    ../ccode/pdp8v/asm/assemble -pal mul36.pal mul36.obj > mul36.lis
    ../ccode/pdp8v/asm/link -o mul36.oct mul36.obj > mul36.map
    ../ccode/pdp8v/asm/octtobin < mul36.oct > mul36.bin
    rm mul36.obj mul36.map mul36.oct
fi
../ccode/z8ipanel -sim mul36.tcl
exec ../ccode/z8itty -cps 960
