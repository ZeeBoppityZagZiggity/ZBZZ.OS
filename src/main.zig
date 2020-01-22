// const uart = @import("uart.zig");

// export const uart_base_addr = 0x10000000;

export fn kinit() void {
  const x = 0;
  while(true) {}
  // uart.uart_init(0x10000000);
  // var rx: ?u8 = null; 
  // while(true) {
  //   rx = uart.uart_read(0x10000000);
  //   if (rx != null) {
  //       uart.uart_put(0x10000000, rx.?); 
  //   }
  // } //stay in zig for now
}
