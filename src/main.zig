// const uart_lib = @import("uart.zig").UART;
const string_lib = @import("string.zig").String;
const trap = @import("trap.zig");
const cpu = @import("cpu.zig");
const plic = @import("plic.zig");
const fmt = @import("std").fmt;
const page = @import("page.zig");
const kmem = @import("kmem.zig");
const timer = @import("timer.zig");
const proc = @import("process.zig");
const sched = @import("sched.zig");
const block = @import("block.zig");
const virtio = @import("virtio.zig");
// const LinkedList = @import("linkedlist.zig").LinkedList;
const uart_base_addr: usize = 0x10000000;

const c = @cImport({
    @cDefine("_NO_CRT_STDIO_INLINE", "1");
    @cInclude("printf.h");
});

//pub var HEAP_START: usize = 0;
//pub var HEAP_SIZE: usize = 0;
extern fn makeUART() void;
extern fn put(din: u8) void;
extern fn puts(din: [*]const u8) void;
extern fn print(din: [*]u8) void;
extern fn read() u8;

extern fn switch_to_user(frame: usize, mepc: usize, satp: usize) noreturn;
// extern fn cputs(c: [*]const u8) void;

pub fn id_map_range(root: *page.Table, start: usize, end: usize, bits: usize) void {
    var memaddr = start & ~(page.PAGE_SIZE - 1);
    var num_kb_pages = (kmem.align_val(end, 12) - memaddr) / page.PAGE_SIZE;
    var i: usize = 0;
    while (i < num_kb_pages) {
        page.map(root, memaddr, memaddr, bits, 0);
        i += 1;
        memaddr += 1 << 12;
    }
}

export fn kinit() void {
    trap.emptyfunc();
    const x = 0;
    // uart.uart_init();
    // const uart = uart_lib.MakeUART();
    makeUART();
    puts(c"Uart Initd\n");
    page.init();
    puts(c"Page Table Initd\n");
    kmem.init();
    puts(c"KMem functionality Initd\n");
    var addr = proc.init();
    // c.printf(c"PROC ADDR: %x\n", addr);

    page.printPageAllocations();
    // var misa: usize = cpu.misa_read();
    // c.printf(c"misa: %08x%08x\n", misa >> 32, misa);

    // var root_ptr: *page.Table = @intToPtr(*page.Table, @ptrToInt(kmem.get_page_table()));
    // var root_u: usize = @ptrToInt(root_ptr);
    // var kheap_head: *u8 = @intToPtr(*u8, @ptrToInt(kmem.get_head()));
    // var total_pages: usize = kmem.get_num_allocations();

    // Map UART
    // page.map(root_ptr, uart_base_addr, uart_base_addr, @enumToInt(page.EntryBits.ReadWrite), 0);
    // // c.printf(c"uart: %08x => %08x\n", uart_base_addr, page.virt_to_phys(root_ptr, uart_base_addr));

    // id_map_range(root_ptr, @ptrToInt(kheap_head), @ptrToInt(kheap_head) + total_pages * 4096, @enumToInt(page.EntryBits.ReadWrite));
    // // Map Heap descriptors
    // var num_pages: usize = page.HEAP_SIZE / page.PAGE_SIZE;
    // id_map_range(root_ptr, page.HEAP_START, page.HEAP_START + page.HEAP_SIZE, @enumToInt(page.EntryBits.ReadWrite));
    // //Map executable section
    // id_map_range(root_ptr, _text, _etext, @enumToInt(page.EntryBits.ReadExecute));
    // //Map rodata section
    // id_map_range(root_ptr, _rodata, _erodata, @enumToInt(page.EntryBits.ReadExecute));
    // //Map data section
    // id_map_range(root_ptr, _data, _edata, @enumToInt(page.EntryBits.ReadWrite));
    // //Map bss section
    // id_map_range(root_ptr, _bss, _ebss, @enumToInt(page.EntryBits.ReadWrite));
    // //Map kernel stack
    // id_map_range(root_ptr, _kernel_stack, _ekernel_stack, @enumToInt(page.EntryBits.ReadWrite));

    // //Map CLINT
    // id_map_range(root_ptr, timer.clint_base, timer.clint_end, @enumToInt(page.EntryBits.ReadWrite));

    // var root_ppn: usize = root_u >> 12;
    // var satp_val: usize = (8 << 60) | root_ppn;
    // cpu.satp_write(satp_val);

    // Set up the PLIC
    plic.set_threshold(0);
    plic.enable(1);
    plic.set_priority(1, 1);
    plic.enable(2);
    plic.set_priority(2, 1);
    plic.enable(3);
    plic.set_priority(3, 1);
    plic.enable(4);
    plic.set_priority(4, 1);
    plic.enable(5);
    plic.set_priority(5, 1);
    plic.enable(6);
    plic.set_priority(6, 1);
    plic.enable(7);
    plic.set_priority(7, 1);
    plic.enable(8);
    plic.set_priority(8, 1);
    plic.enable(9);
    plic.set_priority(9, 1);
    plic.enable(10);
    plic.set_priority(10, 1);
    //Create Trap Frame Pointer
    // const tf = @ptrCast(*const u8, &trap.KERNEL_TRAP_FRAME);
    // const tf_ptr = @ptrToInt(tf);
    // //Store it in mscratch
    // cpu.mscratch_write(tf_ptr);

    // //Testing linked list from here

    // var l = LinkedList(i32) {
    //     .first = null,
    //     .last = null,
    //     .len = 0
    // };
    // c.printf(c"pushed 26\n");
    // l.push_back(26);

    // // c.printf(c"%x, %x\n", &l, &l.first);
    // // c.printf(c"%d\n", l.first.?.*.data);
    // // c.printf(c"front: %d\n", l.front());
    // var tmp = l.pop_front();
    // c.printf(c"popped %d\n", tmp);
    // l.push_back(32);
    // tmp = l.pop_front();
    // c.printf(c"popped %d\n", tmp);
    // // tmp = l.pop_front();
    // // c.printf(c"popped %d\n", tmp);

    // while(true) {}
    // //DOne testing linked list

    virtio.probe();

    c.printf(c"Testing Block Driver ish\n");
    var buffer = kmem.kmalloc(512);
    block.read(8, buffer, 512, 0);
    var i: u16 = 0;
    while (i < 49) {
        c.printf(c" :%02x", buffer[i]);
        if (((i + 1) % 24)== 0) {
            c.printf(c"\n");
        }
        i += 1;
    }

    c.printf(c"\n");

    kmem.kfree(buffer);
    c.printf(c"Block Driver testing completed, bby. \n");

    timer.set_timer_ms(0, 1000);
    c.printf(c"addr of process list: %08x\n", @ptrToInt(&proc.PROCESS_LIST));
    // var tmp = @ptrToInt(&proc.PROCESS_LIST);
    var s = sched.schedule();
    // c.printf(c"Frame addr: %08x\nMEPC: %08x\nSATP: %08x%08x\n", s.frame, s.mepc, s.satp >> 32, s.satp);
    // c.printf(c"sp should be: %x, but is %x\n", proc.PROCESS_LIST[0].frame.*.regs[2], frame_ptr.*.regs[2]);
    // c.printf(c"switching to user\n");
    switch_to_user(s.frame, s.mepc, s.satp);

    // c.printf(c"Oh no!!!!!\n");
    // c.printf(c"Exiting kinit\n");
    // return addr;
    // return satp_val;
}

//This stupid function exists because Zig's compiler has a (known) bug
//that makes referencing extern variables impossible(?)
export fn kheap(a1: usize, a2: usize) void {
    page.HEAP_START = a1;
    page.HEAP_SIZE = a2;
}

export fn kelf1(a0: usize, a1: usize, a2: usize, a3: usize, a4: usize) void {
    cpu._text = a0;
    cpu._etext = a1;
    cpu._rodata = a2;
    cpu._erodata = a3;
    cpu._data = a4;
}

export fn kelf2(a0: usize, a1: usize, a2: usize, a3: usize, a4: usize) void {
    cpu._edata = a0;
    cpu._bss = a1;
    cpu._ebss = a2;
    cpu._kernel_stack = a3;
    cpu._ekernel_stack = a4;
}

export fn kmain() void {
    //Reinit uart
    // const uart = uart_lib.MakeUART();
    puts(c"Entered Main\n");
    var ptr = page.zalloc(10);
    // c.cputs(c"check this out!\n");
    var a: i32 = 14;
    var b: i32 = 18;
    c.printf(c"%d + %d = %05d\n", a, b, a + b);
    var str1 = c"Hello";
    var str2 = c"World";
    c.printf(c"%s, World!\n", str1);
    c.printf(c"Address of str1: 0x%08x\n", @ptrToInt(str1));
    // c.printf(c"Address of _text: %016x\n", _text);

    // uart.puts(cpu.dword2hex(@ptrToInt(ptr)));
    page.printPageAllocations();
    c.printf(c"Kernel stack: %08x -> %08x\n", cpu._kernel_stack, cpu._ekernel_stack);
    c.printf(c"TRAP FRAME STACK PTR: %08x\n", trap.KERNEL_TRAP_FRAME.trap_stack);

    // var l = LinkedList(usize) {
    //     .first = null,
    //     .last = null,
    //     .len = 0,
    // };

    // l.push_front(16);
    // c.printf(c"%d\n", l.first.?.*.data);
    // l.push_front(33);
    // c.printf(c"%d -> %d\n", l.first.?.*.data, l.first.?.*.next.?.*.data);
    // var l1 = l.pop_front();
    // var l2 = l.pop_front();
    // c.printf(c"%d -> %d\n", l1, l2);

    // while (true) {}
}
