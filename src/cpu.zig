/// mscratch_write
/// @brief Writes a value of type usize into the mscratch register
/// @param val Value to write into mscratch
pub fn mscratch_write(val: usize) void {
    asm volatile ("csrw mscratch, %[val]"
        :
        : [val] "{x10}" (val)
    );
}

pub fn itoa(comptime T: type, val: T, str: [*:0]u8) void {
    var len: usize = undefined; 
    var tval = val; 
    if (T == u8) {
        len = 2; 
    } else if (T == u16) {
        len = 4;
    } else if (T == u32) {
        len = 8;
    } else if (T == usize) {
        len = 16; 
    }
    var i = len - 1; 
    
    // var tval: u8 = val;
    // var len: usize = 2;
    // var i = len - 1; 
    while(i >= 0) {
        var a: u8 = tval & 0b1111; 
        if (a < 10) {
            a += 48; 
        } else {
            a += 87;
        }
        str[i] = a;
        tval = tval >> 4; 
        if (i == 0){
            break;
        }
        i = i - 1;
    }
    str[len] = 0;
    // str[0] = 'a';
    // str[1] = 'b';
    // str[2] = 0;
}