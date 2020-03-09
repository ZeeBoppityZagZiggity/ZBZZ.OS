const uart_lib = @import("uart.zig").UART;
const string_lib = @import("string.zig").String;
const trap = @import("trap.zig");
const cpu = @import("cpu.zig");
const plic = @import("plic.zig");
const fmt = @import("std").fmt;
const page = @import("page.zig");
const kmem = @import("kmem.zig");
const timer = @import("timer.zig");
// const uart_base_addr: usize = 0x10000000;

//pub var HEAP_START: usize = 0;
//pub var HEAP_SIZE: usize = 0;

pub var _text: usize = 0;
pub var _etext: usize = 0;
pub var _rodata: usize = 0;
pub var _erodata: usize = 0;
pub var _data: usize = 0;
pub var _edata: usize = 0;
pub var _bss: usize = 0;
pub var _ebss: usize = 0;
pub var _kernel_stack: usize = 0;
pub var _ekernel_stack: usize = 0;

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

export fn kinit() usize {
    trap.emptyfunc();
    const x = 0;
    // uart.uart_init();
    const uart = uart_lib.MakeUART();
    uart.puts("Uart Initd\n");
    page.init();
    uart.puts("Page Table Initd\n");
    kmem.init();
    uart.puts("KMem functionality Initd\n");

    // page.printPageAllocations();

    var root_ptr: *page.Table = @intToPtr(*page.Table, @ptrToInt(kmem.get_page_table()));
    var root_u: usize = @ptrToInt(root_ptr);
    var kheap_head: *u8 = @intToPtr(*u8, @ptrToInt(kmem.get_head()));
    var total_pages: usize = kmem.get_num_allocations();

    id_map_range(root_ptr, @ptrToInt(kheap_head), @ptrToInt(kheap_head) + total_pages * 4096, @enumToInt(page.EntryBits.ReadWrite));
    // Map Heap descriptors
    var num_pages: usize = page.HEAP_SIZE / page.PAGE_SIZE;
    id_map_range(root_ptr, page.HEAP_START, page.HEAP_START + page.HEAP_SIZE, @enumToInt(page.EntryBits.ReadWrite));
    //Map executable section
    id_map_range(root_ptr, _text, _etext, @enumToInt(page.EntryBits.ReadExecute));
    //Map rodata section
    id_map_range(root_ptr, _rodata, _erodata, @enumToInt(page.EntryBits.ReadExecute));
    //Map data section
    id_map_range(root_ptr, _data, _edata, @enumToInt(page.EntryBits.ReadWrite));
    //Map bss section
    id_map_range(root_ptr, _bss, _ebss, @enumToInt(page.EntryBits.ReadWrite));
    //Map kernel stack
    id_map_range(root_ptr, _kernel_stack, _ekernel_stack, @enumToInt(page.EntryBits.ReadWrite));
    //Map UART
    // id_map_range(root_ptr, 0x10000000, 0x10000000, @enumToInt(page.EntryBits.ReadWrite));
    page.map(root_ptr, 0x10000000, 0x10000000, @enumToInt(page.EntryBits.ReadWrite), 0);

    id_map_range(root_ptr, timer.clint_base, timer.clint_end, @enumToInt(page.EntryBits.ReadWrite));

    var root_ppn: usize = root_u >> 12;
    var satp_val: usize = (8 << 60) | root_ppn;
    cpu.satp_write(satp_val);

    //Create Trap Frame Pointer
    const tf = @ptrCast(*const u8, &trap.KERNEL_TRAP_FRAME);
    const tf_ptr = @ptrToInt(tf);
    //Store it in mscratch
    cpu.mscratch_write(tf_ptr);

    cpu.sscratch_write(cpu.mscratch_read()); 
    const ktf = @ptrCast(*trap.TrapFrame, &trap.KERNEL_TRAP_FRAME); 
    


    // Set up the PLIC
    plic.enable(10);
    plic.set_priority(10, 1);
    plic.set_threshold(0);

    
    uart.puts("Exiting kinit\n");
    return satp_val;
}

//This stupid function exists because Zig's compiler has a (known) bug
//that makes referencing extern variables impossible(?)
export fn kheap(a1: usize, a2: usize) void {
    page.HEAP_START = a1;
    page.HEAP_SIZE = a2;
}

export fn kelf1(a0: usize, a1: usize, a2: usize, a3: usize, a4: usize) void {
    _text = a0;
    _etext = a1;
    _rodata = a2;
    _erodata = a3;
    _data = a4;
}

export fn kelf2(a0: usize, a1: usize, a2: usize, a3: usize, a4: usize) void {
    _edata = a0;
    _bss = a1;
    _ebss = a2;
    _kernel_stack = a3;
    _ekernel_stack = a4;
}

export fn kmain() void {
    //Reinit uart
    const uart = uart_lib.MakeUART();
    uart.puts("Entered Main\n");
    var ptr = page.zalloc(10);
    // uart.puts(cpu.dword2hex(@ptrToInt(ptr)));
    // page.printPageAllocations();
    timer.set_timer_ms(0, 1000);
    // var mystr = string_lib.String("Hello as well!\n");
    // uart.print(mystr.z_str());
    // mystr.free();

    // var c: usize = 0x80000000;
    // var

    while (true) {}
}
