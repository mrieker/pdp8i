CFLAGS ?= -O2 -Werror
MACH   := $(shell uname -m)
GPP    := g++ $(CFLAGS) -std=c++11 -g -Wall

VFILES := \
	backplane.v \
	chips.v \
	../kicads/console/console.v \
	../kicads/extarith/extarith.v \
	../kicads/extmemory/extmemory.v \
	../kicads/processor/processor.v \

OFILES := \
	verimain.$(MACH).o \
	assemble.$(MACH).o \
	disassemble.$(MACH).o \
	readprompt.$(MACH).o \

default: verimain.$(MACH)

verimain.armv7l: $(OFILES)
	$(GPP) -g -o verimain.$(MACH) $(OFILES) -lreadline -ltcl8.6

verimain.x86_64: $(OFILES) verilated.$(MACH).o obj_dir/Vbackplane__ALL.a
	$(GPP) -g -o verimain.$(MACH) $(OFILES) verilated.$(MACH).o obj_dir/Vbackplane__ALL.a /home/mrieker/nfs/tcl8.6.17/install/lib/libtcl8.6.so -lreadline

verimain.armv7l.o: verimain.cc
	$(GPP) -g -fPIC -c -o verimain.$(MACH).o -DZTURN verimain.cc

verimain.x86_64.o: verimain.cc obj_dir/Vbackplane.h
	$(GPP) -g -fPIC -c -o verimain.$(MACH).o -I/usr/share/verilator/include/ -DVERLTR verimain.cc

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

../kicads/console/console.v: ../kicads/console/console.kicad_pcb
	cd ../kicads/console ; ../parsepcb.sh console

../kicads/extarith/extarith.v: ../kicads/extarith/extarith.kicad_pcb
	cd ../kicads/extarith ; ../parsepcb.sh extarith

../kicads/extmemory/extmemory.v: ../kicads/extmemory/extmemory.kicad_pcb
	cd ../kicads/extmemory ; ../parsepcb.sh extmemory

../kicads/processor/processor.v: ../kicads/processor/processor.kicad_pcb
	cd ../kicads/processor ; ../parsepcb.sh processor

../kicads/console/console.kicad_pcb: ../kicads/console/console.kicad_sch
	error update console.kicad_pcb

../kicads/extarith/extarith.kicad_pcb: ../kicads/extarith/extarith.kicad_sch
	error update extarith.kicad_pcb

../kicads/extmemory/extmemory.kicad_pcb: ../kicads/extmemory/extmemory.kicad_sch
	error update extmemory.kicad_pcb

../kicads/processor/processor.kicad_pcb: ../kicads/processor/processor.kicad_sch
	error update processor.kicad_pcb

