#!/bin/bash
p=`pwd`
cd `dirname $0`
export CLASSPATH=`pwd`/Renum.jar:`pwd`/PCB.jar:`pwd`/SCM.jar
cd $p
exec java Renum $1
