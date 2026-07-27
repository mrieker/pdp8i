#!/bin/bash
p=`pwd`
cd `dirname $0`
export CLASSPATH=`pwd`/VeriPCB.jar:`pwd`/PCB.jar:`pwd`/SCM.jar
cd $p
set -e
rm -f $1.v
java VeriPCB $1 < $1.kicad_pcb > $1.v.tmp
mv -f $1.v.tmp $1.v
