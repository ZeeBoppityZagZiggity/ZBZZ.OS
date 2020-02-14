CC=riscv64-unknown-elf-gcc-8.2.0
QEMU=qemu-system-riscv64
LLC=llc
OBJCOPY=llvm-objcopy
LDS=lds/output.ld
LIBS=-lc -lgcc 
CFLAGS=-Wall -O0 -g -T$(LDS) -mabi=lp64d -march=rv64gc
CFLAGS+=-ffreestanding -nostartfiles -nostdinc -static -mcmodel=medany
ASM=$(wildcard src/asm/*.S)
ALL_ZIGS=$(wildcard src/*.zig) 
ZIGS=src/main.zig
ZIG=zig
ZIG_TARGET=riscv64-freestanding-none
BUILD_OPTS=--emit llvm-ir
#BUILD_OPTS+=--release-safe
BUILD_OPTS+=-target $(ZIG_TARGET) --output-dir $(OUTPUT_DIR) --name os 
BUILD_OPTS+=-fPIC
BUILD_OPTS+=$(ZIGS)
LLC_OPTS=-O0 --relocation-model=pic --threads=8
LLC_OPTS+=--mcpu=generic-rv64 --mattr=+64bit,+a,+f,+d,+m
OUTPUT_DIR=objs/
OUTPUT_S=objs/os.s
OUTPUT_LL=objs/os.ll
CLEAR_C=src/clear.c
CLEAR_O=objs/clear.o
OUT=os.elf
OUT_BIN=os.bin
OUT_IMG=os.img
QEMU_ARGS=-smp 2 -M virt -m 6M -bios none -serial mon:stdio

all: $(OUT) $(OUT_BIN)


$(OUT): $(OUTPUT_S) $(ASM) $(CLEAR_O) Makefile
	$(CC) $(CFLAGS) -o $@ $(ASM) $(OUTPUT_S) $(CLEAR_O) $(LIBS)

$(OUT_BIN): $(OUT)
	$(OBJCOPY) -O binary $(OUT) $(OUT_BIN)

$(OUTPUT_LL): $(ALL_ZIGS) Makefile
	$(ZIG) build-lib $(BUILD_OPTS)

$(OUTPUT_S): $(OUTPUT_LL)
	$(LLC) $(LLC_OPTS) objs/os.ll -o objs/os.s

$(CLEAR_O): $(CLEAR_C) Makefile
	$(CC) -o $(CLEAR_O) -c $(CLEAR_C)

upload: $(OUT_BIN)
	./kflash.py -p /dev/ttyUSB0 -B maixduino $(OUT_BIN)

rung: $(OUT)
	$(QEMU) -S -s -nographic $(QEMU_ARGS) -kernel $(OUT)

runcon: $(OUT)
	$(QEMU) -nographic $(QEMU_ARGS) -kernel $(OUT)

run: $(OUT)
	$(QEMU) $(QEMU_ARGS) -kernel $(OUT)


.PHONY: clean

clean:
	rm -f $(OUT)
	rm -f $(CLEAR_O)
	rm -f $(OUT_IMG)
	rm -f $(OUT_BIN)
	rm -f $(wildcard $(OUTPUT_DIR)os.*)
