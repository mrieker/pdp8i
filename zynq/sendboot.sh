#!/bin/bash
#
#  send boot and image files to zturn sdcard
#
#   $1 = zturn hostname
#
set -e -x
make
remimage=`ssh root@$1 md5sum /boot/image.ub`
lclimage=`md5sum image.ub`
if [ ${remimage:0:32} != ${lclimage:0:32} ]
then
    scp image.ub root@$1:/boot/imagex.ub
    ssh root@$1 mv -f /boot/imagex.ub /boot/image.ub
fi
zcat BOOT.BIN.gz | ssh root@$1 dd of=/boot/BOOTX.BIN
ssh root@$1 mv -f /boot/BOOTX.BIN /boot/BOOT.BIN
set +e
ssh root@$1 reboot
ping -c 90 $1
