const uart_lib = @import("uart.zig").UART;
const page = @import("page.zig");
const assert = @import("std").debug.assert;

pub const AllocListFlags = enum(usize) {
    Taken = 1 << 63,
};

//Don't think I need Marz's impl AllocListFlags thing here

pub const AllocList = packed struct {
    flags_size: usize = 0,

    pub fn init() AllocList {
        return AllocList{ .flags_size = 0 };
    }

    pub fn is_taken(self: AllocList) bool {
        if (self.flags_size & @enumToInt(AllocListFlags.Taken) != 0) {
            return true;
        } else {
            return false;
        }
    }

    pub fn is_free(self: AllocList) bool {
        return !self.is_taken();
    }

    pub fn set_taken(self: AllocList) void {
        self = AllocList{ .flags_size = (self.flags_size | @enumToInt(AllocListFlags.Taken)) };
    }

    pub fn set_free(self: AllocList) void {
        self = AllocList{ .flags_size = (self.flags_size & ~@enumToInt(AllocListFlags.Taken)) };
    }

    pub fn set_size(self: AllocList, size: usize) void {
        var k = self.is_taken();
        self = AllocList{ .flags_size = (size & ~@enumToInt(AllocListFlags.Taken)) };

        if (k) {
            self = AllocList{ .flags_size = (self.flags_size | @enumToInt(AllocListFlags.Taken)) };
        }
    }

    pub fn get_size(self: AllocList) usize {
        return self.flags_size & ~@enumToInt(AllocListFlags.Taken);
    }
};

var KMEM_HEAD: *AllocList = undefined;
var KMEM_ALLOC: usize = 0;
//Eventually, this will be a table object and not a singular page
var KMEM_PAGE_TABLE: *u8 = undefined;
//var KMEM_PAGE_TABLE: *Table = null;
//Eventually, this will be a table object and not a singular page

pub fn init() void {
    KMEM_ALLOC = 64;
    var k_alloc = page.zalloc(KMEM_ALLOC);
    // assert(k_alloc != undefined);
    // if (k_alloc == null) { //SHOULD NEVER HAPPEN
    //     //Explode and scream bloody murder here
    // }
    // KMEM_HEAD = @intToPtr(*AllocList, k_alloc);
    KMEM_HEAD = @ptrCast(*AllocList, k_alloc);
    KMEM_HEAD.*.set_free();
    KMEM_HEAD.*.set_size(KMEM_ALLOC * page.PAGE_SIZE);
    //KMEM_PAGE_TABLE = @intToPtr(*Table,page.zalloc(1));
    // KMEM_PAGE_TABLE = @intToPtr(*u8, page.zalloc(1));
    KMEM_PAGE_TABLE = page.zalloc(1);
}

pub fn align_val(val: usize, order: usize) usize {
    var one: usize = 1;
    var o: usize = (one << 3) - 1; //WTF do you mean this has to be comptime known???????
    return ((val + o) & ~o);
}

pub fn kzmalloc(sz: usize) *u8 {
    var size: usize = align_val(sz, 3);
    var ret: *u8 = kmalloc(size);

    if (ret != undefined) {
        var base_addr = @ptrToInt(ret);
        var i: usize = 0;
        while (i < size) {
            var tmp = @intToPtr(*usize, base_addr + i);
            tmp.* = 0;
            i += 1;
        }
    }
    return ret;
}

pub fn kmalloc(sz: usize) *u8 {
    var size: usize = align_val(sz, 3) + @sizeOf(AllocList);
    var head = KMEM_HEAD;
    var tail = @intToPtr(*AllocList, @ptrToInt(KMEM_HEAD) + (KMEM_ALLOC * page.PAGE_SIZE));

    while (@ptrToInt(head) < @ptrToInt(tail)) {
        if (head.*.is_free() and size <= head.*.get_size()) {
            var chunk_size: usize = head.*.get_size();
            var rem: usize = chunk_size - size;
            head.*.set_taken();
            if (rem > @sizeOf(AllocList)) {
                //Still got some space left; split it up
                var next = @intToPtr(*AllocList, @ptrToInt(head) + size);
                next.*.set_free();
                next.*.set_size(rem);
                head.*.set_size(size);
            } else {
                //Take entire chunk
                head.*.set_size(chunk_size);
            }
            //Da fuk is the right ptr arith?
            return @intToPtr(*u8, @ptrToInt(head) + @sizeOf(AllocList)); //might be + something else? TODO
        } else {
            //Wasn't a free chunk; move on
            head = @intToPtr(*AllocList, @ptrToInt(head) + head.*.get_size());
        }
    }
    //If we're here, we could not find a chunk that would yield enough
    //memory for us...
    var undef: *u8 = undefined;
    return undef;
}

pub fn kfree(ptr: *u8) void {
    if (ptr != undefined) {
        var p = @intToPtr(*AllocList, @ptrToInt(ptr) - @sizeOf(AllocList));
        if (p.*.is_taken()) {
            p.*.set_free();
        }
        coalesce();
    }
}

pub fn coalesce() void {
    var head = KMEM_HEAD;
    var tail = @intToPtr(*AllocList, @ptrToInt(KMEM_HEAD) + (KMEM_ALLOC * page.PAGE_SIZE));
    while (@ptrToInt(head) < @ptrToInt(tail)) {
        var next = @intToPtr(*AllocList, @ptrToInt(head) + head.*.get_size());
        if (head.*.get_size() == 0) {
            //Oh fuck, we got ourselves some bad double free shit
            //that'll infinitely loop
            break;
        } else if (@ptrToInt(next) >= @ptrToInt(tail)) {
            //We done
            break;
        } else if (head.*.is_free() and next.*.is_free()) {
            //We have adjacent free blocks. Let's make em do the
            //monster mash
            head.*.set_size(head.*.get_size() + next.*.get_size());
        }
        head = @intToPtr(*AllocList, @ptrToInt(head) + head.*.get_size());
    }
}
