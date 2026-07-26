#
#  Single-drive DECTape test
#
#   ./dttest.sh -real   real PDP
#   ./dttest.sh -sim    simulator
#
set sa [loadbinptr dttest.bin]
setsw reg [expr {[clock seconds] & 511}]
startat $sa
