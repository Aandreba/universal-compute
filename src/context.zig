const std = @import("std");
const root = @import("main.zig");

pub const Host = @import("context/host.zig");
pub const OpenCl = @import("context/opencl.zig");

comptime {
    std.debug.assert(@sizeOf(Context) == 3 * @sizeOf(usize));
    std.debug.assert(@alignOf(Context) == @alignOf(usize));
}

pub const Context = union(root.backend.Kind) {
    Host: Host.Context,
    OpenCl: OpenCl.Context,
};

pub export fn ucCreateContext(device: *root.device.Device, config: *const ContextConfig, context: *Context) root.uc_result_t {
    context.* = switch (device) {
        .Host => Host.create(),
        .OpenCl => |cl_device| OpenCl.create(cl_device, config),
    } catch |e| return root.externError(e);
    return root.UC_RESULT_SUCCESS;
}

pub export fn ucContextInfo(self: *Context) root.uc_result_t {
    _ = self;
    // TODO
    return root.UC_RESULT_SUCCESS;
}

pub export fn ucContextDeinit(self: *Context) root.uc_result_t {
    _ = self;
    // TODO
    return root.UC_RESULT_SUCCESS;
}

// OTHER TYPES
pub const ContextConfig = extern struct {
    debug: bool,
};

pub const ContextInfo = enum(u32) {
    DEVICE,
};
