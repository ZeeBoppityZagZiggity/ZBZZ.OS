const kmem = @import("kmem.zig");

pub const ascii_lower = "abcdefghijklmnopqrstuvwxyz";
pub const ascii_upper = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
pub const digits = "0123456789";
pub const hex_digits = "0123456789abcdefABCDEF";
pub const oct_digits = "01234567";
pub const whitespace = " \t\n\r";
pub const punctuation = "!\"#$%&'()*+,-./:;?@[]\\^_{|}~";

pub const String = struct {
    _str: [*]u8,
    _shallow: bool,
    _len: usize,

    pub fn String(str: []const u8) String {
        var allocstr = kmem.kmalloc(str.len * @sizeOf(u8));
        allocstr = strcpy(allocstr, str);
        return String{ ._str = allocstr, ._shallow = false, ._len = str.len};
    }

    //pub fn Shallow(anStr: String) String {
    //    return String{ ._str = anStr.z_str(), ._shallow = true, ._len = anStr._len};
    //}

    //pub fn Deep(anStr: String) String {
    //    var allocstr = kmem.kmalloc(anStr._len * @sizeOf(u8));
    //}

    pub fn free(this: String) void {
        if(!this._shallow) {
            kmem.kfree(this._str);
        }
    }

    pub fn z_str(this: String) [*]u8 {
        return this._str;
    }

    //I Made this so we can copy const string arrays to a pointer.
    pub fn strcpy(dest: [*]u8, src: []const u8) [*]u8 {
        // var ptr = @ptrCast([*]u8, dest);
        for (src) |val, i| {
            dest[i] = val;
        }
        return dest;
    }

    pub fn byte2hex(val: u8) [2]u8 {
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

    pub fn dword2hex(val: usize) [16]u8 {
        var len: usize = 16;
        var i = len - 1;
        var hexstr: [16]u8 = undefined;
        var tval = val;
        while (i >= 0) {
            var a: u8 = @truncate(u8, tval) & 0b1111;
            if (a < 10) {
                a += 48;
            } else {
                a += 87;
            }
            hexstr[i] = a;
            tval = tval >> 4;
            if (i == 0) {
                break;
            }
            i -= 1;
        }
        return hexstr;
    }
};
