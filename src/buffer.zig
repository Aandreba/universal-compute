const std = @import("std");
const root = @import("main.zig");

pub const Host = @import("buffer/host.zig");
pub const OpenCl = @import("buffer/opencl.zig");

comptime {
    root.checkLayout(Buffer, root.extern_sizes.BUFFER_SIZE, root.extern_sizes.BUFFER_ALIGN);
}

pub const Buffer = union(root.Backend) {
    Host: []u8,
    OpenCl: root.cl.cl_mem,
};
