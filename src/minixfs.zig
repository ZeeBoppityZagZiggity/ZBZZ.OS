const cpu = @import("cpu.zig");
const kmem = @import("kmem.zig");
const process = @import("process.zig");
const syscall = @import("syscall.zig");
const string_lib = @import("string.zig").String;

pub const MAGIC: u16 = 0x4d5a;
pub const BLOCK_SIZE: u32 = 1024;
pub const NUM_IPTRS: u32 = BLOCK_SIZE / 4;

// The superblock describes the file system on the disk. It gives
// us all the information we need to read the file system and navigate
// the file system, including where to find the inodes and zones (blocks).
pub const SuperBlock = packed struct {
    ninodes: u32,
    pad0: u16,
    imap_blocks: u16,
    zmap_blocks: u16,
    first_data_zone: u16,
    log_zone_size: u16,
    pad1: u16,
    max_size: u32,
    zones: u32,
    magic: u16,
    pad2: u16,
    block_size: u16,
    disk_version: u8,
};

// An inode stores the "meta-data" to a file. The mode stores the permissions
// AND type of file. This is how we differentiate a directory from a file. A file
// size is in here too, which tells us how many blocks we need to read. Finally, the
// zones array points to where we can find the blocks, which is where the data
// is contained for the file.
pub const Inode = packed struct {
    mode: u16,
    nlinks: u16,
    uid: u16,
    gid: u16,
    size: u32,
    atime: u32,
    mtime: u32,
    ctime: u32,
    zones: [10]u32,
};

// Notice that an inode does not contain the name of a file. This is because
// more than one file name may refer to the same inode. These are called "hard links"
// Instead, a DirEntry essentially associates a file name with an inode as shown in
// the structure below.
pub const DirEntry = packed struct {
    inode: u32,
    name: [60]u8,
};

pub const BlockBuffer = packed struct {
    buffer: [*]u8,

    pub fn new(sz: u32) BlockBuffer {
        return BlockBuffer{ .buffer = kmem.kzmalloc(size) };
    }

    pub fn delete() void {
        kmem.kfree(buffer);
    }
};

pub const MinixFileSystem = packed struct {
    // Inodes are the meta-data of a file, including the mode (permissions and type) and
    // the file's size. They are stored above the data zones, but to figure out where we
    // need to go to get the inode, we first need the superblock, which is where we can
    // find all of the information about the filesystem itself.
    pub fn get_inode(desc: *fs.Descriptor, inode_num: u32) ?Inode {
        // When we read, everything needs to be a multiple of a sector (512 bytes)
        // So, we need to have memory available that's at least 512 bytes, even if
        // we only want 10 bytes or 32 bytes (size of an Inode).
        tmpBuffer = BlockBuffer.new(1024);

        //TODO: Check all of these addresses
        var super_block = @ptrCast(*SuperBlock, tmpBuffer.buffer);
        var inode = @ptrCast(*Inode, tmpBuffer.buffer);

        syc_read(desc, tmpBuffer.buffer, 512, 1024);

        if (super_block.magic == MAGIC) {
            // If we get here, we successfully read what we think is the super block.
            // The math here is 2 - one for the boot block, one for the super block. Then we
            // have to skip the bitmaps blocks. We have a certain number of inode map blocks (imap)
            // and zone map blocks (zmap).
            // The inode comes to us as a NUMBER, not an index. So, we need to subtract 1.

            //TODO: Best check that these dumb variables don't resolve to the same address
            var usize: inode_offset = (2 + super_block.imap_blocks + super_block.zmap_blocks) * BLOCK_SIZE + ((inode_num - 1) / (BLOCK_SIZE / @sizeOf(Inode))) * BLOCK_SIZE;

            // Now, we read the inode itself.
            // The block driver requires that our offset be a multiple of 512. We do that with the
            // inode_offset. However, we're going to be reading a group of inodes.
            syc_read(desc, tmpBuffer.buffer, 1024, u32(inode_offset));

            // There are 512 / size_of<Inode>() inodes in each read that we can do. However, we
            // need to figure out which inode in that group we need to read. We just take
            // the % of this to find out.
            var read_this_node = (inode_num - 1) % (512 / @sizeOf(Inode));

            // We copy the inode over. This might not be the best thing since the Inode will
            // eventually have to change after writing.
            var tmpAddr = @ptrToInt(inode);
            tmpAddr += read_this_node;
            var tmpPtr = @intToPtr(*Inode, tmpAddr);

            return tmpPtr.*;
        }
        return null;
    }

    // Init is where we would cache the superblock and inode to avoid having to read
    // it over and over again, like we do for read right now.
    pub fn init(_bdev: usize) bool {
        return false;
    }

    // The goal of open is to traverse the path given by path. If we cache the inodes
    // in RAM, it might make this much quicker. For now, this doesn't do anything since
    // we're just testing read based on if we know the Inode we're looking for.
    pub fn open(_path: string_lib) fs.FsError {
        return fs.FsError.FileNotFound;
    }

    pub fn read(desc: *fs.Descriptor, buffer: [*]u8, size: u32, offset: u32) u32 {
        // Our strategy here is to use blocks to see when we need to start reading
        // based on the offset. That's offset_block. Then, the actual byte within
        // that block that we need is offset_byte.
        var blocks_seen: u32 = 0;
        var offset_block = offset / BLOCK_SIZE;
        var offset_byte = offset % BLOCK_SIZE;
        var num_indirect_pointers = BLOCK_SIZE / 4;
        var inode = get_inode(desc, desc.*.node);
        if (inode == null) {
            return 0;
        }
        // First, the _size parameter (now in bytes_left) is the size of the buffer, not
        // necessarily the size of the file. If our buffer is bigger than the file, we're OK.
        // If our buffer is smaller than the file, then we can only read up to the buffer size.
        var bytes_left: usize = 0;
        if (size > inode.size) {
            bytes_left = inode.size;
        } else {
            bytes_left = size;
        }

        var bytes_read: u32 = 0;
        // The block buffer automatically drops when we quit early due to an error or we've read enough. This will be the holding port when we go out and read a block. Recall that even if we want 10 bytes, we have to read the entire block (really only 512 bytes of the block) first. So, we use the block_buffer as the middle man, which is then copied into the buffer.
        var block_buffer = BlockBuffer.new(BLOCK_SIZE);
        // Triply indirect zones point to a block of pointers (BLOCK_SIZE / 4). Each one of those pointers points to another block of pointers (BLOCK_SIZE / 4). Each one of those pointers yet again points to another block of pointers (BLOCK_SIZE / 4). This is why we have indirect, iindirect (doubly), and iiindirect (triply).
        var indirect_buffer = BlockBuffer.new(BLOCK_SIZE);
        var iindirect_buffer = BlockBuffer.new(BLOCK_SIZE);
        var iiindirect_buffer = BlockBuffer.new(BLOCK_SIZE);

        // I put the pointers *const u32 here. That means we will allocate the indirect, doubly indirect, and triply indirect even for small files. I initially had these in their respective scopes, but that required us to recreate the indirect buffer for doubly indirect and both the indirect and doubly indirect buffers for the triply indirect. Not sure which is better, but I probably wasted brain cells on this.
        var izones = @ptrCast([*]const u32, indirect_buffer.buffer);
        var iizones = @ptrCast([*]const u32, iindirect_buffer.buffer);
        var iiizones = @ptrCast([*]const u32, iiindirect_buffer.buffer);

        var thisIsDumb: u32 = 0;
        var arrayRange: [num_indirect_pointers]u32 = undefined;
        while (thisIsDumb < num_indirect_pointers) {
            arrayRange[thisIsDumb] = thisIsDumb;
            thisIsDumb += 1;
        }

        // ////////////////////////////////////////////
        // // DIRECT ZONES
        // ////////////////////////////////////////////
        const tmp = [_]u8{ 0, 1, 2, 3, 4, 5, 6 };

        for (tmp) |i| {
            if (inode.zones[i] == 0) {
                continue;
            }
            // We really use this to keep track of when we need to actually start reading
            // But an if statement probably takes more time than just incrementing it.
            if (offset_block <= blocks_seen) {
                // If we get here, then our offset is within our window that we want to see.
                // We need to go to the direct pointer's index. That'll give us a block INDEX.
                // That makes it easy since all we have to do is multiply the block size
                // by whatever we get. If it's 0, we skip it and move on.
                var zone_offset = inode.zones[i] * BLOCK_SIZE;
                // We read the zone, which is where the data is located. The zone offset is simply the block
                // size times the zone number. This makes it really easy to read!
                syc_read(desc, block_buffer.buffer, BLOCK_SIZE, zone_offset);
                // There's a little bit of math to see how much we need to read. We don't want to read
                // more than the buffer passed in can handle, and we don't want to read if we haven't
                // taken care of the offset. For example, an offset of 10000 with a size of 2 means we
                // can only read bytes 10,000 and 10,001.
                var read_this_many: u32 = 0;
                if (BLOCK_SIZE - offset_byte > bytes_left) {
                    read_this_many = bytes_left;
                } else {
                    read_this_many = BLOCK_SIZE - offset_byte;
                }

                // Once again, here we actually copy the bytes into the final destination, the buffer.
                var tmpaddr = @ptrToInt(buffer);
                tmpaddr += bytes_read;
                var dest = @intToPtr([*]u8, tmpaddr);

                var tmpaddr2 = @ptrToInt(block_buffer.buffer);
                tmpaddr2 += offset_byte;
                var src = @intToPtr([*]const u8, tmpaddr2);

                @memcpy(dest, src, read_this_many);

                // Regardless of whether we have an offset or not, we reset the offset byte back to 0. This
                // probably will get set to 0 many times, but who cares?
                offset_byte = 0;
                // Reset the statistics to see how many bytes we've read versus how many are left.
                bytes_read += read_this_many;
                bytes_left -= read_this_many;
                // If no more bytes are left, then we're done.
                if (bytes_left == 0) {
                    return bytes_read;
                }
            }
            // The blocks_seen is for the offset. We need to skip a certain number of blocks FIRST before getting
            // to the offset. The reason we need to read the zones is because we need to skip zones of 0, and they
            // do not contribute as a "seen" block
            blocks_seen += 1;
        }

        // ////////////////////////////////////////////
        // // SINGLY INDIRECT ZONES
        // ////////////////////////////////////////////
        // Each indirect zone is a list of pointers, each 4 bytes. These then
        // point to zones where the data can be found. Just like with the direct zones,
        // we need to make sure the zone isn't 0. A zone of 0 means skip it.
        if (inode.zones[7] != 0) {
            syc_read(desc, indirect_buffer.buffer, BLOCK_SIZE, BLOCK_SIZE * inode.zones[7]);
            for (arrayRange) |i| {
                if (i == num_indirect_pointers) {
                    break;
                }
                if (izones[i] == 0) {
                    continue;
                }
                if (offset_block <= blocks_seen) {
                    syc_read(desc, block_buffer.buffer, BLOCK_SIZE, BLOCK_SIZE * izones[i]);

                    var read_this_many: u32 = 0;
                    if (BLOCK_SIZE - offset_byte > bytes_left) {
                        read_this_many = bytes_left;
                    } else {
                        read_this_many = BLOCK_SIZE - offset_byte;
                    }

                    // Once again, here we actually copy the bytes into the final destination, the buffer.
                    var tmpaddr = @ptrToInt(buffer);
                    tmpaddr += bytes_read;
                    var dest = @intToPtr([*]u8, tmpaddr);

                    var tmpaddr2 = @ptrToInt(block_buffer.buffer);
                    tmpaddr2 += offset_byte;
                    var src = @intToPtr([*]const u8, tmpaddr2);

                    @memcpy(dest, src, read_this_many);

                    // Regardless of whether we have an offset or not, we reset the offset byte back to 0. This
                    // probably will get set to 0 many times, but who cares?
                    offset_byte = 0;
                    // Reset the statistics to see how many bytes we've read versus how many are left.
                    bytes_read += read_this_many;
                    bytes_left -= read_this_many;
                    // If no more bytes are left, then we're done.
                    if (bytes_left == 0) {
                        return bytes_read;
                    }
                }
                blocks_seen += 1;
            }
        }

        // ////////////////////////////////////////////
        // // DOUBLY INDIRECT ZONES
        // ////////////////////////////////////////////
        if (inode.zones[8] != 0) {
            syc_read(desc, indirect_buffer.buffer, BLOCK_SIZE, BLOCK_SIZE * inode.zones[8]);
            for (arrayRange) |j| {
                if (j == num_indirect_pointers) {
                    break;
                }
                if (izones[j] == 0) {
                    continue;
                }
                syc_read(desc, iindirect_buffer.buffer, BLOCK_SIZE, BLOCK_SIZE * izones[j]);
                for (arrayRange) |i| {
                    if (i == num_indirect_pointers) {
                        break;
                    }
                    if (iizones[i] == 0) {
                        continue;
                    }
                    if (offset_block <= blocks_seen) {
                        syc_read(desc, block_buffer.buffer, BLOCK_SIZE, BLOCK_SIZE * iizones[i]);

                        var read_this_many: u32 = 0;
                        if (BLOCK_SIZE - offset_byte > bytes_left) {
                            read_this_many = bytes_left;
                        } else {
                            read_this_many = BLOCK_SIZE - offset_byte;
                        }

                        // Once again, here we actually copy the bytes into the final destination, the buffer.
                        var tmpaddr = @ptrToInt(buffer);
                        tmpaddr += bytes_read;
                        var dest = @intToPtr([*]u8, tmpaddr);

                        var tmpaddr2 = @ptrToInt(block_buffer.buffer);
                        tmpaddr2 += offset_byte;
                        var src = @intToPtr([*]const u8, tmpaddr2);

                        @memcpy(dest, src, read_this_many);

                        // Regardless of whether we have an offset or not, we reset the offset byte back to 0. This
                        // probably will get set to 0 many times, but who cares?
                        offset_byte = 0;
                        // Reset the statistics to see how many bytes we've read versus how many are left.
                        bytes_read += read_this_many;
                        bytes_left -= read_this_many;
                        // If no more bytes are left, then we're done.
                        if (bytes_left == 0) {
                            return bytes_read;
                        }
                    }
                    blocks_seen += 1;
                }
            }
        }

        // ////////////////////////////////////////////
        // // TRIPLY INDIRECT ZONES
        // ////////////////////////////////////////////
        if (inode.zones[9] != 0) {
            syc_read(desc, indirect_buffer.buffer, BLOCK_SIZE, BLOCK_SIZE * inode.zones[9]);
            for (arrayRange) |k| {
                if (k == num_indirect_pointers) {
                    break;
                }
                if (izones[k] == 0) {
                    continue;
                }
                syc_read(desc, iindirect_buffer.buffer, BLOCK_SIZE, BLOCK_SIZE * izones[k]);
                for (arrayRange) |j| {
                    if (j == num_indirect_pointers) {
                        break;
                    }
                    if (iizones[j] == 0) {
                        continue;
                    }
                    syc_read(desc, iiindirect_buffer.buffer, BLOCK_SIZE, BLOCK_SIZE * iizones[j]);
                    for (arrayRange) |i| {
                        if (i == num_indirect_pointers) {
                            break;
                        }
                        if (iiizones[i] == 0) {
                            continue;
                        }
                        if (offset_block <= blocks_seen) {
                            syc_read(desc, block_buffer.buffer, BLOCK_SIZE, BLOCK_SIZE * iiizones[i]);

                            var read_this_many: u32 = 0;
                            if (BLOCK_SIZE - offset_byte > bytes_left) {
                                read_this_many = bytes_left;
                            } else {
                                read_this_many = BLOCK_SIZE - offset_byte;
                            }

                            // Once again, here we actually copy the bytes into the final destination, the buffer.
                            var tmpaddr = @ptrToInt(buffer);
                            tmpaddr += bytes_read;
                            var dest = @intToPtr([*]u8, tmpaddr);

                            var tmpaddr2 = @ptrToInt(block_buffer.buffer);
                            tmpaddr2 += offset_byte;
                            var src = @intToPtr([*]const u8, tmpaddr2);

                            @memcpy(dest, src, read_this_many);

                            // Regardless of whether we have an offset or not, we reset the offset byte back to 0. This
                            // probably will get set to 0 many times, but who cares?
                            offset_byte = 0;
                            // Reset the statistics to see how many bytes we've read versus how many are left.
                            bytes_read += read_this_many;
                            bytes_left -= read_this_many;
                            // If no more bytes are left, then we're done.
                            if (bytes_left == 0) {
                                return bytes_read;
                            }
                        }
                        blocks_seen += 1;
                    }
                }
            }
        }
        return bytes_read;
    }

    pub fn write(desc: *fs.Descriptor, buffer: [*]u8, size: u32, offset: u32) u32 {
        return 0;
    }

    pub fn close(desc: *fs.Descriptor) void {}

    pub fn stat(desc: *fs.Descriptor) fs.Stat {
        var inode_result = get_inode(desc, desc.node);
        if (inode_result != null) {
            var tmp = fs.Stat{
                .mode = inode_result.mode,
                .size = inode_result.size,
                .uid = inode_result.uid,
                .gid = inode_result.gid,
            };

            return tmp;
        }
    }
};

pub fn syc_read(desc: *fs.Descriptor, buffer: [*]u8, size: u32, offset: u32) u8 {
    //TODO
    var tmp = syscall.syscall_block_read(desc.*.blockdev, buffer, size, offset);
    return tmp;
}

// We have to start a process when reading from a file since the block
// device will block. We only want to block in a process context, not an
// interrupt context.
pub const ProcArgs = packed struct {
    pid: u16,
    dev: usize,
    buffer: [*]u8,
    size: u32,
    offset: u32,
    node: u32,
};

// This is the actual code ran inside of the read process.
pub fn read_proc(args_addr: usize) void {
    var args_ptr = @intToPtr(*ProcArgs, args_addr);

    // The descriptor will come from the user after an open() call. However,
    // for now, all we really care about is args.dev, args.node, and args.pid.
    var desc = fs.Descriptor{
        .blockdev = args_ptr.*.dev,
        .node = args_ptr.*.node,
        .loc = 0,
        .size = 500,
        .pid = args_ptr.*.pid,
    };

    // Start the read! Since we're in a kernel process, we can block by putting this
    // process into a waiting state and wait until the block driver returns.
    var bytes = MinixFileSystem.read(&desc, args_ptr.*.buffer, args_ptr.*.size, args_ptr.*.offset);

    // Let's write the return result into regs[10], which is A0.
    var ptr = process.get_by_pid(args_ptr.*.pid);
    //TODO: FINISH THIS!!

    process.set_running(args_ptr.pid); //TODO

    kmem.talloc(args_ptr); //TODO
}

// System calls will call process_read, which will spawn off a kernel process to read
// the requested data.
pub fn process_read(pid: u16, dev: usize, node: u32, buffer: [*]u8, size: u32, offset: u32) void {
    //var args = kmem.talloc() //TODO: Finish by adding talloc and tfree to kmem
    args.pid = pid;
    args.dev = dev;
    args.buffer = buffer;
    args.size = size;
    args.offset = offset;
    args.node = node;
    process.set_waiting(pid); //TODO: Implement this shit and the below shit
    var tmp = process.add_kernel_process_args(read_proc, @ptrToInt(@ptrCast(*ProcArgs, args)));
}
