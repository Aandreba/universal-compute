const std = @import("std");
const root = @import("../main.zig");
const builtin = @import("builtin");
const utils = @import("../utils.zig");

const alloc = utils.alloc;
const target: std.Target = builtin.target;
const windows = std.os.windows;

pub fn getDevices(devices: []root.Device) usize {
    devices[0] = .{ .Host };
    return 1;
}

pub fn getDeviceInfo(info: root.Device.Info, raw_ptr: ?*anyopaque, raw_len: *usize) void {
    _ = raw_len;

    if (raw_ptr) |ptr| {
        _ = ptr;

    } else {
        switch (info) {

        }
    }
}

fn getVendor(raw_ptr: ?*anyopaque, raw_len: *usize) void {
    if (raw_ptr) |ptr| {
        _ = ptr;

    } else {
        raw_len.* = 12;
    }
}

fn getCoreCount() usize {
    if (comptime builtin.single_threaded) {
        return 1;
    } else if (comptime target.os.tag == .windows) {
        // TESTED
        var info: windows.SYSTEM_INFO = undefined;
        windows.kernel32.GetSystemInfo(&info);
        return @intCast(usize, info.dwNumberOfProcessors);
    } else if (comptime target.os.tag == .linux) {
        // TESTED
        const c = @cImport({
            @cInclude("sys/sysinfo.h");
            @cInclude("unistd.h");
        });

        return @intCast(usize, c.sysconf(c._SC_NPROCESSORS_ONLN));
    } else if (comptime target.os.tag == .haiku) {
        var info: std.c.system_info = undefined;
        return if (std.c.get_system_info(&info) != 0) 1 else info.cpu_count;
    } else if (comptime target.os.tag.isBSD()) {
        const c = @cImport(@cInclude("sys/sysctl.h"));

        const mib = [2]c_int{ c.CTL_HW, c.HW_NCPU };
        var ncpus: c_int = undefined;
        var len: usize = @sizeOf(c_int);

        const res = std.c.sysctl(&mib, 2, &ncpus, &len, null, 0,);
        return if (res != 0) 1 else @intCast(usize, ncpus);
    }

    @compileError("not yet implemented");
}

const Cpuid = struct {
    pub inline fn vendor() [12]u8 {
        var regs: [3]u32 = undefined;
        asm volatile (
            \\mov %[regs], %rdi
            \\mov $0, %eax
            \\cpuid
            \\movl %ebx (%rdi)
            \\movl %edx 4(%rdi)
            \\movl %ecx 8(%rdi)
            :: [regs] "r" (@ptrToInt(&regs))
            : "memory", "eax", "rdi"
        );
        return @bitCast([12]u8, regs);
    }

    pub fn brand() ?[12*@sizeOf(u32)]u8 {
        var supported: u32 = undefined;
        asm volatile (
            \\mov $0x80000000 %eax
            \\cpuid
            \\movl %eax (%[sup])
            :: [sup] "r" (@ptrToInt(&supported))
            : "memory", "eax"
        );

        if (supported - 0x80000000 >= 4) {
            var brand_regs: [12]u32 = undefined;
            cpuid(0x80000002, brand_regs[0..4]);
            cpuid(0x80000003, brand_regs[4..8]);
            cpuid(0x80000004, brand_regs[8..12]);
            return @bitCast([12*@sizeOf(u32)]u8, brand_regs);
        }

        return null;
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
