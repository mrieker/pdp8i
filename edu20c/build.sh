#!/bin/bash
#
#  Build EDU20C using real PDP or simulator
#
case $1 in
    real) exec ../ccode/z8ipanel -real -log ~/build.log build.tcl ;;
    sim)  exec ../ccode/z8ipanel -sim  -log ~/build.log build.tcl ;;
    *)    echo missing real or sim argument ;;
esac
