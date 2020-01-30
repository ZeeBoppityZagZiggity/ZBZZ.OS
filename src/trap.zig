const uart = @import("uart.zig");
const uart_base_addr: usize = 0x10000000;

export fn m_trap(epc: usize, tval: usize, cause: usize, hart: usize, status: usize, frame: usize) usize {
    uart.puts("Trap has been triggered!\n");
    return epc;
}

pub fn emptyfunc() void {}
