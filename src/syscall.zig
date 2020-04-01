const TrapFrame = @import("trap.zig").TrapFrame; 

const c = @cImport({
    @cDefine("_NO_CRT_STDIO_INLINE", "1");
    @cInclude("printf.h");
    });

pub fn do_syscall(mepc: usize, frame: usize) usize {
    var syscall_num: usize = @intToPtr(*TrapFrame, frame).*.regs[10]; 

    switch (syscall_num) {
        0 => {
            c.printf(c"Kill Process\n");
            return mepc + 4; 
        }, 
        1 => {
            c.printf(c"Test Syscall\n");
            return mepc + 4; 
        }, 
        else => {
            c.printf(c"Unknown syscall number %d\n", syscall_num);
            return mepc + 4;
        }
    }
}