const proc = @import("process.zig"); 
const trap = @import("trap.zig");
const LinkedList = @import("linkedlist.zig").LinkedList;

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

    //I get an instruction page fault if I don't have this print statement here for some reason
    c.printf(c"addr of process list: %08x\n", @ptrToInt(&proc.PROCESS_LIST));

    var p = proc.PROCESS_LIST[0];
    // var p = proc.pop_front();
    // var p = proc.PROCESS_LIST.*.front(); 
    // var p = proc.PROCESS_LIST.first.?.*.data;
    // var p = proc.PROCESS_LIST.pop_front();
    // proc.PROCESS_LIST.push_back(p);
    // c.printf(c"Address of process info: %x\n", @ptrToInt(p));
    // trap.printTrapFrame(p.*.get_frame_address());
    switch (p.?.get_state()) {
        proc.ProcessState.Running => {
            frame_addr = p.?.get_frame_address(); 
            // c.printf(c"SCHED FRAME ADDR: %x\n", frame_addr);
            mepc = p.?.get_program_counter(); 
            satp = p.?.get_table_address() >> 12; 
            pid = p.?.get_pid(); 
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