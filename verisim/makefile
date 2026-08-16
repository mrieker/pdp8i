CFLAGS ?= -O2 -Werror
MACH   := $(shell uname -m)
GPP    := g++ $(CFLAGS) -std=c++11 -g -Wall

COMMON := bgrep.$(MACH) last16k.$(MACH)
ARMVxL := $(COMMON) resetmcp.$(MACH) testcon1.$(MACH) testcon1.$(MACH) testconsole.$(MACH) testprocalu.$(MACH) testprocseq.$(MACH) testzturn.$(MACH)

ifeq ($(MACH),armv6l)
	DEFAULT := $(ARMVxL)
endif
ifeq ($(MACH),armv7l)
	DEFAULT := $(ARMVxL)
endif
ifeq ($(MACH),x86_64)
	DEFAULT := $(COMMON) verimain.$(MACH)
endif

VFILES := \
	backplane.v \
	blk_mem_gen_0.v \
	blk_mem_gen_1.v \
	chips-varns.v \
	dmatest.v \
	mcp23017.v \
	zturnbundle.v \
	../kicads/console/console.v \
	../kicads/dmatester/dmatester.v \
	../kicads/extarctrl/extarctrl.v \
	../kicads/extardata/extardata.v \
	../kicads/extmemory/extmemory.v \
	../kicads/procalu/procalu.v \
	../kicads/procreg/procreg.v \
	../kicads/procseq/procseq.v \
	../kicads/zturn/zturn.v \
	../zynq/zynq.v \
	../zynq/pdp8idc02.v \
	../zynq/pdp8irk8je.v \
	../zynq/pdp8icmem.v \
	../zynq/pdp8irtc.v \
	../zynq/pdp8ishad.v \
	../zynq/pdp8isim.v \
	../zynq/pdp8isys.v \
	../zynq/pdp8itc08.v \
	../zynq/pdp8ifpi2c.v \
	../zynq/pdp8iptr.v \
	../zynq/pdp8ipbit.v \
	../zynq/pdp8iptp.v \
	../zynq/pdp8itty.v \
	../zynq/pdp8ivc8.v \
	../zynq/dmareq.v \
	../zynq/i2cmaster.v \

OFILES := \
	verimain.$(MACH).o \
	assemble.$(MACH).o \
	disassemble.$(MACH).o \
	readprompt.$(MACH).o \

default: $(DEFAULT)

bgrep.$(MACH): bgrep.c
	cc -O2 -o bgrep.$(MACH) bgrep.c

last16k.$(MACH): last16k.c
	cc -O2 -o last16k.$(MACH) last16k.c

verimain.$(MACH): $(OFILES) verilated.$(MACH).o vbackplane.$(MACH)/Vbackplane__ALL.a
	$(GPP) -g -o verimain.$(MACH) $(OFILES) verilated.$(MACH).o vbackplane.$(MACH)/Vbackplane__ALL.a /home/mrieker/nfs/tcl8.6.17/install/lib/libtcl8.6.so -lreadline

verimain.$(MACH).o: verimain.cc vbackplane.$(MACH)/Vbackplane.h
	$(GPP) -g -fPIC -c -o verimain.$(MACH).o -Ivbackplane.$(MACH) -I/usr/share/verilator/include/ verimain.cc

testcon1.$(MACH): testcon1.$(MACH).o testlib.$(MACH).o i2cmaster.$(MACH).o
	$(GPP) -g -o testcon1.$(MACH) testcon1.$(MACH).o testlib.$(MACH).o i2cmaster.$(MACH).o

testcon1.$(MACH).o: testcon1.cc testlib.h testerdefs.h i2cmaster.h
	$(GPP) -g -c -Wno-narrowing -o testcon1.$(MACH).o testcon1.cc

testconsole.$(MACH): testconsole.$(MACH).o testlib.$(MACH).o i2cmaster.$(MACH).o randbits.$(MACH).o
	$(GPP) -g -o testconsole.$(MACH) testconsole.$(MACH).o testlib.$(MACH).o i2cmaster.$(MACH).o randbits.$(MACH).o

testconsole.$(MACH).o: testconsole.cc testlib.h testerdefs.h i2cmaster.h
	$(GPP) -g -c -Wno-narrowing -o testconsole.$(MACH).o testconsole.cc

testprocalu.$(MACH): testprocalu.$(MACH).o testlib.$(MACH).o i2cmaster.$(MACH).o randbits.$(MACH).o verilated.$(MACH).o veriprocalu.$(MACH)/Vprocalu__ALL.a
	$(GPP) -g -o testprocalu.$(MACH) testprocalu.$(MACH).o testlib.$(MACH).o i2cmaster.$(MACH).o randbits.$(MACH).o verilated.$(MACH).o veriprocalu.$(MACH)/Vprocalu__ALL.a

testprocalu.$(MACH).o: testprocalu.cc testlib.h testerdefs.h i2cmaster.h veriprocalu.$(MACH)/Vprocalu.h
	$(GPP) -g -c -o testprocalu.$(MACH).o -Iveriprocalu.$(MACH) -I/usr/share/verilator/include/ testprocalu.cc

testprocseq.$(MACH): testprocseq.$(MACH).o testlib.$(MACH).o i2cmaster.$(MACH).o randbits.$(MACH).o verilated.$(MACH).o veriprocseq.$(MACH)/Vprocseq__ALL.a
	$(GPP) -g -o testprocseq.$(MACH) testprocseq.$(MACH).o testlib.$(MACH).o i2cmaster.$(MACH).o randbits.$(MACH).o verilated.$(MACH).o veriprocseq.$(MACH)/Vprocseq__ALL.a

testprocseq.$(MACH).o: testprocseq.cc testlib.h testerdefs.h i2cmaster.h veriprocseq.$(MACH)/Vprocseq.h
	$(GPP) -g -c -o testprocseq.$(MACH).o -Iveriprocseq.$(MACH) -I/usr/share/verilator/include/ testprocseq.cc

testzturn.$(MACH): testzturn.$(MACH).o testlib.$(MACH).o i2cmaster.$(MACH).o ../ccode/z8iutil.$(MACH).o
	$(GPP) -g -o testzturn.$(MACH) testzturn.$(MACH).o testlib.$(MACH).o i2cmaster.$(MACH).o ../ccode/z8iutil.$(MACH).o

testzturn.$(MACH).o: testzturn.cc testlib.h testerdefs.h i2cmaster.h ../ccode/z8idefs.h ../ccode/z8iutil.h
	$(GPP) -g -c -o testzturn.$(MACH).o testzturn.cc

resetmcp.$(MACH): resetmcp.$(MACH).o testlib.$(MACH).o i2cmaster.$(MACH).o
	$(GPP) -g -o resetmcp.$(MACH) resetmcp.$(MACH).o testlib.$(MACH).o i2cmaster.$(MACH).o

resetmcp.$(MACH).o: resetmcp.cc testlib.h testerdefs.h i2cmaster.h
	$(GPP) -g -fPIC -c -o resetmcp.$(MACH).o resetmcp.cc

testlib.$(MACH).o: testlib.cc testlib.h testerdefs.h i2cmaster.h
	$(GPP) -g -fPIC -c -o testlib.$(MACH).o testlib.cc

i2cmaster.$(MACH).o: i2cmaster.cc i2cmaster.h
	$(GPP) -g -fPIC -c -o i2cmaster.$(MACH).o i2cmaster.cc

randbits.$(MACH).o: randbits.cc randbits.h
	$(GPP) -g -fPIC -c -o randbits.$(MACH).o randbits.cc

testerdefs.h: ../kicads/tester/tester.kicad_pcb
	cd ../kicads ; ./testerdefs.sh > $(CURDIR)/testerdefs.h

assemble.$(MACH).o: assemble.cc
	$(GPP) -g -fPIC -c -o assemble.$(MACH).o assemble.cc

disassemble.$(MACH).o: disassemble.cc
	$(GPP) -g -fPIC -c -o disassemble.$(MACH).o disassemble.cc

readprompt.$(MACH).o: readprompt.cc
	$(GPP) -g -fPIC -c -o readprompt.$(MACH).o readprompt.cc

verilated.$(MACH).o: /usr/share/verilator/include/verilated.cpp
	$(GPP) -Wno-sign-compare -g -fPIC -c -o verilated.$(MACH).o -I/usr/share/verilator/include/ /usr/share/verilator/include/verilated.cpp

vbackplane.$(MACH)/Vbackplane__ALL.a: vbackplane.$(MACH)/Vbackplane.mk
	make -C vbackplane.$(MACH) -f Vbackplane.mk

vbackplane.$(MACH)/Vbackplane.cpp vbackplane.$(MACH)/Vbackplane.h vbackplane.$(MACH)/Vbackplane.mk: $(VFILES)
	rm -rf vbackplane.$(MACH)
	verilator --cc --Mdir vbackplane.$(MACH) --top-module backplane $(VFILES)

veriprocalu.$(MACH)/Vprocalu__ALL.a: veriprocalu.$(MACH)/Vprocalu.mk
	make -C veriprocalu.$(MACH) -f Vprocalu.mk

veriprocalu.$(MACH)/Vprocalu.cpp veriprocalu.$(MACH)/Vprocalu.h veriprocalu.$(MACH)/Vprocalu.mk: ../kicads/procalu/procalu.v chips-varns.v
	rm -rf veriprocalu.$(MACH)
	verilator --cc --Mdir veriprocalu.$(MACH) --top-module procalu ../kicads/procalu/procalu.v chips-varns.v

veriprocseq.$(MACH)/Vprocseq__ALL.a: veriprocseq.$(MACH)/Vprocseq.mk
	make -C veriprocseq.$(MACH) -f Vprocseq.mk

veriprocseq.$(MACH)/Vprocseq.cpp veriprocseq.$(MACH)/Vprocseq.h veriprocseq.$(MACH)/Vprocseq.mk: ../kicads/procseq/procseq.v chips-varns.v
	rm -rf veriprocseq.$(MACH)
	verilator --cc --Mdir veriprocseq.$(MACH) --top-module procseq ../kicads/procseq/procseq.v chips-varns.v

../kicads/console/console.v: ../kicads/console/console.kicad_pcb
	cd ../kicads/console ; ../veripcb.sh console

../kicads/dmatester/dmatester.v: ../kicads/dmatester/dmatester.kicad_pcb
	cd ../kicads/dmatester ; ../veripcb.sh dmatester

../kicads/extarctrl/extarctrl.v: ../kicads/extarctrl/extarctrl.kicad_pcb
	cd ../kicads/extarctrl ; ../veripcb.sh extarctrl

../kicads/extardata/extardata.v: ../kicads/extardata/extardata.kicad_pcb
	cd ../kicads/extardata ; ../veripcb.sh extardata

../kicads/extmemory/extmemory.v: ../kicads/extmemory/extmemory.kicad_pcb
	cd ../kicads/extmemory ; ../veripcb.sh extmemory

../kicads/procalu/procalu.v: ../kicads/procalu/procalu.kicad_pcb
	cd ../kicads/procalu ; ../veripcb.sh procalu

../kicads/procreg/procreg.v: ../kicads/procreg/procreg.kicad_pcb
	cd ../kicads/procreg ; ../veripcb.sh procreg

../kicads/procseq/procseq.v: ../kicads/procseq/procseq.kicad_pcb
	cd ../kicads/procseq ; ../veripcb.sh procseq

../kicads/zturn/zturn.v: ../kicads/zturn/zturn.kicad_pcb
	cd ../kicads/zturn ; ../veripcb.sh zturn

../kicads/console/console.kicad_pcb: ../kicads/console/console.kicad_sch
	error update console.kicad_pcb

../kicads/dmatester/dmatester.kicad_pcb: ../kicads/dmatester/dmatester.kicad_sch
	error update dmatester.kicad_pcb

../kicads/extmemory/extmemory.kicad_pcb: ../kicads/extmemory/extmemory.kicad_sch
	error update extmemory.kicad_pcb

../kicads/tester/tester.kicad_pcb: ../kicads/tester/tester.kicad_sch
	error update tester.kicad_pcb

