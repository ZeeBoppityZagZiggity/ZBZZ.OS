const cpu = @import("cpu.zig");
const page = @import("page.zig");
const trap = @import("trap.zig");
const kmem = @import("kmem.zig");
const LinkedList = @import("linkedlist.zig").LinkedList;

const c = @cImport({
    @cDefine("_NO_CRT_STDIO_INLINE", "1");
    @cInclude("printf.h");
    });

extern fn make_syscall(a: usize) usize;

//Number of pages (4096 bytes) for a process' stack to have
const STACK_PAGES: usize = 2;

//We want to adjust the stack to be at the bottom of the memory allocation
//regardless of where it is on the kernel heap.
const STACK_ADDR: usize  = 0x100000000;

// All processes will have a defined starting point in virtual memory.
const PROCESS_STARTING_ADDR: usize = 0x20000000;

// pub const ProcNode = packed struct {
//     p: Process,
//     prev: ?*ProcNode, 
//     next: ?*ProcNode,
// };

// pub const ProcList = packed struct {
//     first: ?*ProcNode, 
//     last: ?*ProcNode, 

//     pub fn initProcList() ProcList {
//         var ret_list = ProcList{
//             .first = null,
//             .last = null
//         }; 
//         return ret_list;
//     }



// };

//TODO: MAKE A List TYPE DATA STRUCTURE FOR THE PROCESSS LIST
//var PROCESS_LIST: List = undefined;

//Ooookay, we've got this weird bug where if PROCESS_LIST isnt a statically 
//Sized array, it has a different address depending on where it is referenced from. 
//So for now, we can only have up to 32 processes. 
pub var PROCESS_LIST: [32]?Process = [1]?Process{null} ** 32;
// pub var PROCESS_LIST = LinkedList(*Process) {
//     .first = null,
//     .last = null,
//     .len = 0,
// };

var NEXT_PID: u16 = 1;

pub fn push_back(p: Process) void {
    var i: usize = 0;
    while(i < 32) {
        if (PROCESS_LIST[i] == null) {
            PROCESS_LIST[i] = p; 
            return;
        }
        i += 1;
    }
}

pub fn pop_front() Process {
    var i: usize = 0;
    var ret_proc = PROCESS_LIST[0].?; 
    while(i < 31) {
        PROCESS_LIST[i] = PROCESS_LIST[i + 1]; 
        i += 1;
    }
    PROCESS_LIST[31] = null;
}

//Eventually, this will go away
//For now, it'll occupy a slot in our process list
fn init_process() void{
    var i: usize = 0;
    while (true) {
        if (i >= 70000000) {
            _ = make_syscall(1);
            i = 0;
        } else {
            i += 1;
        }
    }
    // _ = make_syscall(1);
    // c.printf(c"In user mode! :D\n");
    // while(true){}
}

pub fn add_process_default(pr: [*] const u8) void {
    //TODO: LOCKING MECHANISM HERE WHEN APPENDING TO PROCESS_LIST
    var p = Process.new_default(pr);
    // var pid = p.pid; 
    //TODO: Be able to have more than one process in the list
    // PROCESS_LIST[0] = p
    push_back(p); 
    // PROCESS_LIST.push_back(p);
    //TODO: RELEASE LOCK NOW BRU
}

pub fn init() usize{
    // while(i < 32) {
    //     PROCESS_LIST[i] = undefined; 
    //     i += 1;
    // }
    //TODO: Initialize PROCESS_LIST
    //PROCESS_LIST = new List(5); ...or something like that
    add_process_default(@ptrCast([*] const u8, init_process));

    // var p = PROCESS_LIST.pop();
    var p = PROCESS_LIST[0];
    // var p = PROCESS_LIST.pop_front();
    // var p = PROCESS_LIST.front();
    // var func_vaddr = p.program_counter; 
    // var frame: usize = @ptrToInt(&p.frame);
    // cpu.mscratch_write(frame);
    // cpu.satp_write(cpu.build_satp(cpu.SatpMode.Sv39,1,@ptrToInt(p.root)));
    // cpu.satp_fence_asid(1);
    // PROCESS_LIST.push_back(p);
    // return PROCESS_STARTING_ADDR;
    return p.?.program_counter;
}

//Our process must be able to sleep, wait, or run.
//Running - means that when the scheduler finds this process, it can run it.
//Sleeping - means that the process is waiting on a certain amount of time.
//Waiting - means that the process is waiting on I/O
//Dead - We should never get here, but we can flag a process as Dead and clean
//it out of the list later.
pub const ProcessState = enum(usize){
    Running,
    Sleeping,
    Waiting,
    Dead,
};

pub const Process = packed struct {
        frame:              *trap.TrapFrame = undefined,
        stack:              [*]u8 = undefined,
        program_counter:    usize = 0,
        pid:                u16 = 0,
        root:               *page.Table,
        state:              ProcessState = undefined,
        data:               ProcessData = undefined,
        sleep_until:        usize,

        pub fn new_default(func: [*] const u8) Process{
            var func_addr: usize = @ptrToInt(func);
            var func_vaddr = func_addr; //PROCESS_STARTING_ADDR;
            // var ret_proc = @ptrCast(*Process, kmem.kzmalloc(@sizeOf(Process))); 
            // ret_proc.*.frame = @ptrCast(*trap.TrapFrame, page.zalloc(1));
            // ret_proc.*.stack = page.zalloc(STACK_PAGES); 
            // ret_proc.*.program_counter = func_vaddr; 
            // ret_proc.*.pid = NEXT_PID; 
            // ret_proc.*.root = @ptrCast(*page.Table, page.zalloc(1));
            // ret_proc.*.state = ProcessState.Running; 
            // ret_proc.*.data = ProcessData.zero();
            // ret_proc.*.sleep_until = 0;
            var ret_proc = Process{
                    .frame=             @ptrCast(*trap.TrapFrame, page.zalloc(1)), //trap.TrapFrame.makeTrapFrame(),
                    .stack=             page.zalloc(STACK_PAGES),
                    .program_counter=   func_vaddr,
                    .pid=               NEXT_PID,
                    .root=              @ptrCast(*page.Table, page.zalloc(1)),
                    .state=             ProcessState.Running,
                    .data=              ProcessData.zero(), 
                    .sleep_until=       0
            };

            NEXT_PID += 1;

        //Now we move the stack pointer to the bottom of the
        //allocation. The spec shows that register x2 (2) is the stack
        //pointer.
        //We could use ret_proc.stack.add, but that's an unsafe
        //function which would require an unsafe block. So, convert it
        //to usize first and then add PAGE_SIZE is better.
        //We also need to set the stack adjustment so that it is at the
        //bottom of the memory and far away from heap allocations.
            ret_proc.frame.*.regs[2] = STACK_ADDR + page.PAGE_SIZE * STACK_PAGES;
            var saddr: usize = @ptrToInt(ret_proc.stack);
            // ret_proc.frame.*.regs[2] = saddr + (page.PAGE_SIZE * STACK_PAGES);
            ret_proc.frame.*.satp = cpu.build_satp(cpu.SatpMode.Sv39,1,@ptrToInt(ret_proc.root));
            ret_proc.frame.*.trap_stack = cpu._ekernel_stack;
            // c.printf(c"Frame addr: %x, %x\n", @ptrToInt(ret_proc.frame), ret_proc.get_frame_address());
            // c.printf(c"sp should be: %x, but is: %x\n", saddr + (page.PAGE_SIZE * STACK_PAGES), ret_proc.frame.*.regs[2]);
            // var pt: *page.Table = ret_proc.root.*;
            // var pt = @ptrCast(*page.Table, ret_proc.root);
            var pt = ret_proc.root;
            // var saddr: usize = @ptrToInt(ret_proc.stack);

        //We need to map the stack onto the user process' virtual
        //memory This gets a little hairy because we need to also map
        //the function code too.
            var i: usize = 0;
            // c.printf(c"STACK_ADDR = %x\n", STACK_ADDR);
            while(i < STACK_PAGES){
                var addr: usize = i * page.PAGE_SIZE;
                page.map(pt,STACK_ADDR + addr,saddr + addr,@enumToInt(page.EntryBits.UserReadWrite),0);
                i += 1;
                // c.printf(c"Set stack from 0x%08x to 0x%08x\n", STACK_ADDR + addr, saddr + addr); 
                // c.printf(c"Stack virt: 0x%x -> phys: 0x%x\n", STACK_ADDR + addr, page.virt_to_phys(pt, STACK_ADDR + addr));
            }
            
            // asm volatile ("j .");
            //Map the program counter on the MMU
            page.map(pt,func_vaddr,func_addr,@enumToInt(page.EntryBits.UserReadWriteExecute),0);
            // page.map(pt,func_vaddr + 0x1000,func_addr + 0x1000,@enumToInt(page.EntryBits.UserReadWriteExecute),0);
            // i = 0; 
            // while (i <= 100) {
            //     var modifier = i * 0x1000; 
            //     page.map(pt, func_vaddr + modifier, func_addr + modifier, @enumToInt(page.EntryBits.UserReadWriteExecute), 0);
            //     i += 1;
            // }

            // c.printf(c"0x%08x -> 0x%08x\n", func_vaddr, page.virt_to_phys(pt, func_vaddr));
            
            page.map(pt, 0x80000000, 0x80000000, @enumToInt(page.EntryBits.UserReadExecute), 0); 

            return ret_proc;
        }

        fn drop(self: Process) void {
            //We allocate the stack as a page
            page.dealloc(self.stack);
            //Remember that unmap unmaps all levels of page tables
            //except for the root. It also deallocates the memory
            //Passociated with the tables.
            page.unmap(self.root.*);
            page.dealloc(self.root);
        }

        pub fn get_frame_address(self: Process) usize {
            return @ptrToInt(self.frame); 
        }
        pub fn get_program_counter(self: Process) usize {
            return self.program_counter;
        }
        pub fn get_table_address(self: Process) usize {
            return @ptrToInt(self.root); 
        }
        pub fn get_state(self: Process) ProcessState {
            return self.state; 
        }
        pub fn get_pid(self: Process) u16 {
            return self.pid; 
        }
        pub fn get_sleep_until(self: Process) usize {
            return self.sleep_until;
        }
};

pub const ProcessData = packed struct{
    cwd_path: [128]u8 = undefined,

    pub fn zero() ProcessData{
        return ProcessData{ .cwd_path = [1]u8{0} ** 128};
    }
};