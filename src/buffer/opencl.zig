const std = @import("std");
const root = @import("../main.zig");
const c = root.cl;

pub const Buffer = struct {
    mem: c.cl_mem,
    queue: c.cl_command_queue,

    pub fn getContext(self: *const Buffer) !c.cl_context {
        var ctx: c.cl_context = undefined;
        try c.clError(c.clGetMemObjectInfo(self.mem, c.CL_MEM_CONTEXT, @sizeOf(c.cl_context), &ctx, null));
        return ctx;
    }

    pub inline fn deinit(self: Buffer) !void {
        try c.clError(c.clReleaseMemObject(self.mem));
    }
};

// TODO mem flags
pub fn create(ctx: *root.context.OpenCl.Context, size: usize) !Buffer {
    var res: c.cl_int = undefined;
    const mem = c.clCreateBuffer(ctx.context, 0, size, null, &res);
    try c.clError(res);
    return .{ .mem = mem, .queue = ctx.queue };
}

pub fn read(self: *Buffer, offset: usize, len: usize, raw_dst: *anyopaque) !c.cl_event {
    var event: c.cl_event = undefined;
    try c.clError(c.clEnqueueReadBuffer(self.queue, self.mem, c.CL_FALSE, offset, len, raw_dst, 0, null, &event));
    return event;
}

pub fn write(self: *Buffer, offset: usize, len: usize, raw_src: *const anyopaque) !c.cl_event {
    var event: c.cl_event = undefined;
    try c.clError(c.clEnqueueWriteBuffer(self.queue, self.mem, c.CL_FALSE, offset, len, raw_src, 0, null, &event));
    return event;
}

pub fn copy(src: *Buffer, src_offset: usize, dst: *Buffer, dst_offset: usize, len: usize) !c.cl_event {
    // TODO do we need to check if the queues are the same?
    var event: c.cl_event = undefined;
    try c.clError(c.clEnqueueCopyBuffer(src.queue, src.mem, dst.mem, src_offset, dst_offset, len, 0, null, &event));
    return event;
}
