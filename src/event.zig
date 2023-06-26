const std = @import("std");
const root = @import("main.zig");

pub const Host = @import("event/host.zig");
pub const OpenCl = if (root.features.has_opencl) @import("event/opencl.zig") else struct {};

comptime {
    root.exportLayout(Event);
}

pub const Event = union(root.Backend) {
    Host: *Host.Event,
    OpenCl: if (root.features.has_opencl) root.cl.cl_event else void,
};

pub export fn ucEventJoin(event: *Event) root.uc_result_t {
    const res = switch (event.*) {
        .Host => |evt| Host.join(evt),
        .OpenCl => if (!root.features.has_opencl) unreachable else OpenCl.join(&event.OpenCl),
    };
    res catch |e| return root.externError(e);
    return root.UC_RESULT_SUCCESS;
}

pub export fn ucEventOnComplete(
    event: *Event,
    cb: *const fn (root.uc_result_t, ?*anyopaque) callconv(.C) void,
    user_data: ?*anyopaque,
) root.uc_result_t {
    const res = switch (event.*) {
        .Host => |evt| Host.onComplete(evt, cb, user_data),
        .OpenCl => |evt| if (!root.features.has_opencl) unreachable else OpenCl.onComplete(evt, cb, user_data),
    };
    res catch |e| return root.externError(e);
    return root.UC_RESULT_SUCCESS;
}

pub export fn ucEventRelease(event: *Event) root.uc_result_t {
    switch (event.*) {
        .Host => |evt| Host.release(evt),
        .OpenCl => |evt| if (!root.features.has_opencl) unreachable else return root.cl.externError(root.cl.clReleaseEvent(evt)),
    }
    return root.UC_RESULT_SUCCESS;
}

pub export fn ucEventRetain(event: *Event) root.uc_result_t {
    switch (event.*) {
        .Host => |evt| Host.retain(evt),
        .OpenCl => |evt| if (!root.features.has_opencl) unreachable else return root.cl.externError(root.cl.clRetainEvent(evt)),
    }
    return root.UC_RESULT_SUCCESS;
}

pub const Status = enum(u32) {
    PENDING = 0,
    RUNNING = 1,
    COMPLETE = 2,
};
