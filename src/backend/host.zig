const std = @import("std");
const root = @import("../main.zig");
const builtin = @import("builtin");
const utils = @import("../utils.zig");

const alloc = utils.alloc;
const cpuid = utils.libcpuid;
const target: std.Target = builtin.target;
const windows = std.os.windows;

pub fn getHostDevices(devices: ?[*]root.device.Device, count: *usize) !void {
    if (devices) |devs| {
        if (count.* == 0) return;

        if (comptime target.cpu.arch.isX86()) {
            var raw: cpuid.cpu_raw_data_t = undefined;
            try cpuidToError(cpuid.cpuid_get_raw_data(&raw));

            var data: cpuid.cpu_id_t = undefined;
            try cpuidToError(cpuid.cpu_identify(&raw, &data));

            devs[0] = .{
                .vendor = alloc.dupeZ(u8, std.mem.sliceTo(&data.vendor_str, 0)),
                .name = alloc.dupeZ(u8, std.mem.sliceTo(&data.brand_str, 0)),
                .cores = std.math.cast(usize, data.total_logical_cpus) orelse std.math.maxInt(usize),
            };
        } else if (comptime target.os.tag == .windows) {
            var info: windows.SYSTEM_INFO = undefined;
            windows.kernel32.GetSystemInfo(&info);

            devs[0] = .{
                .vendor = null,
                .name = null,
                .cores = std.math.cast(usize, info.dwNumberOfProcessors) orelse std.math.maxInt(usize),
            };
        } else if (comptime target.isWasm()) {
            devs[0] = .{
                .vendor = null,
                .name = null,
                .cores = 1, // TODO wasm threads
            };
        } else {
            @compileError("not yet implemented");
        }
    }

    count.* = 1;
}

fn cpuidToError(e: cpuid.cpu_error_t) !void {
    return switch (e) {
        cpuid.ERR_OK => void,
        cpuid.ERR_NO_CPUID => error.NoCpuid,
        cpuid.ERR_NO_RDTSC => error.NoRdtsc,
        cpuid.ERR_NO_MEM => error.OutOfMemory,
        cpuid.ERR_OPEN => error.OpenFailed,
        cpuid.ERR_BADFMT => error.BadFormat,
        cpuid.ERR_NOT_IMPL => error.NotImplemented,
        cpuid.ERR_CPU_UNKK => error.UnknownCpu,
        cpuid.ERR_NO_RDMSR => error.NoRdmsr,
        cpuid.ERR_NO_DRIVER => error.NoDriver,
        cpuid.ERR_NO_PERMS => error.NoPerms,
        cpuid.ERR_EXTRACT => error.Extract,
        cpuid.ERR_HANDLE => error.BadHandle,
        cpuid.ERR_INVMSR => error.InvalidMsr,
        cpuid.ERR_INVCNB => error.InvalidCoreNumber,
        cpuid.ERR_HANDLE_R => error.HandleRead,
        cpuid.ERR_INVRANGE => error.InvalidRange,
        else => error.Unknown,
    };
}

test "get cpu info" {
    var device: root.device.Device = undefined;
    getHostDevices(&device, &1);
    std.debug.print("{}", .{device});
}
