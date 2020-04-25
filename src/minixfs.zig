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
    pub fn get_inode(desc: *fs.Descriptor, inode_num: u32) Inode {
        // When we read, everything needs to be a multiple of a sector (512 bytes)
        // So, we need to have memory available that's at least 512 bytes, even if
        // we only want 10 bytes or 32 bytes (size of an Inode).
        tmpBuffer = BlockBuffer.new(512);

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
            var usize: inode_offset = (2 + super_block.imap_blocks + super_block.zmap_blocks) * BLOCK_SIZE;

            // Now, we read the inode itself.
            // The block driver requires that our offset be a multiple of 512. We do that with the
            // inode_offset. However, we're going to be reading a group of inodes.
            syc_read(desc, tmpBuffer.buffer, 512, u32(inode_offset));

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

    pub fn init(_bdev: usize) bool {
        return false;
    }

    pub fn open(_path: string_lib) fs.FsError {
        return fs.FsError.FileNotFound;
    }

    
};
