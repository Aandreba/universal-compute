const std = @import("std");
pub const backend = @import("backend.zig");
pub const device = @import("device.zig");
pub const context = @import("context.zig");

pub usingnamespace @import("utils.zig");
pub usingnamespace @import("error.zig");
usingnamespace backend;
usingnamespace device;
usingnamespace context;

pub const AllocLayout = extern struct {
    size: usize,
    @"align": usize,

    pub fn init(comptime T: type) AllocLayout {
        return .{
            .size = @sizeOf(T),
            .@"align" = @alignOf(T),
        };
    }
};

pub fn castOpaque(comptime T: type, ptr: *anyopaque) *T {
    return @ptrCast(*T, @alignCast(@alignOf(T), ptr));
}
