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

pub fn finish(ctx: *Context) !void {
    return switch (ctx.*) {
        .Single => |*c| c.finish(),
    };
}


// Context for single-threaded devices
const SingleContext = struct {
    queue: std.ArrayListUnmanaged(Task),
    queue_lock: if (root.use_atomics) std.Thread.Mutex else void = if (root.use_atomics) .{} else {},

    pub fn enqueue(self: *SingleContext, comptime f: anytype, args: anytype) void {
        const Args = @TypeOf(args);
        const Impl = struct {
            fn run(user_data: *anyopaque) anyerror!void {
                if (comptime @sizeOf(Args) == 0) {
                    try @call(.Auto, f, undefined);
                } else {
                    const args_ptr = @ptrCast(*Args, @alignCast(@alignOf(Args), user_data));
                    try @call(.Auto, f, args_ptr.*);
                }
            }
        };
        
        self.queue.append(root.alloc, Impl.run);
    }

    pub fn finish(self: *SingleContext) !void {
        self.lock();
        defer self.unlock();

        while (self.queue.items.len > 0) {
            const task = self.queue.pop();
            try task.run();
        }
    }

    inline fn lock(self: *SingleContext) void {
        if (comptime root.use_atomics) self.queue_lock.lock();
    }

    inline fn unlock(self: *SingleContext) void {
        if (comptime root.use_atomics) self.queue_lock.unlock();
    }

    const Task = struct {
        f: *const fn(*anyopaque) anyerror!void,
        user_data: *anyopaque,

        inline fn run(self: Task) !void {
            return (self.f)(self.user_data);
        }
    };
};

// Context for multi-threaded devices
const MultiContext = struct {
    threads: []std.Thread,

    pub fn init(cores: usize) !MultiContext {
        var threads: []std.Thread = try root.alloc.alloc(std.Thread, cores);

        var i = 0;
        errdefer for (threads[0..i]) |thread| thread.detach();
        while (i < cores) {
            i += 1;
        }

        return .{ .threads = threads };
    }

    pub fn finish(self: *MultiContext) void {
        self.pool.spawn(comptime func: anytype, args: anytype)
    }

    pub fn deinit(self: *MultiContext) void {
        self.pool.deinit();
        root.alloc.destroy(self.pool);
    }
};
