#!/bin/bash
p=`pwd`
cd `dirname $0`
if [ ParsePCB.jar -ot ParsePCB.java ]
then
    set -e
    rm -f ParsePCB*.class ParsePCB.jar
    javac ParsePCB.java
    jar cf ParsePCB.jar ParsePCB*.class
    rm -f ParsePCB*.class
fi
export CLASSPATH=`pwd`/ParsePCB.jar
cd $p
java ParsePCB $1 < $1.kicad_pcb > $1.v 2> $1.x
truesort < $1.x > $1.e
