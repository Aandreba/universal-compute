const std = @import("std");
const builtin = @import("builtin");
const target: std.Target = builtin.target;

// from [libcpuid](https://github.com/anrieff/libcpuid/blob/master/libcpuid/asm-bits.c#L83)
fn cpuid(eax: u32) [4]u32 {
    var regs: [4]u32 = undefined;
    if (comptime target.cpu.arch == .x86) {
        @compileError("not yet implemented");
    } else if (comptime target.cpu.arch == .x86_64) {
        asm volatile (
            \\mov %[regs], %rdi
            \\mov %[eax], %eax
            \\cpuid
            \\movl %eax, (%rdi)
            \\movl %ebx, 4(%rdi)
            \\movl %ecx, 8(%rdi)
            \\movl %edx, 12(%rdi)
            :
            : [regs] "r" (@ptrToInt(&regs)),
              [eax] "r" (eax),
            : "memory", "eax", "rdi"
        );
        return regs;
    }

    @compileError("cpuid only available on x86/64");
}

pub fn main() void {
    std.debug.print("{any}", .{cpuid(0x80000008)});
}
