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
