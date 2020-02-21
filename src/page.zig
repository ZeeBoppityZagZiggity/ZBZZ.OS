const uart_lib = @import("uart.zig").UART;
const string_lib = @import("string.zig").String;
const cpu = @import("cpu.zig");
const assert = @import("std").debug.assert;

pub var HEAP_START: usize = 0;
pub var HEAP_SIZE: usize = 0;
// extern "C" const HEAP_START: c_ulong;
// extern "C" const HEAP_SIZE: c_ulong;
pub const PAGE_SIZE: usize = 4096;
var ALLOC_START: usize = 0;

pub const PageBits = enum(u8) {
    Empty = 0,
    Taken = 1 << 0,
    Last = 1 << 1,
};

pub const Page = packed struct {
    flags: u8 = 0,

    pub fn init() Page {
        return Page{ .flags = 0 };
    }

    pub fn is_last(self: Page) bool {
        if (self.flags & @enumToInt(PageBits.Last) != 0) {
            return true;
        } else {
            return false;
        }
    }

    pub fn is_taken(self: Page) bool {
        if (self.flags & @enumToInt(PageBits.Taken) != 0) {
            return true;
        } else {
            return false;
        }
    }

    pub fn is_free(self: Page) bool {
        return !self.is_taken();
    }

    pub fn clear(self: Page) void {
        // self.flags = @enumToInt(PageBits.Empty);
        self = Page{ .flags = @enumToInt(PageBits.Empty) };
    }

    pub fn set_flag(self: Page, flag: PageBits) void {
        // self.flags |= @enumToInt(flag);
        self = Page{ .flags = (self.flags | @enumToInt(flag)) };
    }

    pub fn clear_flag(self: Page, flag: PageBits) void {
        // self.flags &= !@enumToInt(flag);
        self = Page{ .flags = (self.flags & ~@enumToInt(flag)) };
    }
};

pub fn init() void {
    const num_pages = HEAP_SIZE / PAGE_SIZE;

    var i: usize = 0;
    var ptr = @intToPtr([*]Page, HEAP_START);
    while (i < num_pages) {
        // var ptr = @intToPtr(*Page, HEAP_START + i);
        // var ptr = @ptrCast(*Page, ptr1);
        // var p: Page = ptr.*;
        ptr[i].clear();
        i += 1;
    }

    ALLOC_START = (HEAP_START + num_pages * @sizeOf(Page) + PAGE_SIZE - 1) & ~(PAGE_SIZE - 1);
}

pub fn alloc(pages: usize) [*]u8 {
    const uart = uart_lib.MakeUART();
    const num_pages = HEAP_SIZE / PAGE_SIZE;
    var i: usize = 0;
    var ptr = @intToPtr([*]Page, HEAP_START);
    while (i < (num_pages - pages)) {
        var found: bool = false;
        // var ptr = @intToPtr(*Page, HEAP_START + i);
        if (ptr[i].is_free()) {
            // uart.puts("Found a page\n");
            found = true;
            var j: usize = i;
            while (j < (i + pages)) {
                // var jptr = @intToPtr(*Page, HEAP_START + j);
                if (ptr[j].is_taken()) {
                    found = false;
                    break;
                }
                j += 1;
            }
        }
        // uart.puts("Here\n");

        if (found) {
            var k: usize = i;
            while (k < (i + pages - 1)) {
                // var kptr = @intToPtr(*Page, HEAP_START + k);
                ptr[k].set_flag(PageBits.Taken);
                k += 1;
            }
            // uart.puts("here?\n");
            // var kptr = @intToPtr(*Page, HEAP_START + i + pages - 1);
            ptr[k].set_flag(PageBits.Taken);
            ptr[k].set_flag(PageBits.Last);
            // uart.puts("alloc!\n");
            return @intToPtr([*]u8, (ALLOC_START + (PAGE_SIZE * i)));
        }

        i += 1;
    }
    // uart.puts("No page found :(\n");
    var u: [*]u8 = undefined;
    return u;
}

pub fn zalloc(pages: usize) [*]u8 {
    var ptr: [*]u8 = alloc(pages);
    var base_addr = @ptrToInt(ptr);
    var size: usize = (PAGE_SIZE * pages) / 8;
    var i: usize = 0;
    var big_ptr = @intToPtr([*]usize, base_addr);
    while (i < size) {
        // var big_ptr = @intToPtr(*usize, base_addr + (i * 8));
        big_ptr[i] = 0;
        i += 1;
    }
    return ptr;
}

pub fn dealloc(ptr: [*]u8) void {
    var base_addr = HEAP_START + ((@ptrToInt(ptr) - ALLOC_START) / PAGE_SIZE);
    var p = @intToPtr(*Page, base_addr);
    var i: usize = 0;
    while (p[i].is_taken() and !(p[i].is_last())) {
        p[i].clear();
        i += 1;
        // p = @intToPtr(*Page, base_addr + i);
    }

    assert(p[i].is_last() == true);
    p[i].clear();
}

pub fn addr2hex(addr: *u8) [2]u8 {
    var val = addr.*;
    // var hexstr: [2]u8 = {'0', '0'};
    var lower: u8 = val & 0b1111;
    var upper: u8 = (val >> 4) & 0b1111;
    if (lower < 10) {
        lower += 48;
    } else {
        lower += 87;
    }
    if (upper < 10) {
        upper += 48;
    } else {
        upper += 87;
    }
    const hexstr = [_]u8{ upper, lower };
    return hexstr;
}

pub fn printPageAllocations() void {
    const uart = uart_lib.MakeUART();
    var num_pages = HEAP_SIZE / PAGE_SIZE;
    var head = @intToPtr(*Page, HEAP_START);
    var tail = @intToPtr(*Page, HEAP_START + num_pages);
    var alloc_head = ALLOC_START;
    var alloc_tail = ALLOC_START + num_pages * PAGE_SIZE;
    //Zee Bop Ziggity Zag, I'll put the developer of Zig in a bodybag :)
    uart.puts("PAGE ALLOCATION TABLE: \nMETA: ");
    uart.puts(string_lib.dword2hex(@ptrToInt(head)));
    uart.puts(" -> ");
    uart.puts(string_lib.dword2hex(@ptrToInt(tail)));
    uart.puts("\nPHYS: ");
    uart.puts(string_lib.dword2hex(alloc_head));
    uart.puts(" -> ");
    uart.puts(string_lib.dword2hex(alloc_tail));
    uart.puts("\n");
    var num: usize = 0;
    while (@ptrToInt(head) < @ptrToInt(tail)) {
        if (head.*.is_taken()) {
            var start = @ptrToInt(head);
            var memaddr = ALLOC_START + (start - HEAP_START) * PAGE_SIZE;
            uart.puts(string_lib.dword2hex(memaddr));
            uart.puts(" => ");
            while (true) {
                num += 1;
                if (head.*.is_last()) {
                    var end = @ptrToInt(head);
                    var endmemaddr = ALLOC_START + ((end - HEAP_START) * PAGE_SIZE) + PAGE_SIZE - 1;
                    uart.puts(string_lib.dword2hex(endmemaddr));
                    uart.puts(": ");
                    uart.puts(string_lib.byte2hex((@truncate(u8, end - start + 1))));
                    uart.puts("\n");
                    break;
                }
                head = @intToPtr(*Page, @ptrToInt(head) + 1);
            }
        }
        head = @intToPtr(*Page, @ptrToInt(head) + 1);
    }
    uart.puts("Free pages: ");
    uart.puts(string_lib.byte2hex(@truncate(u8, num_pages - num)));
    uart.puts("\n");
}

pub fn printPageContents(addr: *u8) void {
    const uart = uart_lib.MakeUART();
    var base_address = @ptrToInt(addr);
    var i: usize = 0;
    while (i < PAGE_SIZE) {
        var ptr = @intToPtr(*u8, base_address + i);
        // var flag = &ptr.*.flags;
        uart.puts(addr2hex(ptr));
        i += 1;
        if ((i % 32) == 0) {
            uart.puts("\n");
        } else if ((i % 4) == 0) {
            uart.puts(" ");
        }
    }
}

pub fn printPageTable() void {
    const uart = uart_lib.MakeUART();
    const num_pages = HEAP_SIZE / PAGE_SIZE;

    var i: usize = 0;
    var ptr = @intToPtr([*]Page, HEAP_START);
    while (i < num_pages) {
        // var ptr = @intToPtr(*Page, HEAP_START + i);
        var flag = &ptr[i].flags;
        uart.puts(addr2hex(flag));
        // var p: Page = ptr.*;
        // ptr.*.clear();
        i += 1;
        if ((i != 0) and (i % 10 == 0)) {
            uart.puts("\n");
        }
    }
}
