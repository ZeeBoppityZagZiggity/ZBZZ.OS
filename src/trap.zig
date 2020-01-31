const uart_lib = @import("uart.zig").UART;
const uart_base_addr: usize = 0x10000000;

pub const TrapFrame = struct {
    regs: [32]usize,
    fregs: [32]usize,
    satp: usize,
    trap_stack: usize,
    hartid: usize,

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

pub const KERNEL_TRAP_FRAME = TrapFrame.makeTrapFrame();

pub export fn ktrap(epc: usize, tval: usize, cause: usize, hart: usize, status: usize, frame: usize) usize {
    const uart = uart_lib.MakeUART(uart_base_addr);
    // Dummy Function to ensure Zig does not optimize it out
    if (epc == 99999999){
        return 0;
    }

    var async_intr: bool = false;
    async_intr = !!(((cause >> 63) & 1) == 1);

    const cause_num = cause & 0xfff;

    var return_pc = epc;

    if (async_intr) {
        const cap = switch (cause_num) {
            3 => {
                uart.puts("Machine Software Interrupt.\n");
            },
            7 => {
                uart.puts("Caught dat 7\n");
                var mtimecomp = @intToPtr(*volatile u64, 0x02004000);
                const mtime = @intToPtr(*volatile u64, 0x0200bff8);
                mtimecomp.* = mtime.* + 10000000;
            },
            11 => {
                uart.puts("Machine External Interrupt.\n");
            },
            else => {
                uart.puts("Unhandled async interrupt!!!\n");
            },
        };
    } else {
        const cap = switch (cause_num) {
            2 => {
                uart.puts("Illegal instruction!!!\n");
            },
            8 => {
                uart.puts("Environment call from user mode.\n");
                return_pc += 4;
            },
            9 => {
                uart.puts("Environment call from super mode.\n");
                return_pc += 4;
            },
            11 => {
                uart.puts("Environment call from machine mode!!! Irrecoverable.\n");
            },
            12 => {
                uart.puts("Instruction Page fault\n");
                return_pc += 4;
            },
            13 => {
                uart.puts("Load Page fault\n");
                return_pc += 4;
            },
            15 => {
                uart.puts("Store Page fault\n");
                return_pc += 4;
            },
            else => {
                uart.puts("Unhandled sync interrupt!!!\n");
            },
        };
    }

    return return_pc + 4; //TODO THIS IS TEMPORARY AND WILL NOT ALWAYS BE +4!!!
}
