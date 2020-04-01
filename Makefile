CC=riscv64-unknown-elf-gcc-8.2.0
QEMU=qemu-system-riscv64
LLC=llc
OBJCOPY=llvm-objcopy
LDS=lds/output.ld
LIBS=-lc -lgcc 
CIC=-Iobjs/
CFLAGS=-Wall -O0 -g -T$(LDS) -mabi=lp64d -march=rv64g
CFLAGS+=$(CIC)
CFLAGS+=-ffreestanding -nostartfiles -nostdinc -static -mcmodel=medany
CFLAGS_PRINTF=$(CIC)
CFLAGS_PRINTF+=-ffreestanding -nostartfiles -static -mcmodel=medany
ASM=$(wildcard src/asm/*.S)
ALL_ZIGS=$(wildcard src/*.zig)
ZIGS=src/main.zig
ZIG=zig
ZIG_TARGET=riscv64-freestanding-none
ZIG_UART=src/uart.zig
BUILD_OPTS=--emit llvm-ir -isystem src/
#BUILD_OPTS+=--release-safe
BUILD_OPTS+=-target $(ZIG_TARGET) --output-dir $(OUTPUT_DIR) --name os 
BUILD_OPTS+=-fPIC
BUILD_OPTS+=$(ZIGS)
UART_OPTS=--emit llvm-ir
UART_OPTS+=-target $(ZIG_TARGET) --output-dir $(OUTPUT_DIR) --name uart
UART_OPTS+=-fPIC
UART_OPTS+=$(ZIG_UART)
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
QEMU_ARGS=-M virt -m 6M -bios none -serial mon:stdio #-smp 2
UART_O=objs/uart.o
UART_LL=objs/uart.ll
UART_S=objs/uart.s
PRINTF_C=src/printf.c
PRINTF_O=objs/printf.o

all: $(OUT) $(OUT_BIN)


$(OUT): $(OUTPUT_S) $(ASM) $(CLEAR_O) $(UART_S) $(PRINTF_O) Makefile
	$(CC) $(CFLAGS) -o $@ $(ASM) $(PRINTF_O) $(OUTPUT_S) $(CLEAR_O) $(UART_S) $(LIBS)

$(OUT_BIN): $(OUT)
	$(OBJCOPY) -O binary $(OUT) $(OUT_BIN)

$(OUTPUT_LL): $(ALL_ZIGS) $(PRINTF_O) Makefile
	$(ZIG) build-lib $(BUILD_OPTS)

$(OUTPUT_S): $(OUTPUT_LL)
	$(LLC) $(LLC_OPTS) objs/os.ll -o objs/os.s

$(CLEAR_O): $(CLEAR_C) Makefile
	$(CC) -o $(CLEAR_O) -c $(CLEAR_C)

$(UART_LL): $(ALL_ZIGS) Makefile 
	$(ZIG) build-lib $(UART_OPTS)

$(UART_S): $(UART_LL)
	$(LLC) $(LLC_OPTS) objs/uart.ll -o objs/uart.s

$(UART_O): $(ALL_ZIGS) Makefile 
	$(ZIG) build-lib $(UART_OPTS)

$(PRINTF_O): $(PRINTF_C) $(UART_S) Makefile 
	$(CC) $(CFLAGS_PRINTF) -o $(PRINTF_O) -c $(PRINTF_C)

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
	rm -f $(UART_O)
	rm -f $(OUT_IMG)
	rm -f $(OUT_BIN)
	rm -f $(wildcard $(OUTPUT_DIR)libuart.a)
	rm -f $(wildcard $(OUTPUT_DIR)os.*)
	rm -f $(wildcard $(OUTPUT_DIR)uart.*)
	rm -f $(wildcard $(OUTPUT_DIR)*)
