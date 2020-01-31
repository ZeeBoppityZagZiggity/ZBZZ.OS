const uart_lib = @import("uart.zig").UART;
const uart_base_addr: usize = 0x10000000;

const trap_lib = @import("trap.zig");

export fn kinit() void {
    const x = 0;

    const uart = uart_lib.MakeUART(uart_base_addr);
    uart.puts("Before Trap\n");
    var dont_toss_ktrap = trap_lib.ktrap(99999999, 0, 0, 0, 0);
    uart.puts("Post Trap\n");

    kmain();
}

export fn kmain() void {
    const x = 0;

    // Trying to force a trap for test purposes
    const v = @intToPtr(*volatile u64, 0x1);
    v.* = 1;

    const uart = uart_lib.MakeUART(uart_base_addr);
    var rx: ?u8 = null;
    while (true) {
        rx = uart.read();
        if (rx != null) {
            uart.put(rx.?);
        }
    } //stay in zig for now
}