const std = @import("std");
const builtin = @import("builtin");
const root = @import("../main.zig");

pub const Buffer = []align(std.Target.maxIntAlignment(builtin.target)) u8;

pub inline fn create(size: usize) !Buffer {
    return root.alloc.alignedAlloc(u8, comptime std.Target.maxIntAlignment(builtin.target), size);
}

pub inline fn deinit(buf: Buffer) void {
    root.alloc.free(buf);
}
