/// mscratch_write
/// @brief Writes a value of type usize into the mscratch register
/// @param val Value to write into mscratch
pub fn mscratch_write(val: usize) void {
    asm volatile ("csrw mscratch, %[val]"
        :
        : [val] "{x10}" (val)
    );
}

