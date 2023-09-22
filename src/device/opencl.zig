const std = @import("std");
const root = @import("../main.zig");
const alloc = root.alloc;
const c = root.cl;

pub fn getDevices(devices: []root.device.Device) !usize {
    // Platforms
    var num_platforms: c.cl_uint = 0;
    try c.clError(c.clGetPlatformIDs(0, null, &num_platforms));
    var platforms = try alloc.alloc(c.cl_platform_id, @as(usize, @intCast(num_platforms)));
    defer alloc.free(platforms);
    try c.clError(c.clGetPlatformIDs(num_platforms, @as([*]c.cl_platform_id, @ptrCast(platforms)), null));

    // Devices
    var count: usize = 0;
    for (platforms) |platform| {
        if (count >= devices.len) break;

        var num_devices: c.cl_uint = undefined;
        try c.clError(c.clGetDeviceIDs(
            platform,
            c.CL_DEVICE_TYPE_ALL,
            0,
            null,
            &num_devices,
        ));

        var cl_devices = try alloc.alloc(c.cl_device_id, @min(
            @as(usize, @intCast(num_devices)),
            devices.len,
        ));
        defer alloc.free(cl_devices);

        try c.clError(c.clGetDeviceIDs(
            platform,
            c.CL_DEVICE_TYPE_ALL,
            @as(c.cl_uint, @intCast(cl_devices.len)),
            @as([*]c.cl_device_id, @ptrCast(cl_devices)),
            null,
        ));

        for (cl_devices, 0..) |cl_device, i| {
            devices[count + i] = .{ .OpenCl = cl_device };
        }

        count += cl_devices.len;
    }

    return count;
}

pub fn getDeviceInfo(info: root.device.DeviceInfo, device: c.cl_device_id, raw_ptr: ?*anyopaque, raw_len: *usize) !void {
    const raw_info = ucToclDeviceInfo(info);
    if (raw_ptr) |ptr| {
        switch (info) {
            // c.cl_uint --> usize
            .CORE_COUNT, .MAX_FREQUENCY => {
                var count: c.cl_uint = undefined;
                try c.clError(c.clGetDeviceInfo(device, raw_info, raw_len.*, &count, null));
                (try root.castOpaque(usize, ptr, raw_len.*)).* = @as(usize, @intCast(count));
            },
            else => {
                return c.clError(c.clGetDeviceInfo(device, raw_info, raw_len.*, ptr, null));
            },
        }
    } else {
        switch (info) {
            .CORE_COUNT, .MAX_FREQUENCY => raw_len.* = @sizeOf(usize),
            else => {
                return c.clError(c.clGetDeviceInfo(device, raw_info, 0, null, raw_len));
            },
        }
    }
}

fn ucToclDeviceInfo(info: root.device.DeviceInfo) c.cl_device_info {
    return switch (info) {
        .BACKEND => unreachable,
        .VENDOR => c.CL_DEVICE_VENDOR,
        .NAME => c.CL_DEVICE_NAME,
        .CORE_COUNT => c.CL_DEVICE_MAX_COMPUTE_UNITS,
        .MAX_FREQUENCY => c.CL_DEVICE_MAX_CLOCK_FREQUENCY,
    };
}
