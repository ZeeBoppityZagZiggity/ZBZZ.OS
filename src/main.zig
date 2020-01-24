const uart = @import("uart.zig");
const UART_BASE_ADDR: usize = 0x10000000;

// export const uart_base_addr = 0x10000000;

export fn kinit() void {
  const x = 0;
  
  uart.uart_init(UART_BASE_ADDR);
  var rx: ?u8 = null; 
  while(true) {
    rx = uart.uart_read(UART_BASE_ADDR);
    if (rx != null) {
        uart.uart_put(UART_BASE_ADDR, rx.?); 
    }
  } //stay in zig for now
}
