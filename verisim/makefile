CFLAGS ?= -O2 -Werror
MACH   := $(shell uname -m)
GPP    := g++ $(CFLAGS) -std=c++11 -g -Wall


VFILES := \
	backplane.v \
	chips.v \
	console.v \
	extarith.v \
	flipflops.v \
	memext.v \
	memory.v \
	../kicads/processor/processor.v \
	../kicads/registers/registers.v \

OFILES := \
	verimain.$(MACH).o \
	assemble.$(MACH).o \
	disassemble.$(MACH).o \
	readprompt.$(MACH).o \
	verilated.$(MACH).o 

default: verimain.$(MACH)

verimain.$(MACH): $(OFILES) obj_dir/Vbackplane__ALL.a
	$(GPP) -g -o verimain.$(MACH) $(OFILES) obj_dir/Vbackplane__ALL.a /home/mrieker/nfs/tcl8.6.17/install/lib/libtcl8.6.so -lreadline

verimain.$(MACH).o: verimain.cc obj_dir/Vbackplane.h
	$(GPP) -g -fPIC -c -o verimain.$(MACH).o -I/usr/share/verilator/include/ verimain.cc

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

