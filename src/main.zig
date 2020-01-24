const uart_lib = @import("uart.zig").UART;
const UART_BASE_ADDR: usize = 0x10000000;

// export const uart_base_addr = 0x10000000;

export fn kinit() void {
  const x = 0;
  
  const uart = uart_lib.init(UART_BASE_ADDR);
  var rx: ?u8 = null; 
  while(true) {
    rx = uart.read();
    if (rx != null) {
        uart.put(rx.?); 
    }
  } //stay in zig for now
}
