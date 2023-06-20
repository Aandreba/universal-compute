const std = @import("std");

pub usingnamespace @import("utils.zig");
pub usingnamespace @import("backend.zig");
pub usingnamespace @import("error.zig");
pub usingnamespace @import("device.zig");
pub const Context = @import("context.zig");

pub fn castOpaque(comptime T: type, ptr: *anyopaque) *T {
    return @ptrCast(*T, @alignCast(@alignOf(T), ptr));
}

test {
    @setEvalBranchQuota(2000);
    std.testing.refAllDecls(Context);
}
