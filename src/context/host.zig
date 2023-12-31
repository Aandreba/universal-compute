const std = @import("std");
const root = @import("../main.zig");
const zigrc = @import("zigrc");

const Event = root.event.Host.Event;
const Arc = zigrc.Arc;

pub const Context = union(enum) {
    Single: SingleContext,
    Multi: *MultiContext,

    pub fn eql(self: *Context, other: *Context) bool {
        return switch (self.*) {
            .Single => |lhs| switch (other.*) {
                .Single => |rhs| lhs.context_id == rhs.context_id,
                else => false,
            },
            .Multi => |lhs| switch (other.*) {
                .Multi => |rhs| lhs == rhs,
                else => false,
            },
        };
    }

    pub fn deinit(self: *Context) void {
        return switch (self.*) {
            .Single => return,
            .Multi => |ctx| ctx.deinit(),
        };
    }
};

pub fn create() !Context {
    return switch (try root.device.Host.getCoreCount()) {
        0 => unreachable,
        1 => .{ .Single = SingleContext.init() },
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
        .Single => ctx.Single.finish(),
        .Multi => |c| c.finish(),
    };
}

// Context for single-threaded devices
const SingleContext = struct {
    context_id: u32,
    queue: std.ArrayListUnmanaged(Task) = .{},
    queue_lock: if (root.use_atomics) std.Thread.Mutex else noreturn = if (root.use_atomics) .{} else {},

    var context_id_count = std.atomic.Atomic(u32).init(0);

    pub fn init() SingleContext {
        return .{
            .context_id = if (root.use_atomics) context_id_count.fetchAdd(1, .Monotonic) else brk: {
                const prev = context_id_count.value;
                context_id_count.value += 1;
                break :brk prev;
            },
        };
    }

    pub fn enqueue(self: *SingleContext, comptime f: anytype, args: anytype) !Arc(Event) {
        const Args = @TypeOf(args);
        const Impl = struct {
            fn run(user_data: *anyopaque) anyerror!void {
                if (comptime @sizeOf(Args) == 0) {
                    try @call(.auto, f, undefined);
                } else {
                    const args_ptr = @as(*Args, @ptrCast(@alignCast(user_data)));
                    defer root.alloc.destroy(args_ptr);
                    try @call(.auto, f, args_ptr.*);
                }
            }
        };

        var event: Arc(Event) = try Arc(Event).init(root.alloc, .{ .workers = 1 });
        errdefer event.releaseWithFn(Event.deinit);

        const user_data = if (comptime @sizeOf(Args) == 0) undefined else try root.alloc.create(Args);
        if (comptime @sizeOf(Args) > 0) user_data.* = args;
        errdefer root.alloc.destroy(user_data);

        self.lock();
        defer self.unlock();

        try self.queue.append(root.alloc, .{
            .f = Impl.run,
            .user_data = user_data,
            .event = event.downgrade(),
        });

        return event;
    }

    pub fn finish(self: *SingleContext) !void {
        self.lock();
        defer self.unlock();

        while (self.queue.items.len > 0) {
            const task: Task = self.queue.pop();
            task.run(1);
        }
    }

    inline fn lock(self: *SingleContext) void {
        if (comptime root.use_atomics) self.queue_lock.lock();
    }

    inline fn unlock(self: *SingleContext) void {
        if (comptime root.use_atomics) self.queue_lock.unlock();
    }
};

// Context for multi-threaded devices
const MultiContext = struct {
    threads: []std.Thread,
    tasks: std.ArrayListUnmanaged(Task),
    tasks_lock: std.Thread.RwLock,
    is_running: std.atomic.Atomic(bool),

    pub fn init(cores: usize) !*MultiContext {
        var ctx = try root.alloc.create(MultiContext);
        errdefer root.alloc.destroy(ctx);

        ctx.* = .{
            .threads = try root.alloc.alloc(std.Thread, cores),
            .tasks = .{},
            .tasks_lock = .{},
            .is_running = std.atomic.Atomic(bool).init(true),
        };

        var i: usize = 0;
        errdefer {
            ctx.threads.len = i;
            ctx.deinit();
        }

        while (i < cores) {
            ctx.threads[i] = try std.Thread.spawn(.{}, worker, .{ctx});
            i += 1;
        }

        return ctx;
    }

    pub fn enqueue(self: *MultiContext, comptime f: anytype, args: anytype, event: *Arc(Event)) !void {
        const Args = @TypeOf(args);
        const Impl = struct {
            fn run(user_data: *anyopaque) anyerror!void {
                if (comptime @sizeOf(Args) == 0) {
                    try @call(.auto, f, undefined);
                } else {
                    const args_ptr = @as(*Args, @ptrCast(@alignCast(user_data)));
                    defer root.alloc.destroy(args_ptr);
                    try @call(.auto, f, args_ptr.*);
                }
            }
        };

        const user_data = if (comptime @sizeOf(Args) == 0) undefined else try root.alloc.create(Args);
        if (comptime @sizeOf(Args) > 0) user_data.* = args;
        errdefer root.alloc.destroy(user_data);

        self.tasks_lock.lock();
        defer self.tasks_lock.unlock();

        try self.tasks.append(root.alloc, .{
            .f = Impl.run,
            .user_data = user_data,
            .event = event.downgrade(),
        });
    }

    fn worker(self: *MultiContext) void {
        var yield: u2 = 2;

        while (self.is_running.load(.Monotonic)) {
            self.tasks_lock.lockShared();

            // Wait for tasks to be available
            if (self.tasks.items.len == 0) {
                self.tasks_lock.unlockShared();
                switch (yield) {
                    0 => {
                        root.yield() catch std.atomic.spinLoopHint();
                        yield = 2;
                    },
                    1, 2 => {
                        std.atomic.spinLoopHint();
                        yield -= 1;
                    },
                    else => unreachable,
                }

                continue;
            }

            // Unlock shared
            self.tasks_lock.unlockShared();
            yield = 2;

            // Pop task from the queue
            var task: Task = brk: {
                self.tasks_lock.lock();
                defer self.tasks_lock.unlock();

                if (self.tasks.items.len == 0) continue;
                break :brk self.tasks.swapRemove(0);
            };

            // Execute task
            task.run();
        }
    }

    pub fn finish(self: *MultiContext) !void {
        self.tasks_lock.lock();
        defer self.tasks_lock.unlock();

        for (self.tasks.items) |task| {
            task.event.join();
        }
    }

    pub fn deinit(self: *MultiContext) void {
        self.is_running.store(false, .Release);
        for (self.threads) |thread| thread.join();

        self.tasks.deinit(root.alloc);
        root.alloc.free(self.threads);
        root.alloc.destroy(self);
    }
};

const Task = struct {
    f: *const fn (*anyopaque) anyerror!void,
    user_data: *anyopaque,
    event: Arc(Event).Weak,

    fn run(self: *Task) void {
        defer self.event.release();

        const event: ?Arc(Event) = self.event.upgrade();
        if (event) |evt| evt.value.markRunning();

        const res: ?anyerror = brk: {
            (self.f)(self.user_data) catch |e| break :brk e;
            break :brk null;
        };

        if (event) |evt| {
            evt.value.markComplete(res) catch @panic("OOM");
            evt.releaseWithFn(Event.deinit);
        }
    }
};
