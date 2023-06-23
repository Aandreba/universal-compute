/*
const std = @import("std");
const uc = @import("uc");

const alloc = std.heap.c_allocator;

pub fn main() !void {
    var devices = try alloc.alloc(uc.device.Device, 2);
    defer alloc.free(devices);

    var len = devices.len;
    try uc.resultToError(uc.device.ucGetDevices(null, 0, devices.ptr, &len));

    for (devices[0..len]) |*device| {
        var info_len: usize = undefined;
        try uc.resultToError(uc.ucDeviceInfo(device, .NAME, null, &info_len));

        var name = try alloc.alloc(u8, info_len);
        defer alloc.free(name);
        try uc.resultToError(uc.ucDeviceInfo(device, .NAME, name.ptr, &info_len));
        name = name[0..info_len];

        var cores: usize = undefined;
        try uc.resultToError(uc.ucDeviceInfo(device, .CORE_COUNT, &cores, null));

        std.debug.print("{s}: {} core(s)\n", .{ name, cores });
    }
}

*/
#include <universal-compute.h>

int main() {
}
