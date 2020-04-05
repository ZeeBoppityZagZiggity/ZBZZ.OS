const kmem = @import("kmem.zig");
const page = @import("page.zig");
const virtio = @import("virtio.zig");

const c = @cImport({
    @cDefine("_NO_CRT_STDIO_INLINE", "1");
    @cInclude("printf.h");
});

pub const Geometry = packed struct {
    cylinders: u16,
    heads: u8,
    sectors: u8,
};

pub const Topology = packed struct {
    physical_block_exp: u8,
    alignment_offset: u8,
    min_io_size: u16,
    opt_io_size: u32,
};

// There is a configuration space for VirtIO that begins
// at offset 0x100 and continues to the size of the configuration.
// The structure below represents the configuration for a
// block device. Really, all that this OS cares about is the
// capacity.
pub const Config = packed struct {
    capacity: u64,
    size_max: u32,
    seg_max: u32,
    geometry: Geometry,
    blk_size: u32,
    topology: Topology,
    writeback: u8,
    unused0: [3]u8,
    max_discard_sector: u32,
    max_discard_seg: u32,
    discard_sector_alignment: u32,
    max_write_zeroes_sectors: u32,
    max_write_zeroes_seg: u32,
    write_zeroes_may_unmap: u8,
    unused1: [3]u8,
};

// The header/data/status is a block request
// packet. We send the header to tell the direction
// (blktype: IN/OUT) and then the starting sector
// we want to read. Then, we put the data buffer
// as the Data structure and finally an 8-bit
// status. The device will write one of three values
// in here: 0 = success, 1 = io error, 2 = unsupported
// operation.
pub const Header = packed struct {
    blktype: u32,
    reserved: u32,
    sector: u64,
};

pub const Data = packed struct {
    data: *u8,
};

pub const Status = packed struct {
    status: u8,
};

pub const Request = packed struct {
    header: Header,
    data: Data,
    status: Status,
    head: u16,
};

// Internal block device structure
// We keep our own used_idx and idx for
// descriptors. There is a shared index, but that
// tells us or the device if we've kept up with where
// we are for the available (us) or used (device) ring.
pub const BlockDevice = packed struct {
    queue: *virtio.Queue,
    dev: *u32,
    idx: u16,
    ack_used_idx: u16,
    read_only: bool,
};

// Type values
pub const VIRTIO_BLK_T_IN: u32 = 0;
pub const VIRTIO_BLK_T_OUT: u32 = 1;
pub const VIRTIO_BLK_T_FLUSH: u32 = 4;
pub const VIRTIO_BLK_T_DISCARD: u32 = 11;
pub const VIRTIO_BLK_T_WRITE_ZEROES: u32 = 13;

// Status values
pub const VIRTIO_BLK_S_OK: u8 = 0;
pub const VIRTIO_BLK_S_IOERR: u8 = 1;
pub const VIRTIO_BLK_S_UNSUPP: u8 = 2;

// Feature bits
pub const VIRTIO_BLK_F_SIZE_MAX: u32 = 1;
pub const VIRTIO_BLK_F_SEG_MAX: u32 = 2;
pub const VIRTIO_BLK_F_GEOMETRY: u32 = 4;
pub const VIRTIO_BLK_F_RO: u32 = 5;
pub const VIRTIO_BLK_F_BLK_SIZE: u32 = 6;
pub const VIRTIO_BLK_F_FLUSH: u32 = 9;
pub const VIRTIO_BLK_F_TOPOLOGY: u32 = 10;
pub const VIRTIO_BLK_F_CONFIG_WCE: u32 = 11;
pub const VIRTIO_BLK_F_DISCARD: u32 = 13;
pub const VIRTIO_BLK_F_WRITE_ZEROES: u32 = 14;

pub var BLOCK_DEVICES: [8]BlockDevice = undefined;

pub fn setup_block_device(ptr: *u32) bool {
    var idx = (usize(@ptrToInt(ptr)) - virtio.MMIO_VIRTIO_START) >> 12;

    //Essentially, we want to write 0 into the status register
    //Peep the volatile.
    //Peep the * 4 because 4 byte offset (I believe...)
    var tmpaddr = @ptrToInt(ptr);
    tmpaddr += (@enumToInt(virtio.MmioOffsets.Status) * 4);
    var tmpPtr = @intToPtr(*volatile u32, tmpaddr);
    tmpPtr.* = 0;

    //Set ACKNOWLEDGE status bit
    var status_bits = @enumToInt(virtio.StatusField.Acknowledge);
    tmpPtr.* = status_bits;

    //Set DRIVER status bit
    status_bits |= @enumToInt(virtio.StatusField.DriverOk);
    tmpPtr.* = status_bits;

    // 4. Read device feature bits, write subset of feature
    // bits understood by OS and driver to the device.
    tmpaddr = @ptrToInt(ptr);
    tmpaddr += (@enumToInt(virtio.MmioOffsets.HostFeatures) * 4);
    tmpPtr = @intToPtr(*volatile u32, tmpaddr);
    var host_features = tmpPtr.*;
    var guest_features = host_features & ~(1 << VIRTIO_BLK_F_RO);
    var ro = (host_features & (1 << VIRTIO_BLK_F_RO)) != 0;
    tmpaddr = @ptrToInt(ptr);
    tmpaddr += (@enumToInt(virtio.MmioOffsets.GuestFeatures) * 4);
    tmpPtr = @intToPtr(*volatile u32, tmpaddr);
    tmpPtr.* = guest_features;

    // 5. Set the FEATURES_OK status bit
    tmpaddr = @ptrToInt(ptr);
    tmpaddr += (@enumToInt(virtio.MmioOffsets.Status) * 4);
    tmpPtr = @intToPtr(*volatile u32, tmpaddr);
    status_bits |= @enumToInt(virtio.StatusField.FeaturesOk);
    tmpPtr.* = status_bits;

    // 6. Re-read status to ensure FEATURES_OK is still set.
    // Otherwise, it doesn't support our features.
    var status_ok = tmpPtr.*;
    // If the status field no longer has features_ok set,
    // that means that the device couldn't accept
    // the features that we request. Therefore, this is
    // considered a "failed" state.
    if (false == virtio.StatusField.features_ok(status_ok)) {
        c.printf("Our Features failed bruh..\n");
        tmpPtr.* = @enumToInt(virtio.StatusField.Failed);
        return false;
    }

    // 7. Perform device-specific setup.
    // Set the queue num. We have to make sure that the
    // queue size is valid because the device can only take
    // a certain size.
    tmpaddr = @ptrToInt(ptr);
    tmpaddr += (@enumToInt(virtio.MmioOffsets.QueueNumMax) * 4);
    tmpPtr = @intToPtr(*volatile u32, tmpaddr);
    var qnmax = tmpPtr.*;

    tmpaddr = @ptrToInt(ptr);
    tmpaddr += (@enumToInt(virtio.MmioOffsets.QueueNum) * 4);
    tmpPtr = @intToPtr(*volatile u32, tmpaddr);
    tmpPtr.* = u32(virtio.VIRTIO_RING_SIZE);

    if (u32(virtio.VIRTIO_RING_SIZE) > qnmax) {
        c.printf("Queue size fail :(\n");
        return false;
    }

    var num_pages = (@sizeOf(virtio.Queue) + page.PAGE_SIZE - 1) / page.PAGE_SIZE;

    tmpaddr = @ptrToInt(ptr);
    tmpaddr += (@enumToInt(virtio.MmioOffsets.QueueSel) * 4);
    tmpPtr = @intToPtr(*volatile u32, tmpaddr);
    tmpPtr.* = 0;

    var queue_ptr = [*]virtio.Queue(page.zalloc(num_pages));
    var queue_pfn = @ptrToInt(queue_ptr);
    tmpaddr = @ptrToInt(ptr);
    tmpaddr += (@enumToInt(virtio.MmioOffsets.GuestPageSize) * 4);
    tmpPtr = @intToPtr(*volatile u32, tmpaddr);
    tmpPtr.* = u32(page.PAGE_SIZE);

    tmpaddr = @ptrToInt(ptr);
    tmpaddr += (@enumToInt(virtio.MmioOffsets.QueuePfn) * 4);
    tmpPtr = @intToPtr(*volatile u32, tmpaddr);
    tmpPtr.* = u32(queue_pfn / page.PAGE_SIZE);

    var bd = BlockDevice{
        .queue = queue_ptr,
        .dev = ptr,
        .idx = 0,
        .ack_used_idx = 0,
        .read_only = ro,
    };

    BLOCK_DEVICES[idx] = bd;

    // 8. Set the DRIVER_OK status bit. Device is now "live"
    status_bits |= @enumToInt(virtio.StatusField.DriverOk);
    tmpaddr = @ptrToInt(ptr);
    tmpaddr += (@enumToInt(virtio.MmioOffsets.Status) * 4);
    tmpPtr = @intToPtr(*volatile u32, tmpaddr);
    tmpPtr.* = status_bits;

    return true;
}

