CFLAGS ?= -O2 -Werror
MACH   := $(shell uname -m)
GPP    := g++ $(CFLAGS) -std=c++11 -g -Wall


VFILES := \
	backplane.v \
	console.v \
	memory.v \
	processor.v \


default: verimain.$(MACH)

verimain.$(MACH): verimain.$(MACH).o readprompt.$(MACH).o verilated.$(MACH).o obj_dir/Vbackplane__ALL.a
	$(GPP) -g -o verimain.$(MACH) readprompt.$(MACH).o verimain.$(MACH).o \
		verilated.$(MACH).o obj_dir/Vbackplane__ALL.a -lreadline -ltcl8.6

verimain.$(MACH).o: verimain.cc obj_dir/Vbackplane.h
	$(GPP) -g -fPIC -c -o verimain.$(MACH).o -I/usr/share/verilator/include/ verimain.cc

readprompt.$(MACH).o: readprompt.cc
	$(GPP) -g -fPIC -c -o readprompt.$(MACH).o readprompt.cc

verilated.$(MACH).o: /usr/share/verilator/include/verilated.cpp
	$(GPP) -Wno-sign-compare -g -fPIC -c -o verilated.$(MACH).o -I/usr/share/verilator/include/ /usr/share/verilator/include/verilated.cpp

obj_dir/Vbackplane__ALL.a: obj_dir/Vbackplane.mk
	make -C obj_dir -f Vbackplane.mk

obj_dir/Vbackplane.cpp obj_dir/Vbackplane.h obj_dir/Vbackplane.mk: $(VFILES)
	rm -rf obj_dir
	verilator --cc --top-module backplane $(VFILES)

