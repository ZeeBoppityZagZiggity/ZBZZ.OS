const uart_lib = @import("uart.zig").UART;
const trap = @import("trap.zig");
const cpu = @import("cpu.zig");
const plic = @import("plic.zig");
const fmt = @import("std").fmt;
const page = @import("page.zig");
// const uart_base_addr: usize = 0x10000000;

// pub var HEAP_START: usize = 0;
// pub var HEAP_SIZE: usize = 0;

export fn kinit() void {
    trap.emptyfunc();
    const x = 0;
    // uart.uart_init();
    const uart = uart_lib.MakeUART();
    uart.puts("Uart Initd\n");

    page.init();
    uart.puts("Page Table Initd\n");

    // Set up the PLIC
    plic.enable(10);
    plic.set_priority(10, 1);
    plic.set_threshold(0);

    //Create Trap Frame Pointer
    const tf = @ptrCast(*const u8, &trap.KERNEL_TRAP_FRAME);
    const tf_ptr = @ptrToInt(tf);
    //Store it in mscratch
    cpu.mscratch_write(tf_ptr);
}

//This stupid function exists because Zig's compiler has a (known) bug
//that makes referencing extern variables impossible(?)
export fn kheap(a1: usize, a2: usize) void {
    page.HEAP_START = a1;
    page.HEAP_SIZE = a2;
}

export fn kmain() void {
    //Reinit uart
    const uart = uart_lib.MakeUART();
    uart.puts("Entered Main\n");
    // var a: u8 = 0x61;
    // const b = page.addr2hex(&a);
    // uart.puts(b);
    // var str: [32:0]u8 = undefined;
    // cpu.itoa(u8, a, &str);
    // uart.puts(&str);
    // while (true) {}
    // page.printPageTable();
    // uart.puts("\n");
    var ptr: *u8 = page.zalloc(10);
    uart.puts("Alloc'd\n");
    // page.printPageTable();
    page.printPageContents(ptr);
    // uart.puts("\n");
    page.dealloc(ptr);
    uart.puts("Dealloc'd\n");
    // page.printPageTable();
    //ecall to test trapping
    // asm volatile ("ecall");
    // var rx: ?u8 = null;
    // while (true) {
    //     // rx = uart.read();
    //     // if (rx != null) {
    //     //     uart.put(rx.?);
    //     // }
    // } //stay in zig for now
}
