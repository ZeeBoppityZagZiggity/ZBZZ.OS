const uart_lib = @import("uart.zig").UART;
const trap = @import("trap.zig");
const cpu = @import("cpu.zig");
const plic = @import("plic.zig");
const c = @cImport({
    @cInclude("printf.h");
    });

//const fmt = @import("std").fmt;
// const uart_base_addr: usize = 0x10000000;

export fn kinit() void {
    trap.emptyfunc();
    const x = 0;
    // uart.uart_init();
    const uart = uart_lib.MakeUART();
    uart.puts("Uart Initd\n");

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

export fn kmain() void {
    //Reinit uart
    const uart = uart_lib.MakeUART();
    uart.puts("Entered Main\n");
    var a: u8 = 0x61; 
   // var str: [32:0]u8 = undefined; 
   // cpu.itoa(u8, a, &str); 
   // uart.puts(&str);
    c.printf("zig is awesome\n");
    while(true) {

    }
    //ecall to test trapping
    // asm volatile ("ecall");
    var rx: ?u8 = null;
    // while (true) {
    //     // rx = uart.read();
    //     // if (rx != null) {
    //     //     uart.put(rx.?);
    //     // }
    // } //stay in zig for now
}
