#!/bin/bash
#
#  $1 = processor
#  $2 = proca procb procc procd
#
set -e
mkdir $2
sed "s/$1/$2/g" $1/$1.kicad_pcb > $2/$2.kicad_pcb
sed "s/$1/$2/g" $1/$1.kicad_prl > $2/$2.kicad_prl
sed "s/$1/$2/g" $1/$1.kicad_pro > $2/$2.kicad_pro
sed "s/$1/$2/g" $1/$1.kicad_sch > $2/$2.kicad_sch
