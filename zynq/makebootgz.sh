#!/bin/bash
#
#  create the BOOT.BIN file for pdp8i and gzip it
#  assumes the .bit bitstream file is up-to-date (compiled with vivado)
#  assumes hostname zturn points to zturn board all booted up with an existing BOOT.BIN file
#    zturn root .ssh/authorized_keys should have this user's .ssh public key so don't need to enter its password
#  assumes directories ../zplin/petadevel and ../zplin/petakernel exist and are filled in
#    follow howto file in ../zplin
#
cd `dirname $0`
mydir=`pwd`

rm -f $mydir/BOOT.BIN.gz

cd ../zplin
source petadevel/settings.sh
source /tools/Xilinx/Vivado/2018.3/settings64.sh
cd petakernl/zturn
rm -f images/linux/BOOT.BIN
petalinux-package --boot --force --fsbl ./images/linux/zynq_fsbl.elf --fpga $mydir/pdp8i.runs/impl_1/myboard_wrapper.bit --u-boot

gzip -c images/linux/BOOT.BIN > $mydir/BOOT.BIN.gz
