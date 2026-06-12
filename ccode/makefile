CFLAGS ?= -O2 -Werror
MACH   := $(shell uname -m)
LNKFLG := -lpthread -lreadline -lrt -l$(shell ./tcllib.sh)

EXECUTEABLES := z8ldump.$(MACH) \
	z8lila.$(MACH) z8lpanel.$(MACH) z8lpbit.$(MACH) \
	z8lptp.$(MACH) z8lptr.$(MACH) z8lrk8je.$(MACH) \
	z8ltc08.$(MACH) z8ltty.$(MACH) z8lvc8.$(MACH)

LIBOBJS := \
	assemble.$(MACH).o \
	cmd_pin.$(MACH).o \
	disassemble.$(MACH).o \
	i2czlib.$(MACH).o \
	readprompt.$(MACH).o \
	tclmain.$(MACH).o \
	z8lutil.$(MACH).o

VFILES := \
	../verisim/chips-10ns.v \
	../verisim/mcp23017.v \
	../kicads/console/console.v \
	../kicads/extarith/extarith.v \
	../kicads/extmemory/extmemory.v \
	../kicads/processor/processor.v \
	../zynq/zynq.v \
	../zynq/pdp8ldc02.v \
	../zynq/pdp8lrk8je.v \
	../zynq/pdp8icmem.v \
	../zynq/pdp8irtc.v \
	../zynq/pdp8isim.v \
	../zynq/pdp8ltc08.v \
	../zynq/pdp8ifpi2c.v \
	../zynq/pdp8lptr.v \
	../zynq/pdp8lpbit.v \
	../zynq/pdp8lptp.v \
	../zynq/pdp8ltty.v \
	../zynq/pdp8lvc8.v \
	../zynq/dmareq.v \
	../zynq/i2cmaster.v

ifeq ($(MACH),armv7l)
	LNKFLG  := $(LNKFLG) -latomic
endif

ifeq ($(MACH),x86_64)
	CFLAGS  := $(CFLAGS) -DVERIZYNQ
	EXECUTEABLES := $(EXECUTEABLES) verizynq.$(MACH)
	LIBOBJS := $(LIBOBJS) z8lu32.$(MACH).o
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

binloader.rim: binloader.pal
	pdp8v/asm/assemble -pal binloader.pal binloader.obj > binloader.lis
	pdp8v/asm/link -o binloader.oct binloader.obj > binloader.map
	pdp8v/asm/octtorim < binloader.oct > binloader.rim

dttest.bin: dttest.asm
	pdp8v/asm/assemble dttest.asm dttest.obj > dttest.lis
	pdp8v/asm/link -o dttest.oct dttest.obj > dttest.map
	pdp8v/asm/octtobin < dttest.oct > dttest.bin

verizynq.$(MACH): verizynq.$(MACH).o verilated.$(MACH).o obj_dir/VZynq__ALL.a $(LIBS)
	$(GPP) -o $@ $^ obj_dir/VZynq__ALL.a $(LNKFLG)

verizynq.$(MACH).o: verizynq.cc *.h obj_dir/VZynq.h
	$(GPP) -I/usr/share/verilator/include/ -c -o $@ $<

verilated.$(MACH).o: /usr/share/verilator/include/verilated.cpp
	$(GPP) -Wno-sign-compare -c -o verilated.$(MACH).o -I/usr/share/verilator/include/ /usr/share/verilator/include/verilated.cpp

z8lpbit.$(MACH): z8lpbit.$(MACH).o $(LIBS)
	$(GPP) -o $@ $^ $(LNKFLG) $(PALIB)

z8lvc8.$(MACH): z8lvc8.$(MACH).o $(LIBS)
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

doubleroll.bin: doubleroll.asm
	pdp8v/asm/assemble doubleroll.asm doubleroll.obj > doubleroll.lis
	pdp8v/asm/link -o doubleroll.oct doubleroll.obj > doubleroll.map
	pdp8v/asm/octtobin < doubleroll.oct > doubleroll.bin

kaleid-e.bin: kaleid-e.pal kaleid.pal
	pdp8v/asm/assemble -pal kaleid-e.pal kaleid-e.obj > kaleid-e.lis
	pdp8v/asm/link -o kaleid-e.oct kaleid-e.obj > kaleid-e.map
	pdp8v/asm/octtobin < kaleid-e.oct > kaleid-e.bin

kaleid-i.bin: kaleid-i.pal kaleid.pal
	pdp8v/asm/assemble -pal kaleid-i.pal kaleid-i.obj > kaleid-i.lis
	pdp8v/asm/link -o kaleid-i.oct kaleid-i.obj > kaleid-i.map
	pdp8v/asm/octtobin < kaleid-i.oct > kaleid-i.bin

