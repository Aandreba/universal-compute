const std = @import("std");
const root = @import("../main.zig");
const builtin = @import("builtin");
const utils = @import("../utils.zig");

const alloc = utils.alloc;
//const cpuid = utils.libcpuid;
const target: std.Target = builtin.target;
const windows = std.os.windows;

const Cpuid = struct {
    vendor: [12]u8,

    pub fn init () Cpuid {
        var regs = std.mem.zeroes([4]u32);
        cpuid(&regs);
        const vendor = [3]u32{ regs[1], regs[3], regs[2] };

        regs = [4]u32{4, 0, 0, 0};
        cpuid(&regs);
        std.debug.print("{any}", .{regs});

        // Brand string (https://en.wikipedia.org/wiki/CPUID#EAX=80000002h,80000003h,80000004h:_Processor_Brand_String)

        return .{ .vendor = @bitCast([12]u8, vendor), };
    }

    // from [libcpuid](https://libcpuid.sourceforge.net/index.html)
    inline fn cpuid(regs: *[4]u32) void {
        if (comptime target.cpu.arch == .x86) {
            return asm volatile (
                \\mov	%[regs],	%edi
                \\push	%ebx
                \\push	%ecx
                \\push	%edx
                \\mov	(%edi),	%eax
                \\mov	4(%edi),	%ebx
                \\mov	8(%edi),	%ecx
                \\mov	12(%edi),	%edx
                \\cpuid
                \\movl	%eax,	(%edi)
                \\movl	%ebx,	4(%edi)
                \\movl	%ecx,	8(%edi)
                \\movl	%edx,	12(%edi)
                \\pop	%edx
                \\pop	%ecx
                \\pop	%ebx
                :
                : [regs] "r" (@ptrToInt(regs))
                : "memory", "eax", "edi"
            );
        } else if (comptime target.cpu.arch == .x86_64) {
            return asm volatile (
                \\mov	%[regs],	%rdi
                \\push	%rbx
                \\push	%rcx
                \\push	%rdx
                \\mov	(%rdi),	%eax
                \\mov	4(%rdi),	%ebx
                \\mov	8(%rdi),	%ecx
                \\mov	12(%rdi),	%edx
                \\cpuid
                \\movl	%eax,	(%rdi)
                \\movl	%ebx,	4(%rdi)
                \\movl	%ecx,	8(%rdi)
                \\movl	%edx,	12(%rdi)
                \\pop	%rdx
                \\pop	%rcx
                \\pop	%rbx
                :
                : [regs] "r" (@ptrToInt(regs))
                : "memory", "eax", "rdi"
            );
        }

        @compileError("cpuid only available on x86/64");
    }
};

pub fn getDevices(devices: []root.Device) !usize {
    if (target.cpu.arch.isX86()) {
        const cpuid = Cpuid.init();
        std.debug.print("{s}", .{&cpuid.vendor});
        // var raw: cpuid.cpu_raw_data_t = undefined;
        // try cpuidToError(cpuid.cpuid_get_raw_data(&raw));
        //
        // var data: cpuid.cpu_id_t = undefined;
        // try cpuidToError(cpuid.cpu_identify(&raw, &data));
        //
        // devices[0] = .{
        //     .vendor = try alloc.dupe(u8, std.mem.sliceTo(&data.vendor_str, 0)),
        //     .name = try alloc.dupe(u8, std.mem.sliceTo(&data.brand_str, 0)),
        //     .cores = if (builtin.single_threaded) 1 else std.math.cast(usize, data.total_logical_cpus) orelse std.math.maxInt(usize),
        //     .backend = .Host,
        //     .backend_data = null,
        // };
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

test "get cpu info" {
    var device = try std.testing.allocator.create(root.Device);
    defer std.testing.allocator.destroy(device);

    _ = try getDevices(@ptrCast([*]root.Device, device)[0..1]);
    //defer device.ucDeviceDeinit();
}
