const std = @import("std");
const root = @import("../main.zig");

pub const Context = union(enum) {
    Single: SingleContext,
    Multi: MultiContext,

    pub fn deinit(self: *Context) void {
        switch (self.*) {
            .Single => return,
            .Multi => |*ctx| ctx.deinit(),
        }
    }
};

pub fn create() !Context {
    return switch (try root.device.Host.getCoreCount()) {
        0 => unreachable,
        1 => .{ .Single = .{} },
        else => |cc| .{ .Multi = try MultiContext.init(cc) },
    };
}

pub fn info(ty: root.context.ContextInfo, raw_data: ?*anyopaque, len: *usize) !void {
    if (raw_data) |data| {
        switch (ty) {
            .BACKEND => (try root.castOpaque(root.Backend, data, len.*)).* = .Host,
            .DEVICE => (try root.castOpaque(root.device.Device, data, len.*)).* = .Host,
        }
    } else {
        switch (ty) {
            .BACKEND => len.* = @sizeOf(root.Backend),
            .DEVICE => len.* = @sizeOf(root.device.Device),
        }
    }
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

    pub fn deinit(self: *MultiContext) void {
        self.pool.deinit();
    }
};
