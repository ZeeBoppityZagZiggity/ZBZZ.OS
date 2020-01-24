pub const UART = struct {
    uart_base_addr: usize,

    pub fn init(base_addr: usize) UART {
        const base_ptr = @intToPtr(*volatile u8, base_addr);
        // const lcr: u8 = 0b11;
        //Set LCR
        const lcr_ptr = @intToPtr(*volatile u8, base_addr + 3);
        lcr_ptr.* = 0b11; 
        //Enable FIFO
        const fifo_ptr = @intToPtr(*volatile u8, base_addr + 2);
        fifo_ptr.* = 0b1;
        // //Enable receiver buffer interrupts  
        // const intr_ptr = @intToPtr(*volatile u8, uart_base_addr + 1); 
        // intr_ptr.* = 0b1; 

        // var divisor: u16 = 592; 
        // var divisor_least: u8 = divisor & 0xff; 
        // var divisor_most: u8 = divisor >> 8; 
        // lcr_ptr.* = 0b10000011; 
        // base_ptr.* = divisor_least;
        // intr_ptr.* = divisor_most; 
        // lcr_ptr.* = 0b11; 
        return UART{.uart_base_addr = base_addr};
    }

    pub fn put(self: UART, din: u8) void {
        const base_ptr = @intToPtr(*volatile u8, self.uart_base_addr);
        base_ptr.* = din; 
    }

    pub fn read(self: UART) ?u8 {
        const base_ptr = @intToPtr(*volatile u8, self.uart_base_addr); 
        const DR_ptr = @intToPtr(*volatile u8, self.uart_base_addr + 5);
        var DR: u8 = DR_ptr.* & 0b1; 
        var rx: ?u8 = null; 
        if (DR == 1) {
            rx = base_ptr.*; 
        }
        return rx;
    }
};
