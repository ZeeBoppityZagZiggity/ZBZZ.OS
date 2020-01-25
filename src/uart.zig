/// UART Struct
/// @functions MakeUART put read
pub const UART = struct {
    /// address to use for DMA UART interface
    uart_base_addr: usize,

    /// init
    /// @brief Initializes a UART struct on the passed memory address
    /// @param base_addr the location of the UART
    pub fn MakeUART(base_addr: usize) UART {
        const base_ptr = @intToPtr(*volatile u8, base_addr);
        
        //Set LCR
        const lcr_ptr = @intToPtr(*volatile u8, base_addr + 3);
        lcr_ptr.* = 0b11; 
        
        //Enable FIFO
        const fifo_ptr = @intToPtr(*volatile u8, base_addr + 2);
        fifo_ptr.* = 0b1;

        return UART{.uart_base_addr = base_addr};
    }

    /// put
    /// @brief writes u8 data through the UART
    /// @param din unsigned byte data input to write
    pub fn put(self: UART, din: u8) void {
        const base_ptr = @intToPtr(*volatile u8, self.uart_base_addr);
        base_ptr.* = din; 
    }

    /// read
    /// @brief returns content written to the UART or a null value
    /// @return a u8 piece of data read off the UART or NULL
    pub fn read(self: UART) ?u8 {
        const base_ptr = @intToPtr(*volatile u8, self.uart_base_addr); 
        const dr_ptr = @intToPtr(*volatile u8, self.uart_base_addr + 5);
        var dr: u8 = dr_ptr.* & 0b1; 
        var rx: ?u8 = null; 
        if (dr == 1) {
            rx = base_ptr.*; 
        }
        return rx;
    }
};
