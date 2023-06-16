const std = @import("std");
const builtin = @import("builtin");
const target: std.Target = builtin.target;

pub const alloc = if (builtin.is_test) std.testing.allocator else std.heap.page_allocator;
pub const libcpuid = if (builtin.link_libc and target.cpu.arch.isX86()) @cImport(@cInclude("libcpuid.h")) else @compileError("libcpuid is only available on x86/64");

pub fn enumList(comptime T: type) [@typeInfo(T).Enum.fields.len]T {
    const info: std.builtin.Type.Enum = @typeInfo(T).Enum;

    var result: [info.fields.len]T = undefined;
    for (info.fields, 0..) |field, i| {
        result[i] = @intToEnum(T, field.value);
    }

    return result;
}
