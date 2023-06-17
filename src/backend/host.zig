const std = @import("std");
const root = @import("../main.zig");
const builtin = @import("builtin");
const utils = @import("../utils.zig");

const alloc = utils.alloc;
const target: std.Target = builtin.target;
const windows = std.os.windows;

pub fn getDevices(devices: []root.Device) !usize {
    var vendor: ?[]const u8 = null;
    var brand: ?[]const u8 = null;

    // Find vendor/brand names
    if (target.cpu.arch.isX86()) {
        const cpuid = Cpuid.init();
        vendor = try alloc.dupe(u8, &cpuid.vendor);
        if (cpuid.brand) |*br| brand = try alloc.dupe(u8, br);
    }

    // Core count (based on [this](https://github.com/anrieff/libcpuid/blob/master/libcpuid/cpuid_main.c))
    // TODO apple
    var core: usize = brk: {
        if (comptime builtin.single_threaded) {
            break :brk 1;
        } else if (comptime target.os.tag == .windows) {
            // TESTED
            var info: windows.SYSTEM_INFO = undefined;
            windows.kernel32.GetSystemInfo(&info);
            break :brk @intCast(usize, info.dwNumberOfProcessors);
        } else if (comptime target.os.tag == .linux) {
            // TESTED
            const c = @cImport({
                @cInclude("sys/sysinfo.h");
                @cInclude("unistd.h");
            });

            break :brk @intCast(usize, c.sysconf(c._SC_NPROCESSORS_ONLN));
        } else if (comptime target.os.tag == .haiku) {
            var info: std.c.system_info = undefined;
            break :brk if (std.c.get_system_info(&info) != 0) 1 else info.cpu_count;
        } else if (comptime target.os.tag.isBSD()) {
            const c = @cImport(@cInclude("sys/sysctl.h"));

            const mib = [2]c_int{ c.CTL_HW, c.HW_NCPU };
            var ncpus: c_int = undefined;
            var len: usize = @sizeOf(c_int);
            
            const res = std.c.sysctl(&mib, 2, &ncpus, &len, null, 0,);
            break :brk if (res != 0) 1 else @intCast(usize, ncpus);
        } else @compileError("not yet implemented");
    };

    devices[0] = .{
        .vendor = vendor,
        .name = brand,
        .cores = core,
        .backend = .Host,
        .backend_data = null,
    };

    return 1;
}

const Cpuid = struct {
    vendor: [12]u8,
    brand: ?[12*@sizeOf(u32)]u8,

    pub fn init () Cpuid {
        // Vendor string
        var regs: [4]u32 = undefined;
        cpuid(0, &regs);
        const vendor = [3]u32{ regs[1], regs[3], regs[2] };

        // Brand string (https://en.wikipedia.org/wiki/CPUID#EAX=80000002h,80000003h,80000004h:_Processor_Brand_String)
        var brand: ?[12*@sizeOf(u32)]u8 = null;
        cpuid(0x80000000, &regs);

        if (regs[0] - 0x80000000 >= 4) {
            var brand_regs: [12]u32 = undefined;
            cpuid(0x80000002, brand_regs[0..4]);
            cpuid(0x80000003, brand_regs[4..8]);
            cpuid(0x80000004, brand_regs[8..12]);
            brand = @bitCast([12*@sizeOf(u32)]u8, brand_regs);
        }

        return .{ .vendor = @bitCast([12]u8, vendor), .brand = brand, };
    }

    // from [libcpuid](https://github.com/anrieff/libcpuid/blob/master/libcpuid/asm-bits.c#L83)
    inline fn cpuid(eax: u32, regs: *[4]u32) void {
        if (comptime target.cpu.arch == .x86) {
            @compileError("not yet implemented");
        } else if (comptime target.cpu.arch == .x86_64) {
            return asm volatile (
                \\mov %[regs], %rdi
                \\mov [eax], %eax
                \\cpuid
                \\movl %eax, (%rdi)
                \\movl %ebx, 4(%rdi)
                \\movl %ecx, 8(%rdi)
                \\movl %edx, 12(%rdi)
                :
                : [regs] "r" (@ptrToInt(regs)), [eax] "r" (eax)
                : "memory", "eax", "rdi"
            );
        }

        @compileError("cpuid only available on x86/64");
    }
};


test "get cpu info" {
    var device = try std.testing.allocator.create(root.Device);
    defer std.testing.allocator.destroy(device);

    _ = try getDevices(@ptrCast([*]root.Device, device)[0..1]);
    defer device.ucDeviceDeinit();
}
