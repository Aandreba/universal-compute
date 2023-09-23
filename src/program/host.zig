const std = @import("std");
const builtin = @import("builtin");
const root = @import("../main.zig");
pub const Program = @This();

const target: std.Target = builtin.target;
const is_unix = switch (target.os.tag) {
    .linux, .haiku, .solaris, .fuchsia => true,
    else => target.isDarwin() or target.isAndroid() or target.isBSD(),
};

const Argument = union(enum) {
    Uninit: void,
    Int: struct { ty: std.builtin.Type.Int, bytes: [32]u8 },
    Float: struct { ty: std.builtin.Type.Float, bytes: [32]u8 },
    Buffer: *anyopaque,
};

pub const Symbol = struct {
    handle: *anyopaque,
    args: std.ArrayListUnmanaged(Argument) = .{},
};

const Impl = if (is_unix) UnixImpl else if (target.isWasm()) WasmImpl else if (target.os.tag == .windows) WindowsImpl else UnsupportedImpl;
impl: Impl,

pub fn open(_: *root.context.Host.Context, path: []const u8) !Program {
    return .{ .impl = try Impl.open(path) };
}

pub fn symbol(self: *Program, name: []const u8) !Symbol {
    return .{
        .handle = try self.impl.symbol(name),
    };
}

pub fn close(self: *Program) !void {
    return self.impl.close();
}

pub fn setInteger(self: *Symbol, idx: usize, signed: bool, bits: root.program.IntBits, value: *const anyopaque) !void {
    var entry = Argument{
        .Int = .{
            .ty = .{
                .signedness = if (signed) .signed else .unsigned,
                .bits = @intFromEnum(bits),
            },
            .bytes = undefined,
        },
    };

    const bytes = @divExact(@intFromEnum(bits), 8);
    @memcpy(entry.Int.bytes[0..bytes], @as([*]const u8, @ptrCast(value))[0..bytes]);
    return setEntry(self, idx, entry);
}

pub fn setFloat(self: *Symbol, idx: usize, bits: root.program.FloatBits, value: *const anyopaque) !void {
    var entry = Argument{
        .Float = .{
            .ty = .{
                .bits = @intFromEnum(bits),
            },
            .bytes = undefined,
        },
    };

    const bytes = @divExact(@intFromEnum(bits), 8);
    @memcpy(entry.Float.bytes[0..bytes], @as([*]const u8, @ptrCast(value))[0..bytes]);
    return setEntry(self, idx, entry);
}

pub fn setBuffer(self: *Symbol, idx: usize, buffer: *root.buffer.Host.Buffer) !void {
    return setEntry(self, idx, .{
        .Buffer = @ptrCast(buffer.slice.ptr),
    });
}

fn setEntry(self: *Symbol, idx: usize, entry: Argument) !void {
    try self.args.ensureTotalCapacity(root.alloc, idx + 1);
    if (std.math.sub(usize, idx, self.args.items.len) catch null) |delta| {
        var slice = self.args.unusedCapacitySlice();
        @memset(slice[0..delta], .Uninit);
        slice[delta] = entry;
        self.args.items.len = idx;
    } else {
        self.args.items[idx] = entry;
    }
}

pub fn closeSymbol(self: *Symbol) !void {
    self.args.deinit(root.alloc);
}

const UnsupportedImpl = struct {
    fn open(_: anytype) noreturn {
        unsupported();
    }

    fn symbol(_: *UnsupportedImpl, _: anytype) noreturn {
        unsupported();
    }

    fn close(_: *UnsupportedImpl) noreturn {
        unsupported();
    }

    fn unsupported() noreturn {
        @compileError("unsupported");
    }
};

const WindowsImpl = struct {
    module: w.HMODULE,
    const w = std.os.windows.kernel32;

    fn open(path: []const u8) !WindowsImpl {
        const utf16_path = try std.unicode.utf8ToUtf16LeWithNull(root.alloc, path);
        defer root.alloc.free(utf16_path);

        if (w.LoadLibraryW(utf16_path.ptr)) |module| {
            return .{ .module = module };
        } else {
            return error.DlError;
        }
    }

    fn symbol(self: *WindowsImpl, name: [*:0]const u8) !*anyopaque {
        const utf8_name = try root.alloc.dupeZ(u8, name);
        defer root.alloc.free(utf8_name);

        if (w.GetProcAddress(self.module, utf8_name.ptr)) |res| {
            return @as(*anyopaque, @ptrCast(res));
        } else {
            return error.DlError;
        }
    }

    fn close(self: *WindowsImpl) !void {
        if (w.FreeLibrary(self.module) != std.os.windows.FALSE) {
            return error.DlError;
        }
    }
};

const UnixImpl = struct {
    handle: *anyopaque,
    const c = @cImport(@cInclude("dlfcn.h"));

    // Taken from [here](https://docs.rs/libloading/latest/src/libloading/os/unix/mod.rs.html#243)
    const is_thread_safe = switch (target.os.tag) {
        .linux, .openbsd, .macos, .ios, .solaris, .fuchsia => true,
        else => target.isAndroid(),
    };

    fn open(path: []const u8) !UnixImpl {
        const utf8_path = try root.alloc.dupeZ(u8, path);
        defer root.alloc.free(utf8_path);

        if (c.dlopen(utf8_path.ptr, c.RTLD_LAZY | c.RTLD_LOCAL)) |handle| {
            return .{ .handle = handle };
        } else return dlError();
    }

    fn symbol(self: *UnixImpl, name: []const u8) !*anyopaque {
        const utf8_name = try root.alloc.dupeZ(u8, name);
        defer root.alloc.free(utf8_name);
        return (c.dlsym(self.handle, utf8_name.ptr)) orelse dlError();
    }

    fn close(self: *UnixImpl) !void {
        return switch (c.dlclose(self.handle)) {
            0 => {},
            else => dlError(),
        };
    }

    fn dlError() error{DlError} {
        if (comptime is_thread_safe) {
            const err = std.mem.span(c.dlerror());
            std.log.err("Dynamic library error: {s}", .{err});
        }
        return error.DlError;
    }
};

// TODO
const WasmImpl = struct {};
