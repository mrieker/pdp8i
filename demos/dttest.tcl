#
#  Single-drive DECTape test
#
#   ./dttest.sh -real   real PDP
#   ./dttest.sh -sim    simulator
#
set sa [loadbin dttest.bin]
setsw sr [expr {[clock seconds] & 511}]
startat $sa
