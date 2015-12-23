all: rf.hex

%.hex: %.asm
	gpasm -o $@ $<
