#!/bin/bash
cd `dirname $0`
export CLASSPATH=`pwd`/TesterDefs.jar:`pwd`/PCB.jar:`pwd`/SCM.jar
exec java TesterDefs < tester/tester.kicad_pcb
