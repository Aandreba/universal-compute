const std = @import("std");
const root = @import("main.zig");

pub const Host = @import("context/host.zig");
pub const OpenCl = @import("context/opencl.zig");

comptime {
    root.exportLayout(Context);
}

pub const Context = union(root.Backend) {
    Host: Host.Context,
    OpenCl: OpenCl.Context,
};

pub export fn ucCreateContext(device: *root.device.Device, config: *const ContextConfig, context: *Context) root.uc_result_t {
    context.* = switch (device.*) {
        .Host => .{ .Host = Host.create() catch |e| return root.externError(e) },
        .OpenCl => |cl_device| .{ .OpenCl = OpenCl.create(cl_device, config) catch |e| return root.externError(e) },
    };
    return root.UC_RESULT_SUCCESS;
}

pub export fn ucContextInfo(self: *const Context, info: ContextInfo, raw_data: ?*anyopaque, len: *usize) root.uc_result_t {
    const res = switch (self.*) {
        .Host => Host.info(info, raw_data, len),
        .OpenCl => |*ctx| ctx.info(info, raw_data, len),
    };
    res catch |e| return root.externError(e);
    return root.UC_RESULT_SUCCESS;
}

pub export fn ucContextDeinit(self: *Context) root.uc_result_t {
    const res = switch (self.*) {
        .Host => |*ctx| ctx.deinit(),
        .OpenCl => |ctx| ctx.deinit(),
    };
    res catch |e| return root.externError(e);
    return root.UC_RESULT_SUCCESS;
}

// OTHER TYPES
pub const ContextConfig = extern struct {
    debug: bool,
};

pub const ContextInfo = enum(usize) {
    BACKEND = 0,
    DEVICE = 1,
};
