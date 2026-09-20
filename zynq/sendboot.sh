#!/bin/bash
#
#  send boot and image files to zturn sdcard
#
#   $1 = zturn hostname
#
set -e -x
remimage=`ssh root@$1 md5sum /boot/image.ub`
lclimage=`md5sum image.ub`
if [ ${remimage:0:32} != ${lclimage:0:32} ]
then
    scp image.ub root@$1:/boot/imagex.ub
    ssh root@$1 mv -f /boot/imagex.ub /boot/image.ub
fi
remboot=`ssh root@$1 md5sum /boot/BOOT.BIN`
lclboot=`zcat BOOT.BIN.gz | md5sum`
if [ ${remboot:0:32} != ${lclboot:0:32} ]
then
    zcat BOOT.BIN.gz | ssh root@$1 dd of=/boot/BOOTX.BIN
    ssh root@$1 mv -f /boot/BOOTX.BIN /boot/BOOT.BIN
fi
set +e
ssh root@$1 reboot
ping -c 90 $1
