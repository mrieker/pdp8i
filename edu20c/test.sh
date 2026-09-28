#!/bin/bash
#
#  Run simple EDU20C test on real PDP or simulator
#
case $1 in
    real) exec ../ccode/z8ipanel -real -log ~/test.log test.tcl ;;
    sim)  exec ../ccode/z8ipanel -sim  -log ~/test.log test.tcl ;;
    *)    echo missing real or sim argument ;;
esac
