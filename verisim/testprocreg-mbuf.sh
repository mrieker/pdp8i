#!/bin/bash
#
#  run on raspi on tester board with procreg board plugged in
#  tests mbuf register
#
echo 'testmbuf' | ./testprocreg.armv6l -tcl
