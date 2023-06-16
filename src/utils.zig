const std = @import("std");
const builtin = @import("builtin");
const target: std.Target = builtin.target;

pub const alloc = std.heap.page_allocator;
pub const libcpuid = if (target.cpu.arch.isX86()) @cImport(@cInclude("libcpuid.h")) else @compileError("libcpuid is only available on x86/64");
