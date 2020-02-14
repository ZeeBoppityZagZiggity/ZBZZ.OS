const priority_reg_addr: usize = 0x0c000000;
const pending_reg_addr: usize = 0x0c001000;
const enable_reg_addr: usize = 0x0c002000;
const thresh_reg_addr: usize = 0x0c200000;
const claim_reg_addr: usize = 0x0c200004;

/// PLIC enable
/// @brief enables interrupts from the device whose id is passed
/// @param id PLIC id of device to enable interrupts for
pub fn enable(comptime id: u32) void {
    const ptr = @intToPtr(*volatile u32, enable_reg_addr);

    ptr.* = (1 << id); 
}

/// PLIC set_priority 
/// @brief set priority of device 
/// @param id PLIC id of device
/// @param prio priority level from 0 to 7 
pub fn set_priority(id: u32, prio: u8) void {
    const prio_actual: u32 = prio & 7; 
    const ptr = @intToPtr(*volatile u32, priority_reg_addr + (id * 4));
    ptr.* = prio_actual;
}

/// PLIC set_threshold 
/// @brief Set interrupt threshold. Any interrupt with a priority lower 
///     than this threshold is considered disabled
/// @param tsh threshold level from 0 to 7 
pub fn set_threshold(tsh: u8) void {
    const tsh_actual: u32 = tsh & 7; 
    const ptr = @intToPtr(*volatile u32, thresh_reg_addr);
    ptr.* = tsh_actual;
}

/// PLIC claim 
/// @brief get id of pending interrupt 
/// @return id of highest priority pending interrupt 
pub fn claim() u32 {
    const ptr = @intToPtr(*volatile u32, claim_reg_addr);
    const claim_id: u32 = ptr.*; 
    return claim_id; 
}

/// PLIC complete 
/// @brief informs PLIC that an interrupt has been handled 
/// @param claim_id PLIC id of interrupt that was handled. 
pub fn complete(claim_id: u32) void {
    const ptr = @intToPtr(*volatile u32, claim_reg_addr); 
    ptr.* = claim_id; 
}