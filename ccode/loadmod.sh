#!/bin/bash
cd `dirname $0`
if grep -q 'Xilinx Zynq' /proc/cpuinfo
then
    if ! lsmod | grep -q ^zynqpdp8i
    then
        if [ ! -f km-zynqpdp8i/zynqpdp8i.`uname -r`.ko ]
        then
            cd km-zynqpdp8i
            rm -f zynqpdp8i.ko zynqpdp8i.mod* zynqpdp8i.o modules.order Module.symvers .zynqpdp8i* .modules* .Module*
            make
            mv zynqpdp8i.ko zynqpdp8i.`uname -r`.ko
            cd ..
        fi
        sudo insmod km-zynqpdp8i/zynqpdp8i.`uname -r`.ko
    fi
fi
