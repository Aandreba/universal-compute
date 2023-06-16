const std = @import("std");
const builtin = @import("builtin");
const libs = @import("libs.zig");

const target: std.Target = builtin.target;
const windows = std.os.windows;

usingnamespace @import("../main.zig");

pub export fn ucHostGetDevices(devices: ?[*]Device, count: *usize) callconv(.C) void {
    if (devices) |devices| {
        if (count.* == 0) return;

        if (comptime target.cpu.arch.isX86()) {
            const vendor = libs.libcpuid.cpuid_get_vndor();
            // TODO
        } else if (comptime target.os.tag == .windows) {
            var info: windows.SYSTEM_INFO = undefined;
            windows.kernel32.GetSystemInfo(&info);

            devices[0] = .{
                .name = null,
                .cores = std.math.cast(usize, info.dwNumberOfProcessors) orelse std.math.maxInt(usize),
            };
        } else if (comptime builtin.link_libc) {
            // TODO
        } else if (comptime target.isWasm()) {
            devices[0] = .{
                .name = null,
                .cores = 1, // TODO wasm threads
            };
        } else {
            @compileError("not yet implemented");
        }
    }

    count.* = 1;
}
