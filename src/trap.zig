const uart_lib = @import("uart.zig").UART;
const plic = @import("plic.zig");
// const uart_base_addr: usize = 0x10000000;

export fn m_trap(epc: usize, tval: usize, mcause: usize, hart: usize, status: usize, frame: usize) usize {
    const uart = uart_lib.MakeUART();
    // uart.puts("Trap has been triggered!\n");
    //Check if it is an interrupt or not
    var is_async: bool = (((mcause >> 63) & 0b1) == 1);
    //Exception code
    var cause_num = mcause & 0xfff;
    var mepc = epc + 4;
    if (is_async) {
        // uart.puts("Interrupt!\n");
        switch (cause_num) {
            0 => {//User software interrupt 
                uart.puts("User software interrupt\n");
            },
            1 => {
                uart.puts("Supervisor Software Intterupt\n");
            },
            11 => { //Machine External Interrupt
                // Get id from PLIC
                const claim_id: u32 = plic.claim();
                switch (claim_id) {
                    10 => { //UART 
                        var rx: ?u8 = uart.read();
                        switch(rx.?) {
                            8, 127 => {
                                uart.put(8);
                                uart.put(' ');
                                uart.put(8);
                            }, 
                            10, 13 => {
                                uart.puts("\r\n");
                            }, 
                            else => {
                                uart.put(rx.?);
                            }
                        }
                    },
                    else => {

                    }
                }
                plic.complete(claim_id); 
                mepc = epc;
            },
            else => {
                uart.puts("Non-external interrupt\n");
            }
        }

    } else {
        switch (cause_num) {
            0 => {
                uart.puts("Instruction address misaligned!\n");
            },
            1 => {
                uart.puts("Instruction Access fault\n");
            },
            2 => {
                uart.puts("Illegal Instruction\n");
            },
            3 => {
                uart.puts("Breakpoint\n");
            },
            4 => {
                uart.puts("Load Address Misaligned\n");
            },
            5 => {
                uart.puts("Load Access Fault\n");
                asm volatile("j .");
            },
            6 => {
                uart.puts("Store/AMO address misaligned\n");
            }, 
            7 => {
                uart.puts("Store/AMO Access Fault\n");
                // asm volatile("j .");
            },
            8 => {
                uart.puts("Ecall from U-mode\n");
            },
            9 => {
                uart.puts("Ecall from S-mode\n");
            },
            10 => {
                uart.puts("( ͡° ͜ʖ ͡°)\n");
            },
            11 => {
                uart.puts("ecall from m-mode\n");
                // asm volatile("j .");
            },
            //Page Faults
            12 => {
                // Instruction page fault
                uart.puts("Instruction page fault CPU 0 (this is hardcoded btw)\n");
                mepc += 4;
            },
            13 => {
                //Load page fault
                uart.puts("Load Page Fault CPU 0 (this is hardcoded btw)\n");
                mepc += 4;
            },
            15 => {
                //Store page fault
                uart.puts("Store Page Fault CPU 0 (this is hardcoded btw)\n");
                mepc += 4;
            },
            else => {
                uart.puts("other\n");
            },
        }
    }

    //For now just return to the next instruction
    return mepc;
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
