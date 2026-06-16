
ASMDIR := ../ccode/pdp8v/asm

doubleroll.bin: doubleroll.asm
	$(ASMDIR)/assemble doubleroll.asm doubleroll.obj > doubleroll.lis
	$(ASMDIR)/link -o doubleroll.oct doubleroll.obj > doubleroll.map
	$(ASMDIR)/octtobin < doubleroll.oct > doubleroll.bin

kaleid-e.bin: kaleid-e.pal kaleid.pal
	$(ASMDIR)/assemble -pal kaleid-e.pal kaleid-e.obj > kaleid-e.lis
	$(ASMDIR)/link -o kaleid-e.oct kaleid-e.obj > kaleid-e.map
	$(ASMDIR)/octtobin < kaleid-e.oct > kaleid-e.bin

kaleid-i.bin: kaleid-i.pal kaleid.pal
	$(ASMDIR)/assemble -pal kaleid-i.pal kaleid-i.obj > kaleid-i.lis
	$(ASMDIR)/link -o kaleid-i.oct kaleid-i.obj > kaleid-i.map
	$(ASMDIR)/octtobin < kaleid-i.oct > kaleid-i.bin

