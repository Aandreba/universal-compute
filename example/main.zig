const std = @import("std");
const uc = @import("uc");

const alloc = std.heap.c_allocator;

pub fn main() !void {
    var devices = try alloc.alloc(uc.Device, 2);
    defer alloc.free(devices);

    var len = devices.len;
    try uc.resultToError(uc.ucGetDevices(null, 0, devices.ptr, &len));

    for (devices[0..len]) |device| {
        std.debug.print("{}", .{uc.ucDeviceInfo(device, .NAME, null, null)});
    }
}
