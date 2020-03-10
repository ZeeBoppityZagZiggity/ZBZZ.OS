const cpu = @import("cpu.zig");
const page = @import("page.zig");
const trap = @import("trap.zig");

//Number of pages (4096 bytes) for a process' stack to have
const STACK_PAGES: usize = 2;

//We want to adjust the stack to be at the bottom of the memory allocation
//regardless of where it is on the kernel heap.
const STACK_ADDR: usize  = 0xf00000000;

// All processes will have a defined starting point in virtual memory.
const PROCESS_STARTING_ADDR: usize = 0x20000000;

//TODO: MAKE A List TYPE DATA STRUCTURE FOR THE PROCESSS LIST
//var PROCESS_LIST: List = undefined;

var NEXT_PID: u16 = 1;

//Eventually, this will go away
//For now, it'll occupy a slot in our process list
fn init_process() void{
    while(1){}
}

pub fn add_process_default(pr: fn()void) void {
    //TODO: LOCKING MECHANISM HERE WHEN APPENDING TO PROCESS_LIST
    var p = Process.new_default(pr);
    //PROCESS_LIST.push_back(p)
    //TODO: RELEASE LOCK NOW BRU
}

pub fn init() usize{

    //TODO: Initialize PROCESS_LIST
    //PROCESS_LIST = new List(5); ...or something like that
    add_process_default(init_process);

    var p = PROCESS_LIST.pop();
    var frame: usize = &p.frame;
    cpu.mscratch_write(frame);
    cpu.satp_write(cpu.build_satp(cpu.SatpMode.Sv39,1,@ptrToInt(p.root)));
    cpu.satp_fence_asid(1);
    //PROCESS_LIST.push_back/front(p);
    return PROCESS_STARTING_ADDR;
}

//Our process must be able to sleep, wait, or run.
//Running - means that when the scheduler finds this process, it can run it.
//Sleeping - means that the process is waiting on a certain amount of time.
//Waiting - means that the process is waiting on I/O
//Dead - We should never get here, but we can flag a process as Dead and clean
//it out of the list later.
pub const ProcessState = enum{
    Running,
    Sleeping,
    Waiting,
    Dead,
};

pub const Process = packed struct {
        frame:              trap.TrapFrame = undefined,
        stack:              [*]u8 = undefined,
        program_counter:    usize = 0,
        pid:                u16 = 0,
        root:               [*]u8,
        state:              ProcessState = undefined,
        data:               ProcessData = undefined,

        pub fn new_default(func: fn()void) Process{
            var func_addr: usize = @ptrToInt(func);
            var ret_proc = Process{
                    .frame=             trap.TrapFrame.makeTrapFrame(),
                    .stack=             page.alloc(STACK_PAGES),
                    .program_counter=   PROCESS_STARTING_ADDR,
                    .pid=               NEXT_PID,
                    .root=              page.zalloc(1),
                    .state=             ProcessState.Waiting,
                    .data=              ProcessData.zero()
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
            ret_proc.frame.regs[2] = STACK_ADDR + page.PAGE_SIZE * STACK_PAGES;
            var pt: *page.Table = ret_proc.root.*;
            var saddr: usize = @ptrToInt(ret_proc.stack);

        //We need to map the stack onto the user process' virtual
        //memory This gets a little hairy because we need to also map
        //the function code too.
            var i: usize = 0;
            while(i < STACK_PAGES){
                var addr: usize = i * PAGE_SIZE;
                page.map(pt,STACK_ADDR + addr,saddr + addr,@enumToInt(page.EntryBits.UserReadWrite),0);
            }

            //Map the program counter on the MMU
            page.map(pt,PROCESS_STARTING_ADDR,func_addr,@enumToInt(page.EntryBits.UserReadExecute),0);
            page.map(pt,PROCESS_STARTING_ADDR + 0x1001,func_addr + 0x1001,@enumToInt(page.EntryBits.UserReadExecute),0);
            
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
};

pub const ProcessData = struct{
    var cwd_path: [128]u8 = undefined;

    pub fn zero() ProcessData{
        return ProcessData{ .cwd_path = [128]u8{0} ** 128};
    }
};