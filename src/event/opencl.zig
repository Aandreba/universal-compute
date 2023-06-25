const std = @import("std");
const builtin = @import("builtin");
const root = @import("../main.zig");
const c = root.cl;

pub fn onComplete(self: c.cl_event, f: *const fn (root.uc_result_t, ?*anyopaque) callconv(.C) void, user_data: ?*anyopaque) !void {
    const Impl = struct {
        cb: *const fn (root.uc_result_t, ?*anyopaque) callconv(.C) void,
        user_data: ?*anyopaque,

        const CL_CALLBACK = if (builtin.target.os.tag == .windows) std.os.windows.WINAPI else .C;

        fn callback(_: c.cl_event, event_command_exec_status: c.cl_int, impl_user_data: ?*anyopaque) callconv(CL_CALLBACK) void {
            const impl = @ptrCast(*@This(), @alignCast(@alignOf(@This()), impl_user_data.?));
            defer root.alloc.destroy(impl);
            const status = c.externError(event_command_exec_status);
            (impl.cb)(status, impl.user_data);
        }
    };

    const data = try root.alloc.create(Impl);
    data.* = .{ .cb = f, .user_data = user_data };

    try c.clError(c.clSetEventCallback(
        self,
        c.CL_COMPLETE,
        Impl.callback,
        data,
    ));
}

pub fn clStatusToUc(status: c.cl_int) !root.event.Status {
    try c.clError(status);
    switch (status) {
        c.CL_QUEUED, c.CL_SUBMITTED => .PENDING,
        c.CL_RUNNING => .RUNNING,
        c.CL_COMPLETE => .COMPLETE,
        else => unreachable,
    }
}
