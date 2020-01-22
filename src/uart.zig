pub extern fn uart_init(base_addr: usize) void {

    const base_ptr = @intToPtr(*volatile u8, base_addr);
    // const lcr: u8 = 0b11;
    //Set LCR
    const lcr_ptr = @intToPtr(*volatile u8, base_addr + 3);
    lcr_ptr.* = 0b11; 
    //Enable FIFO
    const fifo_ptr = @intToPtr(*volatile u8, base_addr + 2);
    fifo_ptr.* = 0b1;
    // //Enable receiver buffer interrupts  
    // const intr_ptr = @intToPtr(*volatile u8, base_addr + 1); 
    // intr_ptr.* = 0b1; 

    // var divisor: u16 = 592; 
    // var divisor_least: u8 = divisor & 0xff; 
    // var divisor_most: u8 = divisor >> 8; 
    // lcr_ptr.* = 0b10000011; 
    // base_ptr.* = divisor_least;
    // intr_ptr.* = divisor_most; 
    // lcr_ptr.* = 0b11; 
}

pub extern fn uart_put(base_addr: usize, din: u8) void {
    const base_ptr = @intToPtr(*volatile u8, base_addr);
    base_ptr.* = din; 
}

pub fn uart_read(base_addr: usize) ?u8 {
    const base_ptr = @intToPtr(*volatile u8, base_addr); 
    const DR_ptr = @intToPtr(*volatile u8, base_addr + 5);
    var DR: u8 = DR_ptr.* & 0b1; 
    var rx: ?u8 = null; 
    if (DR == 1) {
        rx = base_ptr.*; 
    }
    return rx;
}