const std = @import("std");
const root = @import("main.zig");
const utils = @import("utils.zig");
const alloc = utils.alloc;

pub const Device = union(root.Backend) {
    Host: void,
    OpenCl: root.OpenCl.c.cl_device_id,

    pub export fn ucGetDevices(raw_backends: ?[*]const root.Backend, backends_len: usize, raw_devices: [*]Device, devices_len: usize) root.uc_error_t {
        const backends = if (raw_backends) |raw| raw[0..backends_len] else &utils.enumList(root.Backend);
        var devices = raw_devices[0..devices_len];

        for (backends) |backend| {
            const len = backend.getDevices(devices) catch |e| return root.externError(e);
            devices = devices[len..];
        }

        return 0;
    }

    pub export fn ucDeviceDeinit(self: *Device) void {
        if (self.vendor) |vendor| alloc.free(vendor);
        if (self.name) |name| alloc.free(name);
    }

    pub const Info = enum(usize) {
        VENDOR,
        NAME,
        CORE_COUNT,
    };
};
