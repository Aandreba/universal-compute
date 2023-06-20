const std = @import("std");
const builtin = @import("builtin");
const target: std.Target = builtin.target;

pub const compute_archs = [_]std.Target.Cpu.Arch{ .nvptx, .nvptx64, .spir, .spir64, .spirv32, .spirv64 };
pub const is_compute_target = std.mem.count(std.Target.Cpu.Arch, &compute_archs, &[1]std.Target.Cpu.Arch{target.cpu.arch}) > 0;
pub const UCAPI = if (is_compute_target) .Kernel else .C;
