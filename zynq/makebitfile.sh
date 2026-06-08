#!/bin/bash
#
#  use vivado to create .bit file from .v and .vhd files
#
cd `dirname $0`
rm -f pdp8i.runs/*/runme.log
rm -f pdp8i.runs/impl_1/myboard_wrapper.bit
/tools/Xilinx/Vivado/2018.3/bin/vivado -mode batch -source makebitfile.tcl
while ( ps | grep -v grep | grep -q loader )
do
    sleep 1
done
echo = = = = = = = = = = = =
sleep 2
grep ^ERROR pdp8i.runs/*/runme.log
ls -l pdp8i.runs/impl_1/myboard_wrapper.bit
echo = = = = = = = = = = = =
./sortmyboard.sh
sleep 0.125
touch pdp8i.runs/impl_1/myboard_wrapper.bit
