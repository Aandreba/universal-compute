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

pub fn read(self: *Buffer, offset: usize, len: usize, raw_dst: *anyopaque) !Arc(Event) {
    const dst: [*]u8 = @as([*]u8, @ptrCast(raw_dst));
    return copy_impl(self.context, self.slice[offset..].ptr, dst, len);
}

pub fn write(self: *Buffer, offset: usize, len: usize, raw_src: *const anyopaque) !Arc(Event) {
    const src: [*]const u8 = @as([*]const u8, @ptrCast(raw_src));
    return copy_impl(self.context, src, self.slice[offset..].ptr, len);
}

pub fn copy(
    raw_src: *Buffer,
    src_offset: usize,
    raw_dst: *Buffer,
    dst_offset: usize,
    len: usize,
) !Arc(Event) {
    if (!raw_src.context.eql(raw_dst.context)) return error.DiferentContexts;
    const src: [*]const u8 = raw_src.slice[src_offset..].ptr;
    const dst: [*]u8 = raw_dst.slice[dst_offset..].ptr;
    return copy_impl(raw_src.context, src, dst, len);
}

fn copy_impl(context: *Context, raw_src: [*]const u8, raw_dst: [*]u8, len: usize) !Arc(Event) {
    const Impl = struct {
        inline fn write(dst: []u8, src: []const u8) !void {
            std.debug.assert(dst.len == src.len);
            @memcpy(dst, src);
        }
    };

    switch (context.*) {
        .Single => {
            const ctx = &context.Single;
            return ctx.enqueue(Impl.write, .{ raw_dst[0..len], raw_src[0..len] });
        },
        .Multi => |ctx| {
            const min_size_per_worker = std.atomic.cache_line;
            const size_per_worker = len / ctx.threads.len;

            var event = try Arc(Event).init(root.alloc, .{ .workers = undefined });
            errdefer event.releaseWithFn(Event.deinit);

            if (size_per_worker < min_size_per_worker) {
                event.value.workers = 1;
                try ctx.enqueue(Impl.write, .{ raw_dst[0..len], raw_src[0..len] }, &event);
            } else {
                event.value.workers = @as(u32, @intCast(ctx.threads.len));
                for (0..ctx.threads.len - 1) |i| {
                    const chunk_offset = i * size_per_worker;

                    var slice_chunk = raw_dst[chunk_offset..chunk_offset];
                    slice_chunk.len = size_per_worker;

                    var src_chunk = raw_src[chunk_offset..chunk_offset];
                    src_chunk.len = size_per_worker;

                    try ctx.enqueue(Impl.write, .{ slice_chunk, src_chunk }, &event);
                }

                // Last thread accounts for remaining slice
                const last_worker_size = size_per_worker + (len % ctx.threads.len);
                const chunk_offset = (ctx.threads.len - 1) * size_per_worker;

                var slice_chunk = raw_dst[chunk_offset..chunk_offset];
                slice_chunk.len = last_worker_size;

                var src_chunk = raw_src[chunk_offset..chunk_offset];
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
