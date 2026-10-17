#
#  Test EAE instructions via pdp8ishad.v
#
#   ./eaetest.sh -real   real PDP
#   ./eaetest.sh -sim    simulator
#
set sa [loadbin eaetest.bin]
pin set sh_clearit 1 sh_clearit 0 sh_frzonerr 1
setsw reg 0
startat $sa
