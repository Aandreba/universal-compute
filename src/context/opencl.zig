const std = @import("std");
const root = @import("../main.zig");
const c = root.cl;

pub const Context = struct {
    context: c.cl_context,
    queue: c.cl_command_queue,

    pub fn info(self: *const Context, ty: root.context.ContextInfo, raw_data: ?*anyopaque, len: *usize) !void {
        switch (ty) {
            .BACKEND => {
                if (raw_data) |data| {
                    (try root.castOpaque(root.Backend, data, len.*)).* = .OpenCl;
                } else {
                    len.* = @sizeOf(root.Backend);
                }
            },
            .DEVICE => try self.getDevice(raw_data, len),
        }
    }

    fn getDevice(self: *const Context, raw_data: ?*anyopaque, len: *usize) !void {
        if (raw_data) |data| {
            var device: c.cl_device_id = undefined;
            try c.clError(c.clGetContextInfo(self.context, c.CL_CONTEXT_DEVICES, @sizeOf(c.cl_device_id), @ptrCast(*anyopaque, &device), null));
            try c.clError(c.clRetainDevice(device));
            (try root.castOpaque(root.device.Device, data, len.*)).* = .{ .OpenCl = device };
        } else {
            len.* = @sizeOf(root.device.Device);
        }
    }

    pub fn deinit(self: Context) !void {
        try c.clError(c.clReleaseCommandQueue(self.queue));
        try c.clError(c.clReleaseContext(self.context));
    }
};

pub fn create(device: c.cl_device_id, config: *const root.context.ContextConfig) !Context {
    var res: c.cl_int = undefined;

    const ctx = c.clCreateContext(
        null,
        1,
        &device,
        if (config.debug) notify else null,
        null,
        &res,
    );
    try c.clError(res);
    errdefer {
        _ = c.clReleaseContext(ctx);
    }

    var props: c.cl_command_queue_properties = comptime @intCast(c.cl_command_queue_properties, c.CL_QUEUE_OUT_OF_ORDER_EXEC_MODE_ENABLE);
    if (config.debug) props |= comptime @intCast(c.cl_command_queue_properties, c.CL_QUEUE_PROFILING_ENABLE);

    var queue: c.cl_command_queue = if (comptime c.CL_VERSION_2_0 == c.CL_TRUE)
        c.clCreateCommandQueueWithProperties(ctx, device, &[_:0]c.cl_queue_properties{props}, &res)
    else
        c.clCreateCommandQueue(ctx, device, props, &res);
    try c.clError(res);

    return .{
        .context = ctx,
        .queue = queue,
    };
}

fn notify(errinfo: [*c]const u8, _: ?*const anyopaque, _: usize, _: ?*anyopaque) callconv(.C) void {
    const info: [:0]const u8 = std.mem.span(errinfo);
    std.log.warn("{s}", .{info});
}
