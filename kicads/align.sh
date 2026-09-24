#!/bin/bash
p=`pwd`
cd `dirname $0`
export CLASSPATH=`pwd`/Align.jar:`pwd`/PCB.jar:`pwd`/SCM.jar
cd $p
exec java Align $1
