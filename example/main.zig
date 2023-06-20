const std = @import("std");
const uc = @cImport(@cInclude("universal-compute.h"));

const alloc = std.heap.c_allocator;

pub fn main() !void {
    var devices = try alloc.alloc(uc.Device, 2);
    defer alloc.free(devices);
    const len = uc.ucGetDevices(null, 0, devices.ptr, devices.len);
    std.debug.print("{any}", .{devices[0..len]});
}
