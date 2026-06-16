
ASMDIR := ../ccode/pdp8v/asm

doubleroll.bin: doubleroll.asm
	$(ASM)/assemble doubleroll.asm doubleroll.obj > doubleroll.lis
	$(ASM)/link -o doubleroll.oct doubleroll.obj > doubleroll.map
	$(ASM)/octtobin < doubleroll.oct > doubleroll.bin

kaleid-e.bin: kaleid-e.pal kaleid.pal
	$(ASM)/assemble -pal kaleid-e.pal kaleid-e.obj > kaleid-e.lis
	$(ASM)/link -o kaleid-e.oct kaleid-e.obj > kaleid-e.map
	$(ASM)/octtobin < kaleid-e.oct > kaleid-e.bin

kaleid-i.bin: kaleid-i.pal kaleid.pal
	$(ASM)/assemble -pal kaleid-i.pal kaleid-i.obj > kaleid-i.lis
	$(ASM)/link -o kaleid-i.oct kaleid-i.obj > kaleid-i.map
	$(ASM)/octtobin < kaleid-i.oct > kaleid-i.bin

