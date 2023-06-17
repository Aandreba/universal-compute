const std = @import("std");
const root = @import("../main.zig");
const builtin = @import("builtin");
const utils = @import("../utils.zig");

const alloc = utils.alloc;
const cpuid = utils.libcpuid;
const target: std.Target = builtin.target;
const windows = std.os.windows;

pub fn getDevices(devices: []root.Device) !usize {
    if (comptime builtin.link_libc and target.cpu.arch.isX86()) {
        var raw: cpuid.cpu_raw_data_t = undefined;
        try cpuidToError(cpuid.cpuid_get_raw_data(&raw));

        var data: cpuid.cpu_id_t = undefined;
        try cpuidToError(cpuid.cpu_identify(&raw, &data));

        devices[0] = .{
            .vendor = try alloc.dupe(u8, std.mem.sliceTo(&data.vendor_str, 0)),
            .name = try alloc.dupe(u8, std.mem.sliceTo(&data.brand_str, 0)),
            .cores = if (builtin.single_threaded) 1 else std.math.cast(usize, data.total_logical_cpus) orelse std.math.maxInt(usize),
            .backend = .Host,
            .backend_data = null,
        };
    } else if (comptime target.os.tag == .windows) {
        var info: windows.SYSTEM_INFO = undefined;
        windows.kernel32.GetSystemInfo(&info);

        devices[0] = .{
            .vendor = null,
            .name = null,
            .cores = if (builtin.single_threaded) 1 else std.math.cast(usize, info.dwNumberOfProcessors) orelse std.math.maxInt(usize),
            .backend = .Host,
            .backend_data = null,
        };
    } else if (comptime target.isWasm()) {
        // TODO wasm threads
        devices[0] = .{
            .vendor = null,
            .name = null,
            .cores = 1,
            .backend = .Host,
            .backend_data = null,
        };
    } else {
        @compileError("not yet implemented");
    }

    return 1;
}

fn cpuidToError(e: cpuid.cpu_error_t) !void {
    return switch (e) {
        cpuid.ERR_OK => return,
        cpuid.ERR_NO_CPUID => error.NoCpuid,
        cpuid.ERR_NO_RDTSC => error.NoRdtsc,
        cpuid.ERR_NO_MEM => error.OutOfMemory,
        cpuid.ERR_OPEN => error.OpenFailed,
        cpuid.ERR_BADFMT => error.BadFormat,
        cpuid.ERR_NOT_IMP => error.NotImplemented,
        cpuid.ERR_CPU_UNKN => error.UnknownCpu,
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
    var device = try std.testing.allocator.create(root.Device);
    defer std.testing.allocator.destroy(device);

    _ = try getDevices(@ptrCast([*]root.Device, device)[0..1]);
    defer device.ucDeviceDeinit();
}
