const std = @import("std");
const uc = @import("uc");

const alloc = std.heap.c_allocator;

pub fn main() !void {
    var devices = try alloc.alloc(uc.Device, 2);
    defer alloc.free(devices);

    var len = devices.len;
    try uc.resultToError(uc.ucGetDevices(null, 0, devices.ptr, &len));

    for (devices[0..len]) |*device| {
        var name_len: usize = undefined;
        try uc.resultToError(uc.ucDeviceInfo(device, .VENDOR, null, &name_len));

        var name = try alloc.alloc(u8, name_len);
        defer alloc.free(name);
        try uc.resultToError(uc.ucDeviceInfo(device, .VENDOR, name.ptr, &name_len));

        std.debug.print("{s}\n", .{name[0..name_len]});
    }
}
