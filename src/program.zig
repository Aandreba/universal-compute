const std = @import("std");
const builtin = @import("builtin");
const root = @import("main.zig");

pub const Host = @import("program/host.zig");
pub const OpenCl = if (root.features.has_opencl) @import("program/opencl.zig") else struct {};

comptime {
    root.exportLayout(Program, "PROGRAM");
    root.exportLayout(Symbol, "SYMBOL");
}

pub const Program = union(root.Backend) {
    Host: Host.Program,
    OpenCl: if (root.features.has_opencl) OpenCl.Program else noreturn,
};

pub const Symbol = union(root.Backend) {
    Host: Host.Symbol,
    OpenCl: if (root.features.has_opencl) OpenCl.Symbol else noreturn,
};

pub export fn ucOpenProgram(context: *root.context.Context, path: [*]const u8, path_len: usize, program: *Program) root.uc_result_t {
    program.* = switch (context.*) {
        .Host => .{ .Host = Host.open(&context.Host, path[0..path_len]) catch |e| return root.externError(e) },
        .OpenCl => if (!root.features.has_opencl) unreachable else .{ .OpenCl = OpenCl.open(&context.OpenCl, path[0..path_len]) catch |e| return root.externError(e) },
    };
    return root.UC_RESULT_SUCCESS;
}

pub export fn ucProgramSymbol(program: *Program, name: [*]const u8, name_len: usize, symbol: *Symbol) root.uc_result_t {
    symbol.* = switch (program.*) {
        .Host => .{ .Host = Host.symbol(&program.Host, name[0..name_len]) catch |e| return root.externError(e) },
        .OpenCl => if (!root.features.has_opencl) unreachable else .{ .OpenCl = OpenCl.symbol(&program.OpenCl, name[0..name_len]) catch |e| return root.externError(e) },
    };
    return root.UC_RESULT_SUCCESS;
}

pub export fn ucProgramDeinit(self: *Program) root.uc_result_t {
    switch (self.*) {
        .Host => Host.close(&self.Host) catch |e| return root.externError(e),
        .OpenCl => if (!root.features.has_opencl) unreachable else OpenCl.close(&self.OpenCl) catch |e| return root.externError(e),
    }
    return root.UC_RESULT_SUCCESS;
}

// SYMBOL \\
pub export fn ucSymbolDeinit(self: *Symbol) root.uc_result_t {
    switch (self.*) {
        .Host => Host.closeSymbol(&self.Host) catch |e| return root.externError(e),
        .OpenCl => if (!root.features.has_opencl) unreachable else OpenCl.closeSymbol(&self.OpenCl) catch |e| return root.externError(e),
    }
    return root.UC_RESULT_SUCCESS;
}
