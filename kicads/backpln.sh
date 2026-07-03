#!/bin/bash
cd `dirname $0`
p=`pwd`
for bd in backplane console extardata extarctrl procalu procreg procseq extmemory zturn
do
    cd $p/$bd
    if [ $bd.kicad_pcb -ot $bd.kicad_sch ]
    then
        echo "update $bd.kicad_pcb from $bd.kicad_sch"
        exit 1
    fi
    if [ $bd.v -ot $bd.kicad_pcb ]
    then
        echo "build $bd.v"
        ../veripcb.sh $bd
    fi
done
cd $p
export CLASSPATH=$p/Backpln.jar:$p/PCB.jar:$p/SCM.jar
exec java Backpln
