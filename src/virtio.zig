const string_lib = @import("string.zig").String;
const cpu = @import("cpu.zig");
const assert = @import("std").debug.assert;
const page = @import("page.zig");
const block = @import("block.zig");
const rng = @import("rng.zig");

const c = @cImport({
    @cDefine("_NO_CRT_STDIO_INLINE", "1");
    @cInclude("printf.h");
});

// Flags
// Descriptor flags have VIRTIO_DESC_F as a prefix
// Available flags have VIRTIO_AVAIL_F
pub const VIRTIO_DESC_F_NEXT: u16 = 1;
pub const VIRTIO_DESC_F_WRITE: u16 = 2;
pub const VIRTIO_DESC_F_INDIRECT: u16 = 4;

pub const VIRTIO_AVAIL_F_NO_INTERRUPT: u16 = 1;

pub const VIRTIO_USED_F_NO_NOTIFY: u16 = 1;

pub const VIRTIO_RING_SIZE: usize = 1 << 7;

// VirtIO structures

// The descriptor holds the data that we need to send to
// the device. The address is a physical address and NOT
// a virtual address. The len is in bytes and the flags are
// specified above. Any descriptor can be chained, hence the
// next field, but only if the F_NEXT flag is specified.

pub var Descriptor = packed struct {
    addr: u64,
    len: u32,
    flags: u16,
    next: u16,
};

pub var Available = packed struct {
    flags: u16,
    idx: u16,
    ring: [VIRTIO_RING_SIZE]u16,
    event: u16,
};

pub var UsedElem = packed struct {
    id: u32,
    len: u32,
};

pub var Used = packed struct {
    flags: u16,
    idx: u16,
    ring: [VIRTIO_RING_SIZE]UsedElem,
    event: u16,
};

pub var Queue = packed struct {
    desc: [VIRTIO_RING_SIZE]Descriptor,
    avail: Available,
    // Calculating padding, we need the used ring to start on a page boundary. We take the page size, subtract the
    // amount the descriptor ring takes then subtract the available structure and ring.
    padding0: [page.PAGE_SIZE - @sizeOf(Descriptor) * VIRTIO_RING_SIZE - @sizeOf(Available)]u8,
    used: Used,
};

// The MMIO transport is "legacy" in QEMU, so these registers represent
// the legacy interface.
pub const MmioOffsets = enum(u32) { //TODO: MARZ HAS USIZE, BUT HE WANTS U32, I THINK
    MagicValue = 0x000,
    Version = 0x004,
    DeviceId = 0x008,
    VendorId = 0x00c,
    HostFeatures = 0x010,
    HostFeaturesSel = 0x014,
    GuestFeatures = 0x020,
    GuestFeaturesSel = 0x024,
    GuestPageSize = 0x028,
    QueueSel = 0x030,
    QueueNumMax = 0x034,
    QueueNum = 0x038,
    QueueAlign = 0x03c,
    QueuePfn = 0x040,
    QueueNotify = 0x050,
    InterruptStatus = 0x060,
    InterruptAck = 0x064,
    Status = 0x070,
    Config = 0x100,
};

pub const DeviceTypes = enum(usize) {
    None = 0,
    Network = 1,
    Block = 2,
    Console = 3,
    Entropy = 4,
    Gpu = 16,
    Input = 18,
    Memory = 24,
};

pub const StatusField = enum(usize) {
    Acknowledge = 1,
    Driver = 2,
    Failed = 128,
    FeaturesOk = 8,
    DriverOk = 4,
    DeviceNeedsReset = 64,

    //    pub fn val32(self: StatusField) u32 {
    //       return u32(self);
    //    }

    pub fn testVal(self: StatusField, sf: u32, bit: StatusField) bool {
        return (sf & u32(bit) != 0);
    }

    pub fn is_failed(self: StatusField, sf: u32) bool {
        return StatusField.testVal(sf, StatusField.Failed);
    }

    pub fn needs_reset(self: StatusField, sf: u32) bool {
        return StatusField.testVal(sf, StatusField.DeviceNeedsReset);
    }

    pub fn driver_ok(self: StatusField, sf: u32) bool {
        return StatusField.testVal(sf, StatusField.DriverOk);
    }

    pub fn features_ok(self: StatusField, sf: u32) bool {
        return StatusField.testVal(sf, StatusField.FeaturesOk);
    }
};

// We probably shouldn't put these here, but it'll help
// with probing the bus, etc. These are architecture specific
// which is why I say that.
pub const MMIO_VIRTIO_START: usize = 0x10001000;
pub const MMIO_VIRTIO_END: usize = 0x10008000;
pub const MMIO_VIRTIO_STRIDE: usize = 0x1000;
pub const MMIO_VIRTIO_MAGIC: u32 = 0x74726976;

pub var VirtioDevice = packed struct {
    devtype: DeviceTypes,

    pub fn new() VirtioDevice {
        return VirtioDevice{ .devtype = DeviceTypes.None };
    }

    pub fn newWith(devtype: DeviceTypes) VirtioDevice {
        return VirtioDevice{ .devtype = devtype };
    }
};

pub var VIRTIO_DEVICES: [8]VirtioDevice = undefined;

pub fn probe() void {
    var addr = MMIO_VIRTIO_START;

    while (addr <= MMIO_VIRTIO_END) {
        c.printf(c"Virtio probing 0x{:08x}...\n", addr);

        var ptr = @intToPtr(*volatile u32, addr);
        var magicvalue = ptr.*;
        var deviceid = @intToPtr(*volatile u32, addr + 8).*; //Marz has .add(), but i think thats with ptr arith..

        if (MMIO_VIRTIO_MAGIC != magicvalue) {
            c.printf("NOT virtio\n");
        } else if (0 == deviceid) {
            c.printf("NOT connected\n");
        } else {
            switch (deviceid) {
                1 => {
                    c.printf("Network device...\n");
                    if (false == setup_network_device(ptr)) {
                        c.printf("Network Setup Failed!\n");
                    } else {
                        c.printf("Network Setup Succeeded!\n");
                    }
                },
                2 => {
                    c.printf("Block device...\n");
                    if (false == setup_block_device(ptr)) {
                        c.printf("Block Setup Failed!\n");
                    } else {
                        var idx = (addr - MMIO_VIRTIO_START) >> 12;
                        VIRTIO_DEVICES[idx] = VirtioDevice.newWith(DeviceTypes.Block);
                        c.printf("Block Setup Succeeded!\n");
                    }
                },
                4 => {
                    c.printf("Entropy device...\n");
                    if (false == rng.setup_entropy_device(ptr)) {
                        c.printf("Entropy Setup Failed!\n");
                    } else {
                        c.printf("Entropy Setup Succeeded!\n");
                    }
                },
                16 => {
                    c.printf("GPU device...\n");
                    if (false == setup_gpu_device(ptr)) {
                        c.printf("GPU Setup Failed!\n");
                    } else {
                        c.printf("GPU Setup Succeeded!\n");
                    }
                },
                18 => {
                    c.printf("Input device...\n");
                    if (false == setup_input_device(ptr)) {
                        c.printf("Input Setup Failed!\n");
                    } else {
                        c.printf("Input Setup Succeeded!\n");
                    }
                },
                else => {
                    c.printf("Unknown Device Type!\n");
                },
            }
        }

        addr += MMIO_VIRTIO_STRIDE;
    }
}

pub fn setup_network_device(_ptr, *u32) bool {
    return false;
}

pub fn setup_gpu_device(_ptr, *u32) bool {
    return false;
}

pub fn setup_input_device(_ptr, *u32) bool {
    return false;
}

// The External pin (PLIC) trap will lead us here if it is
// determined that interrupts 1..=8 are what caused the interrupt.
// In here, we try to figure out where to direct the interrupt
// and then handle it.
pub fn handle_interrupt(interrupt: u32) void {
    var idx = usize(interrupt) - 1;
    var vd = VIRTIO_DEVICES[idx];
    if (vd == undefined) {
        switch (vd.devtype) {
            DeviceTypes.Block => {
                block.handle_interrupt(idx);
            },
            else => {
                c.printf("Invalid device generated interrupt!\n");
            },
        }
    } else {
        c.printf("Spurious interrupt %d!\n", interrupt);
    }
}
