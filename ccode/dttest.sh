#!/bin/bash
#
#  Test z8itc08.cc and pdp8itc.v
#
set -e
if [ dttest.bin -ot dttest.asm ]
then
    pdp8v/asm/assemble dttest.asm dttest.obj > dttest.lis
    pdp8v/asm/link -o dttest.oct dttest.obj > dttest.map
    pdp8v/asm/octtobin < dttest.oct > dttest.bin
fi
export z8itc08_debug=0
./z8itc08 -killit -loadrw 0 ~/dttest.tu56 &
tcid=$!
./z8itty -cps 960 -killit -nokb &
ttid=$!
./z8isim dttest.tcl
kill $tcid
kill $ttid
