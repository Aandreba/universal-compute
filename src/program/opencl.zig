const std = @import("std");
const builtin = @import("builtin");
const root = @import("../main.zig");
const c = root.cl;

pub const Program = c.cl_program;
pub const Symbol = c.cl_kernel;

pub fn open(ctx: *root.context.OpenCl.Context, path: []const u8) !Program {
    const SPIRV_MAGIC_NUMBER_NATIVE: u32 = 0x07230203;
    const SPIRV_MAGIC_NUMBER_INVERSE: u32 = 0x3022307;

    const content: []align(@alignOf(u32)) u8 = try std.fs.cwd().readFileAllocOptions(
        root.alloc,
        path,
        std.math.maxInt(usize),
        null,
        @alignOf(u32),
        null,
    );
    defer root.alloc.free(content);

    const magic_number = std.mem.bytesToValue(u32, content[0..4]);

    // Open
    var program: c.cl_program = undefined;
    if (magic_number == SPIRV_MAGIC_NUMBER_NATIVE or magic_number == SPIRV_MAGIC_NUMBER_INVERSE) {
        program = try open_spirv(ctx, content, magic_number == SPIRV_MAGIC_NUMBER_NATIVE);
    } else {
        program = try open_source(ctx, content);
    }

    // Build
    try c.clError(c.clBuildProgram(program, 0, null, null, null, null));
    // TODO log build errors

    return program;
}

pub fn symbol(self: *Program, name: []const u8) !Symbol {
    const utf8_name = try root.alloc.dupeZ(u8, name);
    defer root.alloc.free(utf8_name);

    var err: c.cl_int = undefined;
    const kernel = c.clCreateKernel(self.*, @ptrCast(utf8_name.ptr), &err);
    try c.clError(err);
    return kernel;
}

pub fn close(self: *Program) !void {
    return c.clError(c.clReleaseProgram(self.*));
}

pub fn setInteger(self: *Symbol, idx: usize, _: bool, bits: root.program.IntBits, value: *const anyopaque) !void {
    return c.clError(c.clSetKernelArg(
        self.*,
        @intCast(idx),
        @divExact(@intFromEnum(bits), 8),
        value,
    ));
}

pub fn setFloat(self: *Symbol, idx: usize, bits: root.program.FloatBits, value: *const anyopaque) !void {
    return c.clError(c.clSetKernelArg(
        self.*,
        @intCast(idx),
        @divExact(@intFromEnum(bits), 8),
        value,
    ));
}

pub fn closeSymbol(self: *Symbol) !void {
    return c.clError(c.clReleaseKernel(self.*));
}

// OPENERS \\
fn open_source(ctx: *root.context.OpenCl.Context, src: []const u8) !c.cl_program {
    var strings: [*c]const u8 = @ptrCast(src.ptr);
    var lengths = src.len;

    var err: c.cl_int = undefined;
    const program = c.clCreateProgramWithSource(ctx.context, 1, &strings, &lengths, &err);
    try c.clError(err);

    return program;
}

fn open_spirv(ctx: *root.context.OpenCl.Context, binary: []align(@alignOf(u32)) u8, native: bool) !c.cl_program {
    if (!@hasDecl(c, "CL_VERSION_2_1")) return error.InvalidData;
    if (comptime c.CL_VERSION_2_1 == c.CL_FALSE) return error.InvalidData;
    if (binary.len % @sizeOf(u32) != 0) return error.InvalidData;

    var words: []u32 = @as([*]u32, @ptrCast(binary.ptr))[0..@divExact(binary.len, @sizeOf(u32))];
    if (!native) {
        for (0..words.len) |i| {
            words[i] = @byteSwap(words[i]);
        }
    }

    var err: c.cl_int = undefined;
    const program = c.clCreateProgramWithIL(ctx.context, words.ptr, words.len, &err);
    try c.clError(err);

    return program;
}
