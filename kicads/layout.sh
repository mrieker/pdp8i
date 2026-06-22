#!/bin/bash
p=`pwd`
cd `dirname $0`
export CLASSPATH=`pwd`/Layout.jar:`pwd`/PCB.jar:`pwd`/SCM.jar
cd $p
exec java Layout $1 < $1.kicad_pcb > $1-new.kicad_pcb
