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
    data: [*]u8,
};

pub const Status = packed struct {
    status: u8,
};

pub const Request = packed struct {
    header: Header,
    data: Data,
    status: Status,
    // head: u16,
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

pub fn setup_block_device(ptr: *volatile u32) bool {
    var idx = (usize(@ptrToInt(ptr)) - virtio.MMIO_VIRTIO_START) >> 12;

    //Essentially, we want to write 0 into the status register
    //Peep the volatile.
    //Peep the * 4 because 4 byte offset (I believe...)
    var tmpaddr = @ptrToInt(ptr);
    tmpaddr += (@enumToInt(virtio.MmioOffsets.Status));
    var tmpPtr = @intToPtr(*volatile u32, tmpaddr);
    tmpPtr.* = 0;

    //Set ACKNOWLEDGE status bit
    var status_bits = @enumToInt(virtio.StatusField.Acknowledge);
    tmpPtr.* |= @intCast(u32,status_bits);

    //Set DRIVER status bit
    status_bits = @enumToInt(virtio.StatusField.Driver);
    tmpPtr.* |= @intCast(u32,status_bits);

    // 4. Read device feature bits, write subset of feature
    // bits understood by OS and driver to the device.
    tmpaddr = @ptrToInt(ptr);
    tmpaddr += (@enumToInt(virtio.MmioOffsets.HostFeatures));
    tmpPtr = @intToPtr(*volatile u32, tmpaddr);
    var host_features = tmpPtr.*;
    var guest_features = host_features & ~(@intCast(u32,1 << VIRTIO_BLK_F_RO));
    var ro = (host_features & (1 << VIRTIO_BLK_F_RO)) != 0;
    tmpaddr = @ptrToInt(ptr);
    tmpaddr += (@enumToInt(virtio.MmioOffsets.GuestFeatures));
    tmpPtr = @intToPtr(*volatile u32, tmpaddr);
    tmpPtr.* = guest_features;

    // 5. Set the FEATURES_OK status bit
    tmpaddr = @ptrToInt(ptr);
    tmpaddr += (@enumToInt(virtio.MmioOffsets.Status));
    tmpPtr = @intToPtr(*volatile u32, tmpaddr);
    status_bits = @enumToInt(virtio.StatusField.FeaturesOk);
    tmpPtr.* |= @intCast(u32,status_bits);

    // 6. Re-read status to ensure FEATURES_OK is still set.
    // Otherwise, it doesn't support our features.
    var status_ok = tmpPtr.*;
 //   c.printf(c"status_okay: %d\n",status_ok);
    // If the status field no longer has features_ok set,
    // that means that the device couldn't accept
    // the features that we request. Therefore, this is
    // considered a "failed" state.
    if (false == virtio.StatusField.features_ok(status_ok)) {
        c.printf(c"Our Features failed bruh..\n");
        tmpPtr.* = @enumToInt(virtio.StatusField.Failed);
        return false;
    }

    // 7. Perform device-specific setup.
    // Set the queue num. We have to make sure that the
    // queue size is valid because the device can only take
    // a certain size.
    tmpaddr = @ptrToInt(ptr);
    tmpaddr += (@enumToInt(virtio.MmioOffsets.QueueNumMax));
    tmpPtr = @intToPtr(*volatile u32, tmpaddr);
    var qnmax = tmpPtr.*;

    tmpaddr = @ptrToInt(ptr);
    tmpaddr += (@enumToInt(virtio.MmioOffsets.QueueNum));
    tmpPtr = @intToPtr(*volatile u32, tmpaddr);
    tmpPtr.* = u32(virtio.VIRTIO_RING_SIZE);

    if (@intCast(u32,virtio.VIRTIO_RING_SIZE) > qnmax) {
        c.printf(c"Queue size fail :(\n");
        return false;
    }

    var num_pages = (@sizeOf(virtio.Queue) + page.PAGE_SIZE - 1) / page.PAGE_SIZE;

    tmpaddr = @ptrToInt(ptr);
    tmpaddr += (@enumToInt(virtio.MmioOffsets.QueueSel));
    tmpPtr = @intToPtr(*volatile u32, tmpaddr);
    tmpPtr.* = 0;

    //c.printf(c"DEBUG --> num_pages: %d\n",num_pages);
    var queue_ptr = @ptrCast(*virtio.Queue, page.zalloc(num_pages));
    var queue_pfn = @ptrToInt(queue_ptr);
    tmpaddr = @ptrToInt(ptr);
    tmpaddr += (@enumToInt(virtio.MmioOffsets.GuestPageSize));
    tmpPtr = @intToPtr(*volatile u32, tmpaddr);
    tmpPtr.* = u32(page.PAGE_SIZE);

    tmpaddr = @ptrToInt(ptr);
    tmpaddr += (@enumToInt(virtio.MmioOffsets.QueuePfn));
    tmpPtr = @intToPtr(*volatile u32, tmpaddr);
    tmpPtr.* = @intCast(u32,queue_pfn / page.PAGE_SIZE);

    var bd = BlockDevice{
        .queue = queue_ptr,
        .dev = @ptrCast(*u32,ptr),
        .idx = 0,
        .ack_used_idx = 0,
        .read_only = ro,
    };

    BLOCK_DEVICES[idx] = bd;

    // 8. Set the DRIVER_OK status bit. Device is now "live"
    status_bits = @enumToInt(virtio.StatusField.DriverOk);
    tmpaddr |= @ptrToInt(ptr);
    tmpaddr += (@enumToInt(virtio.MmioOffsets.Status));
    tmpPtr = @intToPtr(*volatile u32, tmpaddr);
    tmpPtr.* = @intCast(u32,status_bits);   

    return true;
}

pub fn fill_next_descriptor(bd: *BlockDevice, desc: virtio.Descriptor) u16 {
    // The ring structure increments here first. This allows us to skip
    // index 0, which then in the used ring will show that .id > 0. This
    // is one way to error check. We will eventually get back to 0 as
    // this index is cyclical. However, it shows if the first read/write
    // actually works.
    //c.printf(c"FND bd.idx = %d\n", bd.*.idx);
    bd.*.idx = (bd.*.idx + 1) % u16(virtio.VIRTIO_RING_SIZE);
    (bd.*.queue).*.desc[usize(bd.*.idx)] = desc;
    if (((bd.*.queue).*.desc[usize(bd.*.idx)].flags & virtio.VIRTIO_DESC_F_NEXT) != 0) {
        // If the next flag is set, we need another descriptor
       // c.printf(c"Got in here like we should.\n");
        (bd.*.queue).*.desc[usize(bd.*.idx)].next = (bd.*.idx + 1) % u16(virtio.VIRTIO_RING_SIZE);
    }
    return bd.*.idx;
}

/// This is now a common block operation for both reads and writes. Therefore,
/// when one thing needs to change, we can change it for both reads and writes.
/// There is a lot of error checking that I haven't done. The block device reads
/// sectors at a time, which are 512 bytes. Therefore, our buffer must be capable
/// of storing multiples of 512 bytes depending on the size. The size is also
/// a multiple of 512, but we don't really check that.
/// We DO however, check that we aren't writing to an R/O device. This would
/// cause a I/O error if we tried to write to a R/O device.
pub fn block_op(comptime dev: usize, buffer: [*]u8, size: u32, offset: u64, writeCheck: bool) void {
    var bdev = &BLOCK_DEVICES[dev - 1];

    //if (bdev != undefined) {
    if (bdev.*.read_only == true and writeCheck == true) {
        c.printf(c"Trying to write to read only, you buffoon.\n");
        return;
    }
    var sector = offset / 512;
    var blk_request_size: usize = @sizeOf(Request);
    var blk_request = @ptrCast(*Request, kmem.kzmalloc(blk_request_size));
    

    blk_request.*.header.sector = sector;
    if (writeCheck == true) {
        blk_request.*.header.blktype = VIRTIO_BLK_T_OUT;
    } else {
        blk_request.*.header.blktype = VIRTIO_BLK_T_IN;
    }

    var desc = virtio.Descriptor{
        .addr = @ptrToInt(&(blk_request.*.header)),
        .len = @sizeOf(Header),
        .flags = virtio.VIRTIO_DESC_F_NEXT,
        .next = 0,
    };
    var head_idx = fill_next_descriptor(bdev, desc);

    // We put 111 in the status. Whenever the device finishes, it will write into
    // status. If we read status and it is 111, we know that it wasn't written to by
    // the device.
    blk_request.*.data.data = buffer;
    blk_request.*.header.reserved = 0;
    blk_request.*.status.status = 111;
    

    var flags = virtio.VIRTIO_DESC_F_NEXT;
    if (writeCheck == false) {
        flags |= virtio.VIRTIO_DESC_F_WRITE;
    }
    desc = virtio.Descriptor{
        .addr = u64(@ptrToInt(buffer)),
        .len = size,
        .flags = flags,
        .next = 0,
    };
    var _data_idx = fill_next_descriptor(bdev, desc);

    desc = virtio.Descriptor{
        .addr = @ptrToInt(&(blk_request.*.status)),
        .len = @sizeOf(Status),
        .flags = virtio.VIRTIO_DESC_F_WRITE,
        .next = 0,
    };
    var _status_idx = fill_next_descriptor(bdev, desc);
    const tmpIdx: u16 = (bdev.*.queue).*.avail.idx; 

    // c.printf(c"avail: %d\n", tmpIdx);

    var temp: [*]u16 = @ptrCast([*]u16,@alignCast(2, &((bdev.*.queue).*.avail.ring[0])));
    temp[2 + tmpIdx] = head_idx;
    temp[1] += 1;

    //var a1 = @ptrToInt(temp); 
    //var a2 = @ptrToInt(&((bdev.*.queue).*.avail));
    //var sq: usize = @sizeOf(virtio.Queue);
    //var sa: usize = @sizeOf(virtio.Available);
    //c.printf(c"a1: %08x\na2: %08x\n", a1, a2);
    //c.printf(c"Sizeof queue: %d\nSizeof avail: %d\n", sq, sa);


    var tmpaddr = @ptrToInt(bdev.*.dev);
    tmpaddr += (@enumToInt(virtio.MmioOffsets.QueueNotify));
    var tmpPtr = @intToPtr(*volatile u32, tmpaddr);
    tmpPtr.* = 0;    

    //}
}

pub fn read(comptime dev: usize, buffer: [*]u8, size: u32, offset: u64) void {
    block_op(dev, buffer, size, offset, false);
}

pub fn write(comptime dev: usize, buffer: [*]u8, size: u32, offset: u64) void {
    block_op(dev, buffer, size, offset, true);
}

/// Here we handle block specific interrupts. Here, we need to check
/// the used ring and wind it up until we've handled everything.
/// This is how the device tells us that it's finished a request.
pub fn pending(bd: *BlockDevice) void {
    // Here we need to check the used ring and then free the resources
    // given by the descriptor id.
    var tmpQueue: *virtio.Queue = bd.*.queue;
    // c.printf(c"DEBUG --> bd.*.ack_used_idx: %d",bd.*.ack_used_idx);
    while (bd.*.ack_used_idx != tmpQueue.*.used.idx) {
        //var elem: virtio.UsedElem = tmpQueue.*.used.ring[@intCast(usize,bd.*.ack_used_idx)];
        var newTmpQueue: [*]virtio.UsedElem = @ptrCast([*]virtio.UsedElem,@alignCast(@sizeOf(virtio.UsedElem),&(tmpQueue.*.used.ring[0])));
        var elem = newTmpQueue[bd.*.ack_used_idx % virtio.VIRTIO_RING_SIZE];
        bd.*.ack_used_idx += 1; 
        // c.printf(c"DEBUG --> bd.*.ack_used_idx: %d",bd.*.ack_used_idx);
        kmem.kfree(@intToPtr([*]u8, tmpQueue.*.desc[usize(elem.id)].addr));
    }
}

/// The trap code will route PLIC interrupts 1..=8 for virtio devices. When
/// virtio determines that this is a block device, it sends it here.
pub fn handle_interrupt(idx: usize) void {
    var bdev = BLOCK_DEVICES[idx];
//    if (bdev != undefined) {
    // c.printf(c"DEBUG --> Handling block dev interrupt.\n");
    pending(&bdev);
//    } else {
//        c.printf(c"Invalid block device for interrupt %d...\n", idx + 1);
//   }
}
