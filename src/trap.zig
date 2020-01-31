const uart_lib = @import("uart.zig").UART;
// const uart_base_addr: usize = 0x10000000;

export fn m_trap(epc: usize, tval: usize, mcause: usize, hart: usize, status: usize, frame: usize) usize {
    const uart = uart_lib.MakeUART();
    uart.puts("Trap has been triggered!\n");
    //Check if it is an interrupt or not
    var is_async: bool = (((mcause >> 63) & 0b1) == 1);
    //Exception code
    var cause_num = mcause & 0xfff;
    if (is_async) {
        uart.puts("Interrupt!\n");
    } else {
        switch (cause_num) {
            11 => {
                uart.puts("ecall from m-mode\n");
            },
            else => {
                uart.puts("other\n");
            },
        }
    }

    //For now just return to the next instruction
    return epc + 4;
}

pub fn emptyfunc() void {}

/// TrapFrame
/// @brief trap frame for storing context during trap handling
pub const TrapFrame = struct {
    regs: [32]usize, //registers
    fregs: [32]usize, //fregisters
    satp: usize, //SATP ?
    trap_stack: usize, //pointer to stack for trap handling
    hartid: usize, //hartid

    pub fn makeTrapFrame() TrapFrame {
        return TrapFrame{
            .regs = [_]usize{0} ** 32,
            .fregs = [_]usize{0} ** 32,
            .satp = 0,
            .trap_stack = 0,
            .hartid = 0,
        };
    }
};

// Declaration of Trap Frame
pub var KERNEL_TRAP_FRAME = TrapFrame.makeTrapFrame();
