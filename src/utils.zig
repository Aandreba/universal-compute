const std = @import("std");
const builtin = @import("builtin");
const target: std.Target = builtin.target;

// TODO wasm threads
pub const use_atomics: bool = !builtin.single_threaded;

pub var alloc_instance = if (builtin.is_test) std.testing.allocator_instance else std.heap.GeneralPurposeAllocator(.{}){};
pub const alloc: std.mem.Allocator = alloc_instance.allocator();

pub export fn ucDetectMemoryLeaks() bool {
    return if (builtin.is_test) unreachable else alloc_instance.detectLeaks();
}

pub inline fn yield() std.Thread.YieldError!void {
    if (comptime target.os.tag == .windows or @hasDecl(std.os.system, "sched_yield")) {
        return std.Thread.yield();
    } else {
        return error.SystemCannotYield;
    }
}

pub fn enumList(comptime T: type) [@typeInfo(T).Enum.fields.len]T {
    const info: std.builtin.Type.Enum = @typeInfo(T).Enum;

    var result: [info.fields.len]T = undefined;
    inline for (info.fields, 0..) |field, i| {
        result[i] = @intToEnum(T, field.value);
    }

    return result;
}
