const std = @import("std");
pub const backend = @import("backend.zig");
pub const device = @import("device.zig");
pub const context = @import("context.zig");

pub usingnamespace @import("utils.zig");
pub usingnamespace @import("error.zig");

pub export const UC_DEVICE_SIZE: usize = @sizeOf(device.Device);

pub fn castOpaque(comptime T: type, ptr: *anyopaque) *T {
    return @ptrCast(*T, @alignCast(@alignOf(T), ptr));
}

fn COpaque(comptime T: type) type {
    return extern struct { [@sizeOf(T)]u8 align(@alignOf(T)) };
}
