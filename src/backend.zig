const root = @import("main.zig");

pub const Kind = enum(usize) {
    Host = 0,
    OpenCl = 1,
    // Cuda,
    // WebGpu,

    pub fn getDevices(self: Kind, devices: []root.device.Device) !usize {
        return switch (self) {
            .Host => root.device.Host.getDevices(devices),
            .OpenCl => if (comptime root.features.has_opencl) root.device.OpenCl.getDevices(devices) else unreachable,
        };
    }
};

pub export fn ucBackendName(backend: Kind) [*:0]const u8 {
    return @tagName(backend);
}
