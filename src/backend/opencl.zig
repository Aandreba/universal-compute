const std = @import("std");
const root = @import("../main.zig");
const c = @cImport(@cInclude("CL/cl.h"));
const alloc = root.alloc;

pub fn getDevices(devices: []root.Device) !usize {
    // Platforms
    var num_platforms: c.cl_uint = 0;
    try clError(c.clGetPlatformIDs(0, null, &num_platforms));
    var platforms = try alloc.alloc(c.cl_platform_id, @intCast(usize, num_platforms));
    defer alloc.free(platforms);
    try clError(c.clGetPlatformIDs(num_platforms, &platforms, null));

    // Devices
    var count: usize = 0;
    for (platforms) |platform| {

        // Get devices
        var num_devices: c.cl_int = undefined;
        try clError(c.clGetDeviceIDs(
            platform,
            c.CL_DEVICE_TYPE_ALL,
            0,
            null,
            &num_devices,
        ));
        var cl_devices = try alloc.alloc(c.cl_device_id, std.math.min(
            @intCast(usize, num_devices),
            devices.len,
        ));
        defer alloc.free(devices);
        try clError(c.clGetDeviceIDs(
            platform,
            c.CL_DEVICE_TYPE_ALL,
            cl_devices.len,
            &devices,
            null,
        ));

        for (cl_devices, 0..) |cl_device, i| {
            // Vendor name
            var vendor_len: c.cl_uint = undefined;
            try clError(c.clGetDeviceInfo(cl_device, c.CL_DEVICE_VENDOR, 0, null, &vendor_len));
            var vendor = try alloc.alloc(c_char, @intCast(usize, vendor_len));
            defer alloc.free(vendor);
            try clError(c.clGetDeviceInfo(
                cl_device,
                c.CL_DEVICE_VENDOR,
                vendor_len,
                @ptrCast(*anyopaque, vendor.ptr),
                null,
            ));

            // Name
            var name_len: c.cl_uint = undefined;
            try clError(c.clGetDeviceInfo(cl_device, c.CL_DEVICE_NAME, 0, null, &vendor_len));
            var name = try alloc.alloc(c_char, @intCast(usize, name_len));
            defer alloc.free(name);
            try clError(c.clGetDeviceInfo(
                cl_device,
                c.CL_DEVICE_NAME,
                name_len,
                @ptrCast(*anyopaque, name.ptr),
                null,
            ));

            // Cores (compute units)
            var cores: c.cl_uint = undefined;
            try clError(c.clGetDeviceInfo(
                cl_device,
                c.CL_DEVICE_MAX_COMPUTE_UNITS,
                @sizeOf(c.cl_uint),
                @ptrCast(*anyopaque, &cores),
                null,
            ));

            devices[i] = .{
                .vendor = @ptrCast([]const u8, vendor),
                .name = @ptrCast([]const u8, name),
                .cores = @intCast(usize, cores),
                .backend = .OpenCl,
                .backend_data = @ptrCast(?*anyopaque, cl_device),
            };
        }

        count += cl_devices.len;
        devices = devices[cl_devices.len..];
    }

    return count;
}

fn clError(e: c.cl_int) !void {
    return switch (e) {
        c.CL_SUCCESS => return,
        else => error.Unknown,
    };
}
