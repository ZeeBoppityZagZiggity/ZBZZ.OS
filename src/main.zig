const uart = @import("uart.zig");
const trap = @import("trap.zig");
// const uart_base_addr: usize = 0x10000000;

export fn kinit() void {
    trap.emptyfunc();
    const x = 0;
    uart.uart_init();
    // const uart = uart_lib.MakeUART(uart_base_addr);
    uart.puts("Uart Initd\n");
    // var rx: ?u8 = null;
    // while (true) {
    //     // rx = uart.read();
    //     // if (rx != null) {
    //     //     uart.put(rx.?);
    //     // }
    // } //stay in zig for now
}

export fn kmain() void {
    uart.puts("Entered Main\n");
    asm volatile ("ecall");
    // while (true) {}
    var rx: ?u8 = null;
    while (true) {
        rx = uart.read();
        if (rx != null) {
            uart.put(rx.?);
        }
    } //stay in zig for now
}
