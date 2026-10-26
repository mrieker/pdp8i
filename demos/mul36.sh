#!/bin/bash
set -e
../../pdp8v/asm/assemble -pal mul36.pal mul36.obj > mul36.lis
../../pdp8v/asm/link -o mul36.oct mul36.obj > mul36.map
../../pdp8v/asm/octtobin < mul36.oct > mul36.bin
exec ../ccode/z8ipanel -sim mul36.tcl
