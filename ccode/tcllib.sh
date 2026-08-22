#!/bin/bash
#
#  Caled by makefile to print name of tcl library for linking
#
dn=`dirname $0`
inc=`$dn/tclinc.sh`
basename $inc
