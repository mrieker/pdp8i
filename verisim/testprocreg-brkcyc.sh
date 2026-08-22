#!/bin/bash
#
#  run on raspi on tester board with procreg board plugged in
#  tests brkcyc flipflop
#
echo 'testbrkcyc' | ./testprocreg.armv6l -tcl
