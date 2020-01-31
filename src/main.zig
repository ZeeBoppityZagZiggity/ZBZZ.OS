const uart_lib = @import("uart.zig").UART;
const uart_base_addr: usize = 0x10000000;
const trap_lib = @import("trap.zig");
const cpu = @import("cpu.zig");

export fn kinit() void {
    const x = 0;

    const uart = uart_lib.MakeUART(uart_base_addr);
    
    var dont_toss_ktrap = trap_lib.ktrap(99999999, 0, 0, 0, 0,0);

    //Create Trap Frame
    const tf_ptr1 = @ptrCast(*const u8, &trap_lib.KERNEL_TRAP_FRAME);
    const tf_ptr = @ptrToInt(tf_ptr1);
    cpu.mscratch_write(tf_ptr);
}

export fn kmain() void {
    const x = 0;

    // Trying to force a trap for test purposes
    asm volatile ("ecall");

    const uart = uart_lib.MakeUART(uart_base_addr);
    var rx: ?u8 = null;
    while (true) {
        rx = uart.read();
        if (rx != null) {
            uart.put(rx.?);
        }
    } //stay in zig for now
}