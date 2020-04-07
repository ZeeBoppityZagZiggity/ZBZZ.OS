const kmem = @import("kmem.zig");
const page = @import("page.zig");
const virtio = @import("virtio.zig");

const c = @cImport({
    @cDefine("_NO_CRT_STDIO_INLINE", "1");
    @cInclude("printf.h");
});

pub const EntropyDevice = packed struct {
    queue: *virtio.Queue,
    dev: *u32,
    idx: u16,
    ack_used_idx: u16,

    pub fn new() EntropyDevice {
        return EntropyDevice{
            .queue = undefined,
            .dev = undefined,
            .idx = 0,
            .ack_used_idx = 0,
        };
    }
};

pub var ENTROPY_DEVICES: [8]EntropyDevice = undefined;

pub fn setup_entropy_device(ptr: *u32) bool {
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
    tmpaddr = @ptrToInt(ptr);
    tmpaddr += (@enumToInt(virtio.MmioOffsets.GuestFeatures) * 4);
    tmpPtr = @intToPtr(*volatile u32, tmpaddr);
    tmpPtr.* = host_features;

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

    // 8. Set the DRIVER_OK status bit. Device is now "live"
    status_bits |= @enumToInt(virtio.StatusField.DriverOk);
    tmpaddr = @ptrToInt(ptr);
    tmpaddr += (@enumToInt(virtio.MmioOffsets.Status) * 4);
    tmpPtr = @intToPtr(*volatile u32, tmpaddr);
    tmpPtr.* = status_bits;

    var rngdev = EntropyDevice{
        .queue = queue_ptr,
        .dev = ptr,
        .idx = 0,
        .ack_used_idx = 0,
    };

    ENTROPY_DEVICES[idx] = rngdev;

    return true;
}

pub fn get_random() u64 {
    for (ENTROPY_DEVICES) |i| {
        if (i != undefined) {
            var ptr = kmem.kmalloc(8);
            var desc = virtio.Descriptor{
                .addr = @ptrToInt(ptr),
                .len = 8,
                .flags = virtio.VIRTIO_DESC_F_WRITE,
                .next = 0,
            };

            var val = &ptr;
            kmem.kfree(ptr);
            break;
        }
    }
    return 0;
}
