pub fn mscratch_write(x: usize) void {
    asm volatile ("csrw mscratch, %[x]"
        :
        : [x] "{x10}" (x)
    );
}
