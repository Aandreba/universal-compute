const std = @import("std");
const builtin = @import("builtin");
const root = @import("../main.zig");

const Context = root.context.Host.Context;
const Event = root.event.Host.Event;

pub const Buffer = struct {
    slice: []align(std.Target.maxIntAlignment(builtin.target)) u8,
    context: *Context,
};

pub inline fn create(ctx: *Context, size: usize) !Buffer {
    const slice = try root.alloc.alignedAlloc(u8, comptime std.Target.maxIntAlignment(builtin.target), size);
    return .{
        .slice = slice,
        .context = ctx,
    };
}

// pub fn read(self: *const Buffer, offset: usize, len: usize, dst: [*]anyopaque) *Event {
//     switch (self.context) {
//         .Single => {},
//         .Multi => {}
//     }
// }

pub inline fn deinit(buf: Buffer) void {
    root.alloc.free(buf.slice);
}
