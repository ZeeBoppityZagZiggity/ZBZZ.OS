const c = @cImport({
    @cDefine("_NO_CRT_STDIO_INLINE", "1");
    @cInclude("printf.h");
});

pub const Stat = packed struct {
    mode: u16,
    size: u32,
    uid: u16,
    gid: u16,
};

/// A file descriptor
pub const Descriptor = packed struct {
    blockdev: usize,
    node: u32,
    loc: u32,
    size: u32,
    pid: u16,
};

pub const FsError = enum(usize){
    Success,
    FileNotFound,
    Permission,
    IsFile,
    IsDirectory,
};