#!/bin/bash
set -e
../../pdp8v/asm/assemble -pal mul27.pal mul27.obj > mul27.lis
../../pdp8v/asm/link -o mul27.oct mul27.obj > mul27.map
../../pdp8v/asm/octtobin < mul27.oct > mul27.bin
exec ../ccode/z8ipanel -sim mul27.tcl
