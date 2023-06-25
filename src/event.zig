const std = @import("std");
const root = @import("main.zig");

const Arc = @import("zigrc").Arc;
pub const Host = @import("event/host.zig");
pub const Opencl = @import("event/opencl.zig");

comptime {
    root.checkLayout(Event, root.extern_sizes.EVENT_SIZE, root.extern_sizes.EVENT_ALIGN);
}

pub const Event = union(root.Backend) {
    Host: *Host.Event,
    OpenCl: root.cl.cl_event,
};

pub export fn ucEventOnComplete(
    event: *Event,
    cb: *const fn (root.uc_result_t, ?*anyopaque) callconv(.C) void,
    user_data: ?*anyopaque,
) root.uc_result_t {
    const res = switch (event.*) {
        .Host => |evt| Host.onComplete(evt, cb, user_data),
        .OpenCl => |evt| Opencl.onComplete(evt, cb, user_data),
    };
    res catch |e| return root.externError(e);
    return root.UC_RESULT_SUCCESS;
}

pub export fn ucEventRelease(event: *Event) root.uc_result_t {
    switch (event.*) {
        .Host => |evt| Host.release(evt),
        .OpenCl => |evt| return root.cl.externError(root.cl.clReleaseEvent(evt)),
    }
    return root.UC_RESULT_SUCCESS;
}

pub export fn ucEventRetain(event: *Event) root.uc_result_t {
    switch (event.*) {
        .Host => |evt| Host.retain(evt),
        .OpenCl => |evt| return root.cl.externError(root.cl.clRetainEvent(evt)),
    }
    return root.UC_RESULT_SUCCESS;
}

pub const Status = enum(u32) {
    PENDING = 0,
    RUNNING = 1,
    COMPLETE = 2,
};
