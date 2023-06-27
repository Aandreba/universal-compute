const std = @import("std");
const builtin = @import("builtin");
const root = @import("../main.zig");
const Program = @This();

const target: std.Target = builtin.target;
const is_unix = switch (target.os.tag) {
    .linux, .haiku, .solaris, .illumos, .redox, .fuchsia => true,
    else => target.isDarwin() or target.isAndroid() or target.isBSD(),
};

const Impl = if (is_unix) UnixImpl else if (target.isWasm()) WasmImpl else if (target.os.tag == .windows) WindowsImpl else UnsupportedImpl;
impl: Impl,

pub fn open(path: []const u8) Program {
    _ = path;
}

pub const UnsupportedImpl = struct {
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

pub const WindowsImpl = struct {
    module: w.HMODULE,
    const w = std.os.windows.kernel32;

    fn open(path: [*:0]const u16) !WindowsImpl {
        return .{ .module = try w.LoadLibraryW(path) };
    }

    fn symbol(self: *WindowsImpl, name: [*:0]const u8) !*anyopaque {
        const res = try w.GetProcAddress(self.module, name);
        return @ptrCast(*anyopaque, res);
    }

    fn close(self: *WindowsImpl) !void {
        if (w.FreeLibrary(self.module) != std.os.windows.FALSE) {
            return error.DlError;
        }
    }
};

pub const UnixImpl = struct {
    handle: *anyopaque,
    const c = @cImport(@cInclude("dlfcn.h"));

    // Taken from [here](https://docs.rs/libloading/latest/src/libloading/os/unix/mod.rs.html#243)
    const is_thread_safe = switch (target.os.tag) {
        .linux, .openbsd, .macos, .ios, .solaris, .illumos, .redox, .fuchsia => true,
        else => target.isAndroid(),
    };

    fn open(path: [*:0]const u8) !UnixImpl {
        if (c.dlopen(path, c.RTLD_LAZY | c.RTLD_LOCAL)) |handle| {
            return .{ .handle = handle };
        } else return dlError();
    }

    fn symbol(self: *UnixImpl, name: [*:0]const u8) !*anyopaque {
        return (c.dlsym(self.handle, name)) orelse dlError();
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
            std.log.err("Dynamic library error: {}", .{err});
        }
        return error.DlError;
    }
};

// TODO
pub const WasmImpl = struct {};
