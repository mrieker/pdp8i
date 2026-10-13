VFILES := $(shell ./vfilelist.sh)

BOOT.BIN.gz: pdp8i.runs/impl_1/myboard_wrapper.bit
	./makebootgz.sh

pdp8i.runs/impl_1/myboard_wrapper.bit: $(VFILES)
	time -p ./makebitfile.sh

../kicads/console/console.v:
	make -C ../verisim $@

../kicads/extarctrl/extarctrl.v:
	make -C ../verisim $@

../kicads/extardata/extardata.v:
	make -C ../verisim $@

../kicads/extmemory/extmemory.v:
	make -C ../verisim $@

../kicads/procalu/procalu.v:
	make -C ../verisim $@

../kicads/procreg/procreg.v:
	make -C ../verisim $@

../kicads/procseq/procseq.v:
	make -C ../verisim $@
