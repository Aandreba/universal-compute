const root = @import("main.zig");

pub const Host = @import("backend/host.zig");
pub const OpenCl = @import("backend/opencl.zig");
pub const Cuda = @import("backend/cuda.zig");
pub const WebGpu = @import("backend/webgpu.zig");

pub const Backend = enum(u32) {
    Host,
    OpenCl,
    Cuda,
    WebGpu,
    _,

    pub fn getDevices(self: Backend, devices: []root.Device) !usize {
        return switch (self) {
            .Host => Host.getDevices(devices),
            else => return error.NotYetImplemented,
        };
    }
};
