const std = @import("std");
const root = @import("main.zig");

pub const Host = @import("context/host.zig");
//pub const OpenCl = @import("context/opencl.zig");

pub const Context = union(root.backend.Kind) {
    Host: Host.Context,
    OpenCl: @compileError("todo"),
};

pub export fn ucCreateContext(device: *root.device.Device, config: *const ContextConfig) root.uc_result_t {
    _ = config;
    _ = device;
    // TODO
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
