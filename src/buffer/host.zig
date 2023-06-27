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

pub inline fn create(ctx: *Context, size: usize) !Buffer {
    const slice = try root.alloc.alignedAlloc(u8, comptime std.Target.maxIntAlignment(builtin.target), size);
    return .{
        .slice = slice,
        .context = ctx,
    };
}

pub export fn write(self: *Buffer, offset: usize, len: usize, raw_src: *const anyopaque) !*Event {
    const Impl = struct {
        inline fn write(slice: Slice, src: []const u8) !void {
            @memcpy(slice, src);
        }
    };

    const src: []const u8 = @ptrCast([*]const u8, raw_src)[0..len];
    switch (self.context.*) {
        .Single => {
            const ctx = &self.context.Single;
            const evt = ctx.enqueue(Impl.write, .{ self.slice[offset .. offset + len], src });
            return evt.value;
        },
        .Multi => |ctx| {
            const min_size_per_worker = std.atomic.cache_line;
            const size_per_worker = len / ctx.threads.len;
            var event = Arc(Event).init(root.alloc, .{ .workers = undefined });

            if (size_per_worker < min_size_per_worker) {
                event.value.workers = 1;
                const evt = ctx.enqueue(Impl.write, .{ self.slice[offset .. offset + len], src }, &event);
                return evt.value;
            } else {
                event.value.workers = ctx.threads.len;
                for (0..ctx.threads.len - 1) |i| {
                    const chunk_offset = i * size_per_worker;

                    var slice_chunk = self.slice[offset + chunk_offset ..];
                    slice_chunk.len = size_per_worker;

                    var src_chunk = src[chunk_offset..];
                    src_chunk.len = size_per_worker;

                    ctx.enqueue(Impl.slice, .{ slice_chunk, src_chunk }, &event);
                }

                // Last thread accounts for remaining slice
                const remainder_size = size_per_worker + (len % ctx.threads.len);
                const chunk_offset = (ctx.threads.len - 1) * size_per_worker;

                var slice_chunk = self.slice[offset + chunk_offset ..];
                slice_chunk.len = size_per_worker + remainder;

                var src_chunk = src[chunk_offset..];
                src_chunk.len = size_per_worker;

                ctx.enqueue(Impl.slice, .{ slice_chunk, src_chunk }, &event);
            }
            // TODO
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
