#!/bin/bash
#
#  run random instruction test on simulator
#
./verimain.`uname -m` <<EOF
source simtest.tcl
simtest
EOF
