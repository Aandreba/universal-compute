const std = @import("std");
const builtin = @import("builtin");
const root = @import("../main.zig");
pub const Program = @This();

const target: std.Target = builtin.target;
const is_unix = switch (target.os.tag) {
    .linux, .haiku, .solaris, .fuchsia => true,
    else => target.isDarwin() or target.isAndroid() or target.isBSD(),
};

const Impl = if (is_unix) UnixImpl else if (target.isWasm()) WasmImpl else if (target.os.tag == .windows) WindowsImpl else UnsupportedImpl;
pub const Symbol = *anyopaque;

impl: Impl,

pub fn open(_: *root.context.Host.Context, path: []const u8) !Program {
    return .{ .impl = try Impl.open(path) };
}

pub fn symbol(self: *Program, name: []const u8) !Symbol {
    return self.impl.symbol(name);
}

pub fn close(self: *Program) !void {
    return self.impl.close();
}

pub fn closeSymbol(_: *Symbol) !void {}

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
