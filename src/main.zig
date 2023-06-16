const std = @import("std");
const alloc = std.heap.page_allocator;

pub const device_t = *align(@alignOf(Device)) anyopaque;

const Device = struct {
    vandor: ?[]const u8,
    name: ?[]const u8,
    cores: usize,
};

pub export fn cuDeinitDevice(device: device_t) callconv(.C) void {
    alloc.destroy(@ptrCast(*Device, device));
}
