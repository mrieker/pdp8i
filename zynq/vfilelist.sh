#!/bin/bash
#
#  list source files by scanning project file
#
grep '<File Path="$PPRDIR/' pdp8i.xpr | sed 's;<File Path="$PPRDIR/;;g' | sed 's/">//g'
echo '      pdp8i.xpr'
