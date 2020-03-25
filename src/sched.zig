const proc = @import("process.zig"); 

const c = @cImport({
    @cDefine("_NO_CRT_STDIO_INLINE", "1");
    @cInclude("printf.h");
    });

pub const sched_struct = packed struct {
    frame: usize, 
    mepc: usize, 
    satp: usize,
};

pub fn schedule() sched_struct {
    var frame_addr: usize = 0; 
    var mepc: usize = 0;
    var satp: usize = 0; 
    var pid: usize = 0; 

    var p = proc.PROCESS_LIST[0]; 
    switch (p.get_state()) {
        proc.ProcessState.Running => {
            frame_addr = p.get_frame_address(); 
            mepc = p.get_program_counter(); 
            satp = p.get_table_address() >> 12; 
            pid = p.get_pid(); 
        },
        else => {

        }
    }
    c.printf(c"Scheduling %d\n", pid); 
    if (frame_addr != 0) {
        if (satp != 0) {
            return sched_struct {
                .frame = frame_addr, 
                .mepc = mepc, 
                .satp = (8 << 60) | (pid << 44) | satp,
            };
        } else {
            return sched_struct {
                .frame = frame_addr,
                .mepc = mepc, 
                .satp = 0,
            };
        }
    }
    return sched_struct {
        .frame = 0, .mepc = 0, .satp = 0,
    };
}