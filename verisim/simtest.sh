#!/bin/bash
#
#  run random instruction test on simulator
#
cd `dirname $0`
./verimain <<EOF
source simtest.tcl
simtest
EOF
