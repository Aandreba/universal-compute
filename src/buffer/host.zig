const std = @import("std");
const builtin = @import("builtin");
const root = @import("../main.zig");

const Arc = @import("zigrc").Arc;
const Context = root.context.Host.Context;
const Event = root.event.Host.Event;

const Slice = []align(std.Target.maxIntAlignment(builtin.target)) u8;

pub const Buffer = struct {
    slice: Slice,
    context: *Context,
};

pub fn create(ctx: *Context, size: usize) !Buffer {
    const slice = try root.alloc.alignedAlloc(u8, comptime std.Target.maxIntAlignment(builtin.target), size);
    return .{
        .slice = slice,
        .context = ctx,
    };
}

pub fn write(self: *Buffer, offset: usize, len: usize, raw_src: *const anyopaque) !Arc(Event) {
    const Impl = struct {
        inline fn write(slice: []u8, src: []const u8) !void {
            std.debug.assert(slice.len == src.len);
            @memcpy(slice, src);
        }
    };

    const src: []const u8 = @ptrCast([*]const u8, raw_src)[0..len];
    switch (self.context.*) {
        .Single => {
            const ctx = &self.context.Single;
            return ctx.enqueue(Impl.write, .{ self.slice[offset .. offset + len], src });
        },
        .Multi => |ctx| {
            const min_size_per_worker = std.atomic.cache_line;
            const size_per_worker = len / ctx.threads.len;

            var event = try Arc(Event).init(root.alloc, .{ .workers = undefined });
            errdefer event.releaseWithFn(Event.deinit);

            if (size_per_worker < min_size_per_worker) {
                event.value.workers = 1;
                try ctx.enqueue(Impl.write, .{ self.slice[offset .. offset + len], src }, &event);
            } else {
                event.value.workers = @intCast(u32, ctx.threads.len);
                for (0..ctx.threads.len - 1) |i| {
                    const chunk_offset = i * size_per_worker;

                    var slice_chunk = self.slice[offset + chunk_offset ..];
                    slice_chunk.len = size_per_worker;

                    var src_chunk = src[chunk_offset..];
                    src_chunk.len = size_per_worker;

                    try ctx.enqueue(Impl.write, .{ slice_chunk, src_chunk }, &event);
                }

                // Last thread accounts for remaining slice
                const last_worker_size = size_per_worker + (len % ctx.threads.len);
                const chunk_offset = (ctx.threads.len - 1) * size_per_worker;

                var slice_chunk = self.slice[offset + chunk_offset ..];
                slice_chunk.len = last_worker_size;

                var src_chunk = src[chunk_offset..];
                src_chunk.len = last_worker_size;

                try ctx.enqueue(Impl.write, .{ slice_chunk, src_chunk }, &event);
            }

            return event;
        },
    }
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
