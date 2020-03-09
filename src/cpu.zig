/// mscratch_write
/// @brief Writes a value of type usize into the mscratch register
/// @param val Value to write into mscratch
pub fn mscratch_write(val: usize) void {
    asm volatile ("csrw mscratch, %[val]"
        :
        : [val] "{x10}" (val)
    );
}

pub fn mscratch_read() usize {
    return asm volatile ("csrr %[ret], mscratch"
        : [ret] "={x10}" (-> usize) : : );
}

pub fn sscratch_write(val: usize) void {
    asm volatile ("csrw sscratch, %[val]"
        :
        : [val] "{x10}" (val)
    );
}

pub fn sscratch_read() usize {
    return asm volatile ("csrr %[ret], sscratch"
        : [ret] "={x10}" (-> usize) : : );
}

pub fn satp_write(val: usize) void {
    asm volatile ("csrw satp, %[val]"
        :
        : [val] "{x10}" (val)
    );
}
