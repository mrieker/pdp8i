#!/bin/bash
#
#  run on raspi on tester board with procreg board plugged in
#  tests acum, link, bwcov registers
#
echo 'testacum' | ./testprocreg.armv6l -tcl
