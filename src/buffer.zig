const std = @import("std");
const builtin = @import("builtin");
const root = @import("main.zig");

pub const Host = @import("buffer/host.zig");
pub const OpenCl = @import("buffer/opencl.zig");

comptime {
    root.checkLayout(Buffer, root.extern_sizes.BUFFER_SIZE, root.extern_sizes.BUFFER_ALIGN);
}

pub const Buffer = union(root.Backend) {
    Host: Host.Buffer,
    OpenCl: OpenCl.Buffer,
};

pub export fn ucCreateBuffer(context: *root.context.Context, size: usize, config: *const BufferConfig, buffer: *Buffer) root.uc_result_t {
    _ = config;
    buffer.* = switch (context.*) {
        .Host => .{ .Host = Host.create(size) catch |e| return root.externError(e) },
        .OpenCl => |*ctx| .{ .OpenCl = OpenCl.create(ctx.context, size) catch |e| return root.externError(e) },
    };
    return root.UC_RESULT_SUCCESS;
}

pub export fn ucBufferDeinit(buffer: *Buffer) root.uc_result_t {
    const res = switch (buffer.*) {
        .Host => |buf| Host.deinit(buf),
        .OpenCl => |buf| buf.deinit(),
    };
    res catch |e| return root.externError(e);
    return root.UC_RESULT_SUCCESS;
}

// OTHER TYPES
pub const BufferConfig = extern struct {};

pub const BufferInfo = enum(usize) {
    BACKEND = 0,
    DEVICE = 1,
    CONTEXT = 2,
    SIZE = 3,
};
