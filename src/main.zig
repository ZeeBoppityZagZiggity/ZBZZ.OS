const uart_lib = @import("uart.zig").UART;
const trap = @import("trap.zig");
const cpu = @import("cpu.zig");
// const uart_base_addr: usize = 0x10000000;

export fn kinit() void {
    trap.emptyfunc();
    const x = 0;
    // uart.uart_init();
    const uart = uart_lib.MakeUART();
    uart.puts("Uart Initd\n");

    //Create Trap Frame
    const tf_ptr1 = @ptrCast(*const u8, &trap.KERNEL_TRAP_FRAME);
    const tf_ptr = @ptrToInt(tf_ptr1);
    cpu.mscratch_write(tf_ptr);
    // var rx: ?u8 = null;
    // while (true) {
    //     // rx = uart.read();
    //     // if (rx != null) {
    //     //     uart.put(rx.?);
    //     // }
    // } //stay in zig for now
}

export fn kmain() void {
    const uart = uart_lib.MakeUART();
    uart.puts("Entered Main\n");
    asm volatile ("ecall");
    // while (true) {}
    // var a: u8 = 30;
    // var b: u8 = 35;
    // var c: u8 = cpu.asm_add(a, b);
    // uart.put(c);
    // var x: usize = 0x10000000;
    // cpu.mscratch_write(x);
    var rx: ?u8 = null;
    while (true) {
        rx = uart.read();
        if (rx != null) {
            uart.put(rx.?);
        }
    } //stay in zig for now
}
