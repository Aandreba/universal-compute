const std = @import("std");
const root = @import("../main.zig");
const builtin = @import("builtin");
const utils = @import("../utils.zig");

const alloc = utils.alloc;
const target: std.Target = builtin.target;
const windows = std.os.windows;

pub fn getDevices(devices: []root.device.Device) usize {
    devices[0] = .Host;
    return 1;
}

pub fn getDeviceInfo(info: root.device.DeviceInfo, raw_ptr: ?*anyopaque, raw_len: *usize) !void {
    switch (info) {
        .BACKEND => unreachable,
        .VENDOR => try getVendor(raw_ptr, raw_len),
        .NAME => try getName(raw_ptr, raw_len),
        .CORE_COUNT => {
            if (raw_ptr) |ptr| {
                (try root.castOpaque(usize, ptr, raw_len.*)).* = try getCoreCount();
            } else {
                raw_len.* = @sizeOf(usize);
            }
        },
        .MAX_FREQUENCY => {
            if (raw_ptr) |ptr| {
                (try root.castOpaque(usize, ptr, raw_len.*)).* = getMaxFrequency();
            } else {
                raw_len.* = @sizeOf(usize);
            }
        },
    }
}

pub fn getVendor(raw_ptr: ?*anyopaque, raw_len: *usize) !void {
    if (raw_ptr) |ptr| {
        if (comptime target.cpu.arch.isX86()) {
            if (raw_len.* < 12) return error.InvalidSize;
            const vendor = Cpuid.vendor();
            @memcpy(@ptrCast([*]u8, ptr), &vendor);
        } else {
            @compileError("not yet implemented");
        }
    } else {
        raw_len.* = if (comptime target.cpu.arch.isX86()) 12 else 0;
    }
}

pub fn getName(raw_ptr: ?*anyopaque, raw_len: *usize) !void {
    if (raw_ptr) |ptr| {
        if (comptime target.cpu.arch.isX86()) {
            if (Cpuid.brand()) |*raw_brand| {
                const brand = std.mem.sliceTo(raw_brand, 0);
                if (raw_len.* < brand.len) return error.InvalidSize;
                @memcpy(@ptrCast([*]u8, ptr), brand);
                raw_len.* = brand.len;
            }
            return;
        }
        @compileError("not yet implemented");
    } else {
        raw_len.* = if (comptime target.cpu.arch.isX86()) 48 else 0;
    }
}

pub fn getCoreCount() !usize {
    if (comptime !root.use_atomics) return 1;
    return std.Thread.getCpuCount();
}

// TODO
fn getMaxFrequency() usize {
    return 12000;
}

const Cpuid = struct {
    pub inline fn vendor() [12]u8 {
        var regs: [3]u32 = undefined;
        asm volatile (
            \\mov %[regs], %rdi
            \\mov $0, %eax
            \\cpuid
            \\movl %ebx, (%rdi)
            \\movl %edx, 4(%rdi)
            \\movl %ecx, 8(%rdi)
            :
            : [regs] "r" (@ptrToInt(&regs)),
            : "memory", "eax", "rdi"
        );
        return @bitCast([12]u8, regs);
    }

    pub fn brand() ?[12 * @sizeOf(u32)]u8 {
        var supported: u32 = undefined;
        asm volatile (
            \\mov %[sup], %rdi
            \\movl $0x80000000, %eax
            \\cpuid
            \\movl %eax, (%rdi)
            :
            : [sup] "r" (@ptrToInt(&supported)),
            : "memory", "eax"
        );

        if (supported - 0x80000000 >= 4) {
            var brand_regs: [12]u32 = undefined;
            cpuid(0x80000002, brand_regs[0..]);
            cpuid(0x80000003, brand_regs[4..]);
            cpuid(0x80000004, brand_regs[8..]);
            return @bitCast([12 * @sizeOf(u32)]u8, brand_regs);
        }

        return null;
    }

    // from [libcpuid](https://github.com/anrieff/libcpuid/blob/master/libcpuid/asm-bits.c#L83)
    fn cpuid(eax: u32, regs: [*]u32) void {
        if (comptime target.cpu.arch == .x86) {
            @compileError("not yet implemented");
        } else if (comptime target.cpu.arch == .x86_64) {
            return asm volatile (
                \\mov %[regs], %rdi
                \\mov %[eax], %eax
                \\cpuid
                \\movl %eax, (%rdi)
                \\movl %ebx, 4(%rdi)
                \\movl %ecx, 8(%rdi)
                \\movl %edx, 12(%rdi)
                :
                : [regs] "r" (@ptrToInt(regs)),
                  [eax] "r" (eax),
                : "memory", "eax", "rdi"
            );
        }

        @compileError("cpuid only available on x86/64");
    }
};
