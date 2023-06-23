const root = @import("main.zig");

pub const Kind = enum(usize) {
    Host = 0,
    OpenCl = 1,
    // Cuda,
    // WebGpu,
};
