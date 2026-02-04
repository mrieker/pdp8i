#!/bin/bash
#
#  run random instruction test on simulator
#
./verimain.x86_64 <<EOF
source simtest.tcl
simtest
EOF
