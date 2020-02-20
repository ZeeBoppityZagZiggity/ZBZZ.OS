/// mscratch_write
/// @brief Writes a value of type usize into the mscratch register
/// @param val Value to write into mscratch
pub fn mscratch_write(val: usize) void {
    asm volatile ("csrw mscratch, %[val]"
        :
        : [val] "{x10}" (val)
    );
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

// pub fn itoa(comptime T: type, val: T, str: [*:0]u8) void {
//     var len: usize = undefined;
//     var tval = val;
//     if (T == u8) {
//         len = 2;
//     } else if (T == u16) {
//         len = 4;
//     } else if (T == u32) {
//         len = 8;
//     } else if (T == usize) {
//         len = 16;
//     }
//     var i = len - 1;

//     // var tval: u8 = val;
//     // var len: usize = 2;
//     // var i = len - 1;
//     while(i >= 0) {
//         var a: u8 = tval & 0b1111;
//         if (a < 10) {
//             a += 48;
//         } else {
//             a += 87;
//         }
//         str[i] = a;
//         tval = tval >> 4;
//         if (i == 0){
//             break;
//         }
//         i = i - 1;
//     }
//     str[len] = 0;
//     // str[0] = 'a';
//     // str[1] = 'b';
//     // str[2] = 0;
// }
