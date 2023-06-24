const std = @import("std");
const root = @import("main.zig");
const utils = @import("utils.zig");
const alloc = utils.alloc;

pub const Host = @import("device/host.zig");
pub const OpenCl = @import("device/opencl.zig");

comptime {
    root.checkLayout(Device, 2 * @sizeOf(usize), @alignOf(usize));
}

pub const Device = union(root.Backend) {
    Host: void,
    OpenCl: root.cl.cl_device_id,
};

pub export fn ucGetDevices(raw_backends: ?[*]const root.Backend, backends_len: usize, raw_devices: [*]Device, devices_len: *usize) root.uc_result_t {
    const backends = if (raw_backends) |raw| raw[0..backends_len] else &utils.enumList(root.Backend);
    var devices = raw_devices[0..devices_len.*];

    var count: usize = 0;
    for (backends) |backend| {
        const len = backend.getDevices(devices) catch |e| return root.externError(e);
        devices = devices[len..];
        count += len;
    }

    devices_len.* = count;
    return root.UC_RESULT_SUCCESS;
}

pub export fn ucDeviceInfo(self: *const Device, info: DeviceInfo, raw_ptr: ?*anyopaque, raw_len: *usize) root.uc_result_t {
    if (info == .BACKEND) {
        if (raw_ptr) |ptr| {
            const casted_ptr = root.castOpaque(root.Backend, ptr, raw_len.*) catch |e| return root.externError(e);
            casted_ptr.* = @as(root.Backend, self.*);
        }
        raw_len.* = @sizeOf(root.Backend);
        return root.UC_RESULT_SUCCESS;
    }

    const res = switch (self.*) {
        .Host => root.device.Host.getDeviceInfo(info, raw_ptr, raw_len),
        .OpenCl => |device| root.device.OpenCl.getDeviceInfo(info, device, raw_ptr, raw_len),
    };
    res catch |e| return root.externError(e);
    return root.UC_RESULT_SUCCESS;
}

pub export fn ucDeviceDeinit(self: *Device) root.uc_result_t {
    return switch (self.*) {
        .Host => root.UC_RESULT_SUCCESS,
        .OpenCl => |cl_device| root.cl.externError(root.cl.clReleaseDevice(cl_device)),
    };
}

pub const DeviceInfo = enum(usize) {
    BACKEND = 0,
    VENDOR = 1,
    NAME = 2,
    CORE_COUNT = 3,
    // in MHz
    MAX_FREQUENCY = 4,
};
