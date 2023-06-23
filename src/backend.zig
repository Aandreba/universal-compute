const root = @import("main.zig");

pub const Host = @import("backend/host.zig");
pub const OpenCl = @import("backend/opencl.zig");

pub const Kind = enum(u32) {
    Host,
    OpenCl,
    // Cuda,
    // WebGpu,

    pub fn getDeviceData(comptime self: Kind, ptr: ?*anyopaque) switch (self) {
        .Host => null,
        .OpenCl => OpenCl.c.cl_device_id,
    } {
        switch (self) {
            .Host => null,
            .OpenCl => @ptrCast(OpenCl.c.cl_device_id, ptr),
            else => null,
        }
    }

    pub fn getDevices(self: Kind, devices: []root.device.Device) !usize {
        return switch (self) {
            .Host => Host.getDevices(devices),
            .OpenCl => OpenCl.getDevices(devices),
        };
    }
};
