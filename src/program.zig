const std = @import("std");
const builtin = @import("builtin");
const root = @import("main.zig");

pub const Host = @import("program/host.zig");
pub const OpenCl = if (root.features.has_opencl) @import("program/opencl.zig") else struct {};

pub const Program = union(root.Backend) {
    Host: Host.Program,
    OpenCl: if (root.features.has_opencl) OpenCl.Program else void,
};
