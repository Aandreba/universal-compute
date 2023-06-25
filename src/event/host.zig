const std = @import("std");
const builtin = @import("builtin");
const root = @import("../main.zig");

const ArcEvent = @import("zigrc").Arc(Event);
// TODO add support for Wasm atomics
const use_atomics: bool = !builtin.single_threaded;

pub const Event = struct {
    status: root.event.Status = .PENDING,
    cbs: CallbackQueue = .{ .queue = .{} },
    cbs_lock: if (use_atomics) std.Thread.Mutex else void = if (use_atomics) .{} else {},

    const CallbackQueue = union(enum) {
        marked: root.uc_result_t,
        queue: std.ArrayListUnmanaged(Callback),
    };

    pub fn markRunning(self: *Event) !void {
        if (comptime (builtin.mode == .Debug or builtin.mode == .ReleaseSafe) and use_atomics) {
            std.debug.assert(@atomicRmw(
                root.event.Status,
                &self.status,
                .Xchg,
                .RUNNING,
                .Release,
            ) == .PENDING);
        } else if (comptime use_atomics) {
            @atomicStore(root.event.Status, &self.status, .RUNNING, .Release);
        } else {
            std.debug.assert(self.status == .PENDING);
            self.status = .RUNNING;
        }
    }

    pub fn markComplete(self: *Event, res: ?anyerror) !void {
        if (comptime (builtin.mode == .Debug or builtin.mode == .ReleaseSafe) and use_atomics) {
            std.debug.assert(@atomicRmw(
                root.event.Status,
                &self.status,
                .Xchg,
                .COMPLETE,
                .Release,
            ) == .RUNNING);
        } else if (comptime use_atomics) {
            @atomicStore(root.event.Status, &self.status, .COMPLETE, .Release);
        } else {
            std.debug.assert(self.status == .RUNNING);
            self.status = .COMPLETE;
        }

        const c_res = if (res) |e| root.externError(e) else root.UC_RESULT_SUCCESS;
        var cbs: []Callback = undefined;
        {
            self.lock();
            defer self.unlock();
            cbs = switch (self.cbs) {
                .queue => |q| try q.toOwnedSlice(root.alloc),
                .marked => unreachable,
            };
            self.cbs = .{ .marked = c_res };
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
