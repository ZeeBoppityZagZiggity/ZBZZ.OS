pub const clint_base: usize = 0x2000000;
pub const clint_end: usize = 0x200ffff;
pub const mtimecmp_base: usize = 0x2004000;
pub const mtime: usize = 0x200bff8;
pub const clkrate = 10000000; //Clock rate in Hz

pub fn set_timer_ms(hartid: usize, ms: usize) void {
    var cmp_ptr = @intToPtr(*volatile usize, mtimecmp_base + (4 * hartid)); 
    var mtime_ptr = @intToPtr(*volatile usize, mtime); 
    cmp_ptr.* = mtime_ptr.* + (ms * (clkrate / 1000)); 
}