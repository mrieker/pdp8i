# use to start up real board set
# does not have extmemory board
# ...so uses zynq.v externmem
pin set fp_manual 0     ;# tell pdp8ifpi2c.v to scan console
pin set fp_i2cspeed 99  ;# use 500KHz for console<->zynq i2c
pin set arm_imemdis 1   ;# turn off extmemory board memory
pin set fpgamemen 1     ;# turn on zynq.v externmem memory
pin set arm_ireset 1    ;# pulse hard reset
pin set arm_ireset 0
