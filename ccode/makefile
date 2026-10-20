CFLAGS ?= -O2 -Werror
MACH   := $(shell uname -m)
LNKFLG := -lpthread -lreadline -lrt -l$(shell ./tcllib.sh)

EXECUTEABLES := z8idump.$(MACH) \
	z8iila.$(MACH) z8ipanel.$(MACH) z8ipbit.$(MACH) \
	z8iptp.$(MACH) z8iptr.$(MACH) z8irk8je.$(MACH) \
	z8isys.$(MACH) z8itc08.$(MACH) z8itrace.$(MACH) \
	z8itty.$(MACH) z8ivc8.$(MACH) \
	pidpclient.$(MACH) pidpserver.$(MACH)

LIBOBJS := \
	assemble.$(MACH).o \
	cmd_pin.$(MACH).o \
	disassemble.$(MACH).o \
	i2czlib.$(MACH).o \
	pidp_proc.$(MACH).o \
	randbits.$(MACH).o \
	readprompt.$(MACH).o \
	shaderr.$(MACH).o \
	strprintf.$(MACH).o \
	tclmain.$(MACH).o \
	z8iutil.$(MACH).o

VFILES := \
	../verisim/blk_mem_gen_0.v \
	../verisim/blk_mem_gen_1.v \
	../verisim/chips-10ns.v \
	../verisim/mcp23017.v \
	../kicads/console/console.v \
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
	../zynq/pdp8isys.v \
	../zynq/pdp8itc08.v \
	../zynq/pdp8ifpi2c.v \
	../zynq/pdp8iptr.v \
	../zynq/pdp8ipbit.v \
	../zynq/pdp8iptp.v \
	../zynq/pdp8ishad.v \
	../zynq/pdp8itty.v \
	../zynq/pdp8ivc8.v \
	../zynq/dmareq.v \
	../zynq/i2cmaster.v

ifeq ($(MACH),armv7l)
	LNKFLG  := $(LNKFLG) -latomic
endif

ifeq ($(MACH),x86_64)
	CFLAGS  := $(CFLAGS) -DVERIZYNQ
	EXECUTEABLES := $(EXECUTEABLES) verizynq.$(MACH)
	LIBOBJS := $(LIBOBJS) z8iu32.$(MACH).o
endif

ifneq (,$(wildcard /usr/include/pulse/simple.h))
	HASPA := 1
	PALIB := -lpulse-simple
else
	HASPA := 0
	PALIB :=
endif

LIBS   := lib.$(MACH).a

TCLINC := -I$(shell ./tclinc.sh)
GPP    := g++ $(CFLAGS) $(TCLINC) -std=c++11 -g -Wall -fPIC

default: $(EXECUTEABLES)

lib.$(MACH).a: $(LIBOBJS)
	rm -f lib.$(MACH).a
	ar rc $@ $^

binloader.rim: binloader.pal pdp8v/asm/assemble pdp8v/asm/link pdp8v/asm/octtorim
	pdp8v/asm/assemble -pal binloader.pal binloader.obj > binloader.lis
	pdp8v/asm/link -o binloader.oct binloader.obj > binloader.map
	pdp8v/asm/octtorim < binloader.oct > binloader.rim

verizynq.$(MACH): verizynq.$(MACH).o verilated.$(MACH).o obj_dir/VZynq__ALL.a $(LIBS)
	$(GPP) -o $@ $^ obj_dir/VZynq__ALL.a $(LNKFLG)

verizynq.$(MACH).o: verizynq.cc *.h obj_dir/VZynq.h
	$(GPP) -I/usr/share/verilator/include/ -c -o $@ $<

verilated.$(MACH).o: /usr/share/verilator/include/verilated.cpp
	$(GPP) -Wno-sign-compare -c -o verilated.$(MACH).o -I/usr/share/verilator/include/ /usr/share/verilator/include/verilated.cpp

z8ipbit.$(MACH): z8ipbit.$(MACH).o $(LIBS)
	$(GPP) -o $@ $^ $(LNKFLG) $(PALIB)

z8ivc8.$(MACH): z8ivc8.$(MACH).o $(LIBS)
	$(GPP) -o $@ $^ $(LNKFLG) -lX11

%.$(MACH): %.$(MACH).o $(LIBS)
	$(GPP) -o $@ $^ $(LNKFLG)

%.$(MACH).o: %.cc *.h
	$(GPP) -DHASPA=$(HASPA) -c -o $@ $<

obj_dir/VZynq__ALL.a: obj_dir/VZynq.mk
	make -C obj_dir -f VZynq.mk

obj_dir/VZynq.cpp obj_dir/VZynq.h obj_dir/VZynq.mk: $(VFILES)
	rm -rf obj_dir
	verilator --cc --top-module Zynq $(VFILES)

pdp8v/asm/%: pdp8v
	make -C pdp8v/asm

pdp8v:
	git clone https://github.com/mrieker/pdp8v.git

