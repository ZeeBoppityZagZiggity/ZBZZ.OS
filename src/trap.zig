// const uart_lib = @import("uart.zig").UART;
const plic = @import("plic.zig");
const string_lib = @import("string.zig").String;
const page = @import("page.zig");
const kmem = @import("kmem.zig");
const timer = @import("timer.zig");
const proc = @import("process.zig");
const sched = @import("sched.zig");
const sys = @import("syscall.zig");
const cpu = @import("cpu.zig");
const virtio = @import("virtio.zig");
// const uart_base_addr: usize = 0x10000000;

const c = @cImport({
    @cDefine("_NO_CRT_STDIO_INLINE", "1");
    @cInclude("printf.h");
});

extern fn makeUART() void;
extern fn put(din: u8) void;
extern fn puts(din: [*]const u8) void;
extern fn print(din: [*]u8) void;
extern fn read() u8;
extern fn switch_to_user(frame: usize, mepc: usize, satp: usize) noreturn;

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
                c.printf(c"User software interrupt\n");
            },
            1 => {
                c.printf(c"Supervisor Software Intterupt\n");
            },
            7 => {
                // cpu.mscratch_write(@ptrToInt(&KERNEL_TRAP_FRAME));
                c.printf(c"Timer Interrupt\n");
                // put process into proc list

                // c.printf(c"addr of process list: %08x\n", @ptrToInt(&proc.PROCESS_LIST));
                // asm volatile("j .");
                var s = sched.schedule();
                timer.set_timer_ms(0, 1000);
                switch_to_user(s.frame, s.mepc, s.satp);
                // switch_to_user(frame, epc, @intToPtr(*TrapFrame, frame).*.satp);
                // mepc = epc;
            },
            11 => { //Machine External Interrupt
                // Get id from PLIC
                const claim_id: u32 = plic.claim();
                switch (claim_id) {
                    1...8 => {
                        virtio.handle_interrupt(interrupt);
                    },
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
                c.printf(c"Non-external interrupt\n");
            },
        }
    } else {
        switch (cause_num) {
            0 => {
                c.printf(c"Instruction address misaligned!\n");
            },
            1 => {
                c.printf(c"Instruction Access fault\n");
            },
            2 => {
                c.printf(c"Illegal Instruction\n");
                asm volatile ("j .");
            },
            3 => {
                c.printf(c"Breakpoint\n");
            },
            4 => {
                c.printf(c"Load Address Misaligned\n");
            },
            5 => {
                c.printf(c"Load Access Fault\n");
                // c.printf(c"%x\n", @intToPtr(*TrapFrame, frame).*.regs[1]);
                c.printf(c"MEPC: %x\n", epc);
                printTrapFrame(frame);
                // const epcstr = string_lib.dword2hex(epc);
                // puts(epcstr);
                // puts(" => ");
                // var phys = page.virt_to_phys(@intToPtr(*page.Table, @ptrToInt(kmem.get_page_table())), epc);
                // puts(string_lib.dword2hex(phys));
                asm volatile ("j .");
            },
            6 => {
                c.printf(c"Store/AMO address misaligned\n");
            },
            7 => {
                c.printf(c"Store/AMO Access Fault\n");
                // asm volatile("j .");
            },
            8 => {
                // c.printf(c"Ecall from U-mode\n");
                mepc = sys.do_syscall(epc, frame);
            },
            9 => {
                c.printf(c"Ecall from S-mode\n");
            },
            10 => {
                c.printf(c"( ͡° ͜ʖ ͡°)\n");
            },
            11 => {
                c.printf(c"ecall from m-mode\n");
                // asm volatile ("j .");
            },
            //Page Faults
            12 => {
                // Instruction page fault
                c.printf(c"Instruction page fault CPU 0 (this is hardcoded btw)\n");
                // c.printf(c"Virt addr: %x\nPhys addr: %x\n", epc, page.virt_to_phys(@intToPtr(*page.Table, @ptrToInt(kmem.get_page_table())), epc));
                // const epcstr = string_lib.dword2hex(epc);
                // uart.puts(epcstr);
                // uart.puts(" => ");
                // var phys = page.virt_to_phys(@intToPtr(*page.Table, @ptrToInt(kmem.get_page_table())), epc);
                // uart.puts(string_lib.dword2hex(phys));
                asm volatile ("j .");
                // mepc += 4;
            },
            13 => {
                //Load page fault
                c.printf(c"Load Page Fault CPU 0 (this is hardcoded btw)\n");
                asm volatile ("j .");
                // mepc += 4;
            },
            15 => {
                //Store page fault
                c.printf(c"Store Page Fault CPU 0 (this is hardcoded btw)\n");
                // mepc += 4;
            },
            else => {
                c.printf(c"other\n");
            },
        }
    }

    //For now just return to the next instruction
    return mepc;
}

pub fn emptyfunc() void {}

pub fn printTrapFrame(frame: usize) void {
    var fptr = @intToPtr(*TrapFrame, frame);
    var i: usize = 0;
    while (i < 32) {
        c.printf(c"x%d: %08x ", i, fptr.*.regs[i]);
        if ((i + 1) % 4 == 0) {
            c.printf(c"\n");
        }
        i += 1;
    }
    c.printf(c"SATP: %x\n", fptr.*.satp);
    c.printf(c"TRAP STACK: %x\n", fptr.*.trap_stack);
}

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
