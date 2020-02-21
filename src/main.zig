const uart_lib = @import("uart.zig").UART;
const string_lib = @import("string.zig").String;
const trap = @import("trap.zig");
const cpu = @import("cpu.zig");
const plic = @import("plic.zig");
const fmt = @import("std").fmt;
const page = @import("page.zig");
const kmem = @import("kmem.zig");
// const uart_base_addr: usize = 0x10000000;

// pub var HEAP_START: usize = 0;
// pub var HEAP_SIZE: usize = 0;

export fn kinit() void {
    trap.emptyfunc();
    const x = 0;
    // uart.uart_init();
    const uart = uart_lib.MakeUART();
    uart.puts("Uart Initd\n");

    page.init();
    uart.puts("Page Table Initd\n");

    kmem.init();
    uart.puts("KMem functionality Initd\n");

    // Set up the PLIC
    plic.enable(10);
    plic.set_priority(10, 1);
    plic.set_threshold(0);

    //Create Trap Frame Pointer
    const tf = @ptrCast(*const u8, &trap.KERNEL_TRAP_FRAME);
    const tf_ptr = @ptrToInt(tf);
    //Store it in mscratch
    cpu.mscratch_write(tf_ptr);
}

//This stupid function exists because Zig's compiler has a (known) bug
//that makes referencing extern variables impossible(?)
export fn kheap(a1: usize, a2: usize) void {
    page.HEAP_START = a1;
    page.HEAP_SIZE = a2;
}

export fn kmain() void {
    //Reinit uart
    const uart = uart_lib.MakeUART();
    uart.puts("Entered Main\n");
    var ptr = page.zalloc(10);
    // uart.puts(cpu.dword2hex(@ptrToInt(ptr)));
    page.printPageAllocations();
    var c = kmem.kmalloc(32 * @sizeOf(u8));
    c = string_lib.strcpy(c, "hello!\n");
    
    var mystr = string_lib.String("Hello as well!\n");
    uart.print(mystr.z_str());
    mystr.free();

    uart.print(c);
    const caddr = string_lib.dword2hex(@ptrToInt(c));
    uart.puts(caddr);
    uart.puts("\n");
    // uart.print(d);

    while (true) {}
}
