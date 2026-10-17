#!/bin/bash
#
#  Test EAE instructions
#
set -e
cd `dirname $0`
if [ eaetest.bin -ot eaetest.asm ]
then
    ../ccode/pdp8v/asm/assemble eaetest.asm eaetest.obj > eaetest.lis
    ../ccode/pdp8v/asm/link -o eaetest.oct eaetest.obj > eaetest.map
    ../ccode/pdp8v/asm/octtobin < eaetest.oct > eaetest.bin
fi
../ccode/z8ipanel "$@" eaetest.tcl
exec ../ccode/z8itty -nokb -cps 960
