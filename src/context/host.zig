const std = @import("std");
const root = @import("../main.zig");

pub const Context = union(enum) {
    Single: SingleContext,
    Multi: MultiContext,
};

pub fn create() !Context {
    return switch (try root.device.Host.getCoreCount()) {
        0 => unreachable,
        1 => .{ .Single = .{} },
        else => |cc| .{ .Multi = try MultiContext.init(cc) },
    };
}

// Context for single-threaded devices
const SingleContext = struct {};

// Context for multi-threaded devices
const MultiContext = struct {
    pool: std.Thread.Pool,

    pub fn init(cores: usize) !MultiContext {
        var pool: std.Thread.Pool = undefined;
        try std.Thread.Pool.init(&pool, .{
            .allocator = root.alloc,
            .n_jobs = std.math.cast(u32, cores),
        });

        return .{ .pool = pool };
    }
};
