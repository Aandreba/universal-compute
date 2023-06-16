const std = @import("std");
const builtin = @import("builtin");

const target: std.Target = builtin.target;
const windows = std.os.windows;

usingnamespace @import("../main.zig");

pub export fn ucHostGetDevices(devices: ?[*]Device, count: *usize) callconv(.C) void {
    if (devices) |devices| {
        if (count.* == 0) return;

        if (comptime target.os.tag == .windows) {
            var info: windows.SYSTEM_INFO = undefined;
            windows.kernel32.GetSystemInfo(&info);
            
            devices[0] = .{
                .name = null,
                .cores = info.dwNumberOfProcessors,
            };
        } else {
            @compileError("not yet implemented");
        }
    }
    
    return 1;
} 
