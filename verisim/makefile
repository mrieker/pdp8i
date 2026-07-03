CFLAGS ?= -O2 -Werror
MACH   := $(shell uname -m)
GPP    := g++ $(CFLAGS) -std=c++11 -g -Wall

VFILES := \
	backplane.v \
	blk_mem_gen_0.v \
	chips-varns.v \
	dmatest.v \
	mcp23017.v \
	../kicads/console/console.v \
	../kicads/dmatester/dmatester.v \
	../kicads/extarctrl/extarctrl.v \
	../kicads/extardata/extardata.v \
	../kicads/extmemory/extmemory.v \
	../kicads/procalu/procalu.v \
	../kicads/procreg/procreg.v \
	../kicads/procseq/procseq.v \
	../zynq/zynq.v \
	../zynq/pdp8idc02.v \
	../zynq/pdp8irk8je.v \
	../zynq/pdp8icmem.v \
	../zynq/pdp8irtc.v \
	../zynq/pdp8isim.v \
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

default: verimain.$(MACH) testprocalu.$(MACH)

verimain.$(MACH): $(OFILES) verilated.$(MACH).o obj_dir/Vbackplane__ALL.a
	$(GPP) -g -o verimain.$(MACH) $(OFILES) verilated.$(MACH).o obj_dir/Vbackplane__ALL.a /home/mrieker/nfs/tcl8.6.17/install/lib/libtcl8.6.so -lreadline

verimain.$(MACH).o: verimain.cc obj_dir/Vbackplane.h
	$(GPP) -g -fPIC -c -o verimain.$(MACH).o -I/usr/share/verilator/include/ verimain.cc

testprocalu.$(MACH): testprocalu.$(MACH).o testlib.$(MACH).o verilated.$(MACH).o veriprocalu/Vprocalu__ALL.a
	$(GPP) -g -o testprocalu.$(MACH) testprocalu.$(MACH).o testlib.$(MACH).o verilated.$(MACH).o veriprocalu/Vprocalu__ALL.a

testprocalu.$(MACH).o: testprocalu.cc testlib.h obj_dir/Vbackplane.h
	$(GPP) -g -fPIC -c -o testprocalu.$(MACH).o -I/usr/share/verilator/include/ testprocalu.cc

testlib.$(MACH).o: testlib.cc testlib.h
	$(GPP) -g -fPIC -c -o testlib.$(MACH).o testlib.cc

assemble.$(MACH).o: assemble.cc
	$(GPP) -g -fPIC -c -o assemble.$(MACH).o assemble.cc

disassemble.$(MACH).o: disassemble.cc
	$(GPP) -g -fPIC -c -o disassemble.$(MACH).o disassemble.cc

readprompt.$(MACH).o: readprompt.cc
	$(GPP) -g -fPIC -c -o readprompt.$(MACH).o readprompt.cc

verilated.$(MACH).o: /usr/share/verilator/include/verilated.cpp
	$(GPP) -Wno-sign-compare -g -fPIC -c -o verilated.$(MACH).o -I/usr/share/verilator/include/ /usr/share/verilator/include/verilated.cpp

obj_dir/Vbackplane__ALL.a: obj_dir/Vbackplane.mk
	make -C obj_dir -f Vbackplane.mk

obj_dir/Vbackplane.cpp obj_dir/Vbackplane.h obj_dir/Vbackplane.mk: $(VFILES)
	rm -rf obj_dir
	verilator --cc --top-module backplane $(VFILES)

veriprocalu/Vprocalu__ALL.a: veriprocalu/Vprocalu.mk
	make -C veriprocalu -f Vprocalu.mk

veriprocalu/Vprocalu.cpp veriprocalu/Vprocalu.h veriprocalu/Vprocalu.mk: ../kicads/procalu/procalu.v chips-varns.v
	rm -rf veriprocalu
	verilator --cc --Mdir veriprocalu --top-module procalu ../kicads/procalu/procalu.v chips-varns.v

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

../kicads/console/console.kicad_pcb: ../kicads/console/console.kicad_sch
	error update console.kicad_pcb

../kicads/dmatester/dmatester.kicad_pcb: ../kicads/dmatester/dmatester.kicad_sch
	error update dmatester.kicad_pcb

../kicads/extarith/extarith.kicad_pcb: ../kicads/extarith/extarith.kicad_sch
	error update extarith.kicad_pcb

../kicads/extmemory/extmemory.kicad_pcb: ../kicads/extmemory/extmemory.kicad_sch
	error update extmemory.kicad_pcb

../kicads/processor/processor.kicad_pcb: ../kicads/processor/processor.kicad_sch
	error update processor.kicad_pcb

