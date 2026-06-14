#!/bin/bash
#
#  Test z8itc08.cc and pdp8itc08.v
#
#  Optional:
#    Run '../ccode/z8itc08 -status' in another window
#
set -e
cd `dirname $0`
if [ dttest.bin -ot dttest.asm ]
then
    ../ccode/pdp8v/asm/assemble dttest.asm dttest.obj > dttest.lis
    ../ccode/pdp8v/asm/link -o dttest.oct dttest.obj > dttest.map
    ../ccode/pdp8v/asm/octtobin < dttest.oct > dttest.bin
fi
../ccode/z8itc08 -killit -loadrw 0 ~/dttest.tu56 &
tcid=$!
../ccode/z8ipanel "$@" dttest.tcl
../ccode/z8itty -cps 960 -killit -nokb
kill $tcid
