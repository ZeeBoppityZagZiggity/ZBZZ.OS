// const uart_lib = @import("uart.zig").UART;
const plic = @import("plic.zig");
const string_lib = @import("string.zig").String;
const page = @import("page.zig");
const kmem = @import("kmem.zig");
const timer = @import("timer.zig");
// const uart_base_addr: usize = 0x10000000;

extern fn makeUART() void;
extern fn put(din: u8) void; 
extern fn puts(din: [*]const u8) void;
extern fn print(din: [*]u8) void; 
extern fn read() u8; 

export fn m_trap(epc: usize, tval: usize, mcause: usize, hart: usize, status: usize, frame: usize) usize {
    // const uart = uart_lib.MakeUART();
    // uart.puts("Trap has been triggered!\n");
    //Check if it is an interrupt or not
    var is_async: bool = (((mcause >> 63) & 0b1) == 1);
    //Exception code
    var cause_num = mcause & 0xfff;
    var mepc = epc + 4;
    if (is_async) {
        // uart.puts("Interrupt!\n");
        switch (cause_num) {
            0 => { //User software interrupt
                puts(c"User software interrupt\n");
            },
            1 => {
                puts(c"Supervisor Software Intterupt\n");
            },
            7 => {
                puts(c"Timer Interrupt\n");
                timer.set_timer_ms(0, 1000);
                mepc = epc;
            },
            11 => { //Machine External Interrupt
                // Get id from PLIC
                const claim_id: u32 = plic.claim();
                switch (claim_id) {
                    10 => { //UART
                        var rx: u8 = read();
                        switch (rx) {
                            8, 127 => {
                                put(8);
                                put(' ');
                                put(8);
                            },
                            10, 13 => {
                                puts(c"\r\n");
                            },
                            else => {
                                put(rx);
                            },
                        }
                    },
                    else => {},
                }
                plic.complete(claim_id);
                mepc = epc;
            },
            else => {
                puts(c"Non-external interrupt\n");
            },
        }
    } else {
        switch (cause_num) {
            0 => {
                puts(c"Instruction address misaligned!\n");
            },
            1 => {
                puts(c"Instruction Access fault\n");
            },
            2 => {
                puts(c"Illegal Instruction\n");
            },
            3 => {
                puts(c"Breakpoint\n");
            },
            4 => {
                puts(c"Load Address Misaligned\n");
            },
            5 => {
                puts(c"Load Access Fault\n");
                // const epcstr = string_lib.dword2hex(epc);
                // puts(epcstr);
                // puts(" => ");
                // var phys = page.virt_to_phys(@intToPtr(*page.Table, @ptrToInt(kmem.get_page_table())), epc);
                // puts(string_lib.dword2hex(phys));
                // asm volatile ("j .");
            },
            6 => {
                puts(c"Store/AMO address misaligned\n");
            },
            7 => {
                puts(c"Store/AMO Access Fault\n");
                // asm volatile("j .");
            },
            8 => {
                puts(c"Ecall from U-mode\n");
            },
            9 => {
                puts(c"Ecall from S-mode\n");
            },
            10 => {
                puts(c"( ͡° ͜ʖ ͡°)\n");
            },
            11 => {
                puts(c"ecall from m-mode\n");
                asm volatile ("j .");
            },
            //Page Faults
            12 => {
                // Instruction page fault
                puts(c"Instruction page fault CPU 0 (this is hardcoded btw)\n");
                // const epcstr = string_lib.dword2hex(epc);
                // uart.puts(epcstr);
                // uart.puts(" => ");
                // var phys = page.virt_to_phys(@intToPtr(*page.Table, @ptrToInt(kmem.get_page_table())), epc);
                // uart.puts(string_lib.dword2hex(phys));
                // asm volatile ("j .");
                // mepc += 4;
            },
            13 => {
                //Load page fault
                puts(c"Load Page Fault CPU 0 (this is hardcoded btw)\n");
                // mepc += 4;
            },
            15 => {
                //Store page fault
                puts(c"Store Page Fault CPU 0 (this is hardcoded btw)\n");
                // mepc += 4;
            },
            else => {
                puts(c"other\n");
            },
        }
    }

    //For now just return to the next instruction
    return mepc;
}

pub fn emptyfunc() void {}

/// TrapFrame
/// @brief trap frame for storing context during trap handling
pub const TrapFrame = packed struct {
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
