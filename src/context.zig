const std = @import("std");
const root = @import("main.zig");
const Context = @This();

device: root.Device,

pub export fn ucCreateContext(device: *root.Device, options: *const ContextOptions) root.uc_result_t {
    _ = options;
    _ = device;
    // TODO
    return root.UC_RESULT_SUCCESS;
}

pub export fn ucContextInfo(self: *Context) root.uc_result_t {
    _ = self;
    // TODO
    return root.UC_RESULT_SUCCESS;
}

// OTHER TYPES
pub const ContextOptions = extern struct {};

pub const ContextInfo = enum(u32) {
    DEVICE,
};
