#!/bin/bash
cd `dirname $0`
case "$1" in
    real) exec ../ccode/z8ipanel -real doubleroll.tcl ;;
    sim)  exec ../ccode/z8ipanel -sim  doubleroll.tcl ;;
    *) echo "missing 'real' or 'sim' parameter" ;;
esac
