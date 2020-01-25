const uart_lib = @import("uart.zig").UART;
const uart_base_addr: usize = 0x10000000;

export fn kinit() void {
  const x = 0;
  
  const uart = uart_lib.MakeUART(uart_base_addr);
  var rx: ?u8 = null; 
  while(true) {
    rx = uart.read();
    if (rx != null) {
        uart.put(rx.?); 
    }
  } //stay in zig for now
}
