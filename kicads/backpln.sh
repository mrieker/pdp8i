#!/bin/bash
p=`pwd`
cd `dirname $0`
export CLASSPATH=`pwd`/Backpln.jar:`pwd`/PCB.jar:`pwd`/SCM.jar
cd $p
exec java Backpln
