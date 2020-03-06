/// mscratch_write
/// @brief Writes a value of type usize into the mscratch register
/// @param val Value to write into mscratch
pub fn mscratch_write(val: usize) void {
    asm volatile ("csrw mscratch, %[val]"
        :
        : [val] "{x10}" (val)
    );
}

pub fn satp_write(val: usize) void {
    asm volatile ("csrw satp, %[val]"
        :
        : [val] "{x10}" (val)
    );
}

pub const SatpMode = enum(usize) {
    Off = 0,
    Sv39 = 8,
    Sv48 = 9,
};

pub fn build_satp(mode: SatpMode, asid: usize, addr: usize) usize {
    return ((@enumToInt(mode) << 60) | ((asid & 0xffff) << 44) | ((addr >> 12) & 0xffffffffff));
}

pub fn satp_fence_asid(asid: usize) void {
    asm volatile ("sfence.vma zero, %[asid]"
        :
        : [asid] "{x10}" (asid)
    );
}
