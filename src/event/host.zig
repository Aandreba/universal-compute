const std = @import("std");
const builtin = @import("builtin");
const root = @import("../main.zig");

const AtomicU32 = std.atomic.Atomic(u32);
const ArcEvent = @import("zigrc").Arc(Event);
const use_atomics: bool = root.use_atomics;

pub const PENDING = std.math.maxInt(u32);

pub const Event = struct {
    status: AtomicU32 = AtomicU32.init(PENDING),
    cbs: CallbackQueue = .{ .queue = .{} },
    cbs_lock: if (use_atomics) std.Thread.Mutex else void = if (use_atomics) .{} else {},
    workers: u32,

    const CallbackQueue = union(enum) {
        marked: root.uc_result_t,
        queue: std.ArrayListUnmanaged(Callback),
    };

    pub fn markRunning(self: *Event) void {
        std.debug.assert(self.workers != PENDING);
        if (comptime use_atomics) {
            self.status.store(self.workers, .Release);
        } else {
            std.debug.assert(self.status == PENDING);
            self.status.storeUnchecked(self.workers);
        }
    }

    pub fn markComplete(self: *Event, res: ?anyerror) !void {
        const c_res = if (res) |e| root.externError(e) else root.UC_RESULT_SUCCESS;
        var cbs: []Callback = undefined;
        {
            self.lock();
            defer self.unlock();
            cbs = switch (self.cbs) {
                .queue => |*q| try q.toOwnedSlice(root.alloc),
                .marked => unreachable,
            };
            self.cbs = .{ .marked = c_res };
        }

        if (comptime use_atomics) {
            const prev = self.status.fetchSub(1, .Release);
            if (prev == 1) std.Thread.Futex.wake(&self.status, self.workers);
        } else {
            self.status.storeUnchecked(self.status.loadUnchecked() - 1);
        }

        for (cbs) |cb| cb.call(c_res);
    }

    pub fn deinit(self: Event) void {
        var this = self;
        switch (this.cbs) {
            .queue => |*queue| queue.deinit(root.alloc),
            .marked => {},
        }
    }

    inline fn lock(self: *Event) void {
        if (comptime use_atomics) self.cbs_lock.lock();
    }

    inline fn unlock(self: *Event) void {
        if (comptime use_atomics) self.cbs_lock.unlock();
    }
};

pub fn join(self: *Event) !void {
    if (comptime use_atomics) {
        while (true) {
            switch (@atomicLoad(root.event.Status, &self.status, .Acquire)) {
                .COMPLETE => return,
                else => |status| std.Thread.Futex.wait(@ptrCast(*const std.atomic.Atomic(u32), &self.status), @enumToInt(status)),
            }
        }
    } else {
        if (self.status != .COMPLETE) return error.Deadlock;
    }
}

pub fn onComplete(self: *Event, f: *const fn (root.uc_result_t, ?*anyopaque) callconv(.C) void, user_data: ?*anyopaque) !void {
    const cb = Callback{
        .f = f,
        .user_data = user_data,
    };
    self.lock();
    defer self.unlock();
    switch (self.cbs) {
        .queue => |*cbs| try cbs.append(root.alloc, cb),
        .marked => |c_res| cb.call(c_res),
    }
}

pub inline fn release(self: *Event) void {
    const arc = ArcEvent{
        .value = self,
        .alloc = root.alloc,
    };
    arc.releaseWithFn(Event.deinit);
}

pub inline fn retain(self: *Event) void {
    var arc = ArcEvent{
        .value = self,
        .alloc = root.alloc,
    };
    _ = arc.retain();
}

const Callback = struct {
    f: *const fn (root.uc_result_t, ?*anyopaque) callconv(.C) void,
    user_data: ?*anyopaque,

    inline fn call(self: Callback, c_res: root.uc_result_t) void {
        (self.f)(c_res, self.user_data);
    }
};
