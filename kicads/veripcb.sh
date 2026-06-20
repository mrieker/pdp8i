#!/bin/bash
p=`pwd`
cd `dirname $0`
export CLASSPATH=`pwd`/VeriPCB.jar:`pwd`/PCB.jar
cd $p
exec java VeriPCB $1 < $1.kicad_pcb > $1.v
