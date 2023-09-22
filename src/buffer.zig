const std = @import("std");
const builtin = @import("builtin");
const root = @import("main.zig");

pub const Host = @import("buffer/host.zig");
pub const OpenCl = if (root.features.has_opencl) @import("buffer/opencl.zig") else struct {};

comptime {
    root.exportLayout(Buffer, null);
}

pub const Buffer = union(root.Backend) {
    Host: Host.Buffer,
    OpenCl: if (root.features.has_opencl) OpenCl.Buffer else noreturn,
};

pub export fn ucCreateBuffer(context: *root.context.Context, size: usize, config: *const BufferConfig, buffer: *Buffer) root.uc_result_t {
    _ = config;
    buffer.* = switch (context.*) {
        .Host => .{ .Host = Host.create(&context.Host, size) catch |e| return root.externError(e) },
        .OpenCl => if (!root.features.has_opencl) unreachable else .{ .OpenCl = OpenCl.create(&context.OpenCl, size) catch |e| return root.externError(e) },
    };
    return root.UC_RESULT_SUCCESS;
}

pub export fn ucBufferRead(
    self: *Buffer,
    offset: usize,
    len: usize,
    dst: *anyopaque,
    evt: ?*root.event.Event,
) root.uc_result_t {
    switch (self.*) {
        .Host => {
            const host_evt = Host.read(&self.Host, offset, len, dst) catch |e| return root.externError(e);
            if (evt) |e| e.* = .{ .Host = host_evt };
        },
        .OpenCl => if (!root.features.has_opencl) unreachable else {
            const cl_event = OpenCl.read(&self.OpenCl, offset, len, dst) catch |e| return root.externError(e);
            if (evt) |e| e.* = .{ .OpenCl = cl_event };
        },
    }
    return root.UC_RESULT_SUCCESS;
}

pub export fn ucBufferWrite(
    self: *Buffer,
    offset: usize,
    len: usize,
    src: *const anyopaque,
    evt: ?*root.event.Event,
) root.uc_result_t {
    switch (self.*) {
        .Host => {
            const host_evt = Host.write(&self.Host, offset, len, src) catch |e| return root.externError(e);
            if (evt) |e| e.* = .{ .Host = host_evt };
        },
        .OpenCl => if (!root.features.has_opencl) unreachable else {
            const cl_event = OpenCl.write(&self.OpenCl, offset, len, src) catch |e| return root.externError(e);
            if (evt) |e| e.* = .{ .OpenCl = cl_event };
        },
    }
    return root.UC_RESULT_SUCCESS;
}

pub export fn ucBufferCopy(
    src: *Buffer,
    src_offset: usize,
    dst: *Buffer,
    dst_offset: usize,
    len: usize,
    evt: ?*root.event.Event,
) root.uc_result_t {
    if (@as(root.Backend, src.*) != @as(root.Backend, dst.*)) {
        return root.externError(error.DiferentBackends);
    }

    switch (src.*) {
        .Host => {
            const host_evt = Host.copy(&src.Host, src_offset, &dst.Host, dst_offset, len) catch |e| return root.externError(e);
            if (evt) |e| e.* = .{ .Host = host_evt };
        },
        .OpenCl => if (!root.features.has_opencl) unreachable else {
            const cl_evt = OpenCl.copy(&src.OpenCl, src_offset, &dst.OpenCl, dst_offset, len) catch |e| return root.externError(e);
            if (evt) |e| e.* = .{ .OpenCl = cl_evt };
        },
    }

    return root.UC_RESULT_SUCCESS;
}

pub export fn ucBufferDeinit(buffer: *Buffer) root.uc_result_t {
    const res: anyerror!void = switch (buffer.*) {
        .Host => |buf| Host.deinit(buf),
        .OpenCl => |buf| if (!root.features.has_opencl) unreachable else buf.deinit(),
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
