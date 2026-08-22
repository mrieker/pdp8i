#!/bin/bash
#
#  run on raspi on tester board with procreg board plugged in
#  tests acum and link registers
#
echo 'testacum' | ./testprocreg.armv6l -tcl
