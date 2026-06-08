VFILES := $(shell ./vfilelist.sh)

BOOT.BIN.gz: pdp8i.runs/impl_1/myboard_wrapper.bit
	./makebootgz.sh

pdp8i.runs/impl_1/myboard_wrapper.bit: $(VFILES)
	time -p ./makebitfile.sh
