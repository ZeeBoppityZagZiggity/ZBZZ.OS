const base_addr: usize = 0x10000000;
const freq = 10000000;
const baud = 115200;

//true when uart has first been initialized. Reinitializing the uart
//and its fifos, baud rate, etc every time we need to use it seems wasteful.
var initd = false;

/// UART Struct
/// @functions MakeUART put read
const UART = struct {
    /// address to use for DMA UART interface
    uart_base_addr: usize,
};
    /// init
    /// @brief Initializes a UART struct on the passed memory address
    /// @param base_addr the location of the UART
    export fn makeUART() void {
        if (initd == false) {
            const base_ptr = @intToPtr(*volatile u8, base_addr);

            //Set LCR
            const lcr_ptr = @intToPtr(*volatile u8, base_addr + 3);
            lcr_ptr.* = 0b11;

            //Enable FIFO
            const fifo_ptr = @intToPtr(*volatile u8, base_addr + 2);
            fifo_ptr.* = 0b1;

            // //Enable receiver buffer interrupts
            const intr_ptr = @intToPtr(*volatile u8, base_addr + 1);
            intr_ptr.* = 0b1;

            // var divisor: u16 = freq / (baud * 16);
            var divisor: u16 = @intCast(u16, @divFloor(freq, (baud * 16)));
            var divisor_least: u8 = @intCast(u8, divisor & 0xff);
            var divisor_most: u8 = @intCast(u8, divisor >> 8);
            lcr_ptr.* = 0b10000011;
            base_ptr.* = divisor_least;
            intr_ptr.* = divisor_most;
            lcr_ptr.* = 0b11;
        }
        initd = true;
        // return UART{ .uart_base_addr = base_addr };
    }

    /// put
    /// @brief writes u8 data through the UART
    /// @param din unsigned byte data input to write
    export fn put(din: u8) void {
        const base_ptr = @intToPtr(*volatile u8, base_addr);
        base_ptr.* = din;
    }

    /// puts
    /// @brief writes an array of u8 data through the UART
    /// @param din unsigned byte array of input to write
    export fn puts(din: [*]u8) void {
        // for (din) |value| {
        //     put(value);
        // }
        // var base = @ptrToInt(din); //I'm not sure why but it won't work without this
        var d = din[0];
        var i: usize = 0;
        // var ptr = @intToPtr(*u8, base + i);
        while (d != 0) {
            put(d);
            i += 1;
            d = din[i];
            // ptr = @intToPtr(*u8, base + i);
        }
        // var i: usize = 0;
        // while(true) {
        //     var value = din[i];
        //     if (value == 0) {
        //         break;
        //     } else {
        //         self.put(value);
        //     }
        //     i += 1;
        // }
    }

    export fn print(din: [*]u8) void {
        // var base = @ptrToInt(din);
        var i: usize = 0;
        // var ptr = @intToPtr(*u8, base + i);
        while (din[i] != 0) {
            put(din[i]);
            i += 1;
            // ptr = @intToPtr(*u8, base + i);
        }
    }

    /// read
    /// @brief returns content written to the UART or a null value
    /// @return a u8 piece of data read off the UART or NULL
    export fn read() u8 {
        const base_ptr = @intToPtr(*volatile u8, base_addr);
        const dr_ptr = @intToPtr(*volatile u8, base_addr + 5);
        var dr: u8 = dr_ptr.* & 0b1;
        var rx: u8 = undefined;
        if (dr == 1) {
            rx = base_ptr.*;
        }
        return rx;
    }
// };
