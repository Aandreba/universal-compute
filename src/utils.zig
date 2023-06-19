const std = @import("std");
const builtin = @import("builtin");
const target: std.Target = builtin.target;

pub const alloc = if (builtin.is_test) std.testing.allocator else std.heap.page_allocator;

pub fn enumList(comptime T: type) [@typeInfo(T).Enum.fields.len]T {
    const info: std.builtin.Type.Enum = @typeInfo(T).Enum;

    var result: [info.fields.len]T = undefined;
    inline for (info.fields, 0..) |field, i| {
        result[i] = @intToEnum(T, field.value);
    }

    return result;
}
