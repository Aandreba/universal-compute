const utils = @import("utils.zig");

pub const Device = struct {
    vendor: ?[]const u8,
    name: ?[]const u8,
    cores: usize,
};

pub export fn cuDeviceDeinit(device: *Device) void {
    utils.alloc.destroy(device);
}
