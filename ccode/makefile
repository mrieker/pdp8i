CFLAGS ?= -O2 -Werror
MACH   := $(shell uname -m)
TCLINC := -I$(shell ./tclinc.sh)
GPP    := g++ $(CFLAGS) $(TCLINC) -std=c++11 -g -Wall -fPIC
LNKFLG := -lpthread -lreadline -lrt -l$(shell ./tcllib.sh)

ifeq ($(MACH),armv7l)
	LNKFLG := $(LNKFLG) -latomic
endif

ifneq (,$(wildcard /usr/include/pulse/simple.h))
	HASPA := 1
	PALIB := -lpulse-simple
else
	HASPA := 0
	PALIB :=
endif

LIBS = lib.$(MACH).a

default: z8ldump.$(MACH) \
	z8lila.$(MACH) z8lpanel.$(MACH) z8lpbit.$(MACH) \
	z8lptp.$(MACH) z8lptr.$(MACH) z8lrk8je.$(MACH) \
	z8ltc08.$(MACH) z8ltty.$(MACH) z8lvc8.$(MACH)

lib.$(MACH).a: \
		assemble.$(MACH).o \
		cmd_pin.$(MACH).o \
		disassemble.$(MACH).o \
		i2czlib.$(MACH).o \
		readprompt.$(MACH).o \
		tclmain.$(MACH).o \
		z8lutil.$(MACH).o
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

z8ldump.$(MACH): z8ldump.$(MACH).o $(LIBS)
	$(GPP) -o $@ $^ -lpthread

z8lila.$(MACH): z8lila.$(MACH).o $(LIBS)
	$(GPP) -o $@ $^ -lpthread

z8lpanel.$(MACH): z8lpanel.$(MACH).o $(LIBS)
	$(GPP) -o $@ $^ $(LNKFLG)

z8lpbit.$(MACH): z8lpbit.$(MACH).o $(LIBS)
	$(GPP) -o $@ $^ $(LNKFLG) $(PALIB)

z8lptp.$(MACH): z8lptp.$(MACH).o $(LIBS)
	$(GPP) -o $@ $^ $(LNKFLG)

z8lptr.$(MACH): z8lptr.$(MACH).o $(LIBS)
	$(GPP) -o $@ $^ $(LNKFLG)

z8lrk8je.$(MACH): z8lrk8je.$(MACH).o $(LIBS)
	$(GPP) -o $@ $^ $(LNKFLG)

z8ltc08.$(MACH): z8ltc08.$(MACH).o $(LIBS)
	$(GPP) -o $@ $^ $(LNKFLG)

z8ltrace.$(MACH): z8ltrace.$(MACH).o $(LIBS)
	$(GPP) -o $@ $^ -lpthread

z8ltty.$(MACH): z8ltty.$(MACH).o $(LIBS)
	$(GPP) -o $@ $^ $(LNKFLG)

z8lvc8.$(MACH): z8lvc8.$(MACH).o $(LIBS)
	$(GPP) -o $@ $^ -lX11

%.$(MACH).o: %.cc *.h
	$(GPP) -DHASPA=$(HASPA) -c -o $@ $<

doubleroll-8l.bin: doubleroll-8l.asm
	pdp8v/asm/assemble doubleroll-8l.asm doubleroll-8l.obj > doubleroll-8l.lis
	pdp8v/asm/link -o doubleroll-8l.oct doubleroll-8l.obj > doubleroll-8l.map
	pdp8v/asm/octtobin < doubleroll-8l.oct > doubleroll-8l.bin

kaleid-e.bin: kaleid-e.pal kaleid.pal
	pdp8v/asm/assemble -pal kaleid-e.pal kaleid-e.obj > kaleid-e.lis
	pdp8v/asm/link -o kaleid-e.oct kaleid-e.obj > kaleid-e.map
	pdp8v/asm/octtobin < kaleid-e.oct > kaleid-e.bin

kaleid-i.bin: kaleid-i.pal kaleid.pal
	pdp8v/asm/assemble -pal kaleid-i.pal kaleid-i.obj > kaleid-i.lis
	pdp8v/asm/link -o kaleid-i.oct kaleid-i.obj > kaleid-i.map
	pdp8v/asm/octtobin < kaleid-i.oct > kaleid-i.bin

