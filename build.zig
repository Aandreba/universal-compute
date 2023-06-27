const std = @import("std");
const bridge = @import("bridge.zig");
const ff = @import("lib/zig-ff/main.zig");
const builtin = @import("builtin");
const build_target: std.Target = builtin.target;

const CrossTarget = std.zig.CrossTarget;
const Optimize = std.builtin.Mode;
const ModuleEntry = struct { []const u8, *std.Build.Module };

pub const Linkage = enum {
    static,
    shared,
    dynamic,
};

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    var ff_build = ff.builder(b);

    // Library options
    const lib_options = .{
        .name = "universal-compute",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    };

    // Fetch submodules
    const submodule = b.addSystemCommand(&[_][]const u8{ "git", "submodule", "update", "--init", "--remote" });
    const zigrc = b.createModule(.{ .source_file = .{ .path = "lib/zigrc/src/main.zig" } });

    // Flags and options
    const docs = b.option(bool, "docs", "Generate docs (defaults to false)") orelse false;
    const linkage = b.option(Linkage, "linkage", "Defines the linkage type for the library (defaults to static)") orelse .static;
    const libc = b.option(bool, "libc", "Links libc to the output library (defaults to true)") orelse true;
    const opencl = b.option([]const u8, "opencl", "Add OpenCL backend with the specified OpenCL version (defaults to null)") orelse null;

    // Library
    const comptime_info = try Utils.parseComptimeInfo(b);
    const lib = addLibrary(b, lib_options, docs, linkage, libc);
    lib.step.dependOn(&comptime_info.step);
    b.installArtifact(lib);

    // Generate comptime info
    const geninfo = addComptimeInfo(b, target, optimize, linkage, libc);
    const geninfo_step = b.step("comptime_info", "Generate comptime info");
    geninfo_step.dependOn(&geninfo.step);

    // Tests
    const tests = addTests(b, target, optimize, libc);
    const example = try addExample(b, lib, target, optimize, libc);

    // Import libraries
    const compiles = &[_]*std.build.Step.Compile{ lib, tests, example, geninfo };
    addModules(compiles, submodule, &[_]ModuleEntry{
        .{ "zigrc", zigrc },
    });
    if (opencl) |cl| try buildOpenCl(b, &ff_build, cl, compiles, submodule) else try ff_build.addFeatureFlag("opencl", @as(?[]const u8, null), false);

    // Install feature flags
    const features = try ff_build.build();
    for (compiles) |compile| {
        features.installOn(compile, null);
    }
}

fn addModules(compiles: []const *std.build.Step.Compile, submodule: ?*std.build.Step.Run, modules: []const ModuleEntry) void {
    for (compiles) |compile| {
        for (modules) |module| {
            compile.addModule(module[0], module[1]);
        }
        if (submodule) |sm| compile.step.dependOn(&sm.step);
    }
}

// look into [this](https://github.com/gustavolsson/zig-opencl-test/blob/master/build.zig)
fn buildOpenCl(b: *std.Build, ff_build: *ff.Builder, raw_version: []const u8, compiles: []const *std.build.Step.Compile, submodule: *std.build.Step.Run) !void {
    const semver = try std.SemanticVersion.parse(raw_version);
    var version = std.ArrayList(u8).init(b.allocator);
    defer version.deinit();
    try std.fmt.format(version.writer(), "{}{}{}", .{ semver.major, semver.minor, semver.patch });
    try ff_build.addFeatureFlag("opencl", @as(
        ?[]const u8,
        version.items,
    ), false);

    for (compiles) |compile| {
        if (build_target.os.tag == .windows) {
            compile.addIncludePath("./lib/OpenCL-Headers");
            if (try Utils.getCudaPath(b.allocator)) |cuda| {
                defer b.allocator.free(cuda);
                compile.addLibraryPath(cuda);
            }
            compile.step.dependOn(&submodule.step);
        }

        if (compile.target.isDarwin()) {
            compile.linkFramework("OpenCL");
        } else {
            compile.linkSystemLibrary("OpenCL");
        }
    }
}

fn addLibrary(b: *std.Build, options: anytype, docs: bool, linkage: Linkage, libc: bool) *std.build.Step.Compile {
    const lib: *std.build.Step.Compile = if (linkage == .static) b.addStaticLibrary(options) else b.addSharedLibrary(options);
    lib.addIncludePath("include");
    if (libc) lib.linkLibC();
    lib.rdynamic = linkage == .dynamic;
    lib.emit_docs = if (docs) .emit else .default;
    return lib;
}

fn addTests(b: *std.Build, target: CrossTarget, optimize: Optimize, libc: bool) *std.build.Step.Compile {
    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const main_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    if (libc) main_tests.linkLibC();

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&b.addRunArtifact(main_tests).step);
    return main_tests;
}

fn addExample(b: *std.Build, lib: *std.build.Step.Compile, target: CrossTarget, optimize: Optimize, libc: bool) !*std.build.Step.Compile {
    var max_int_align = std.ArrayList(u8).init(b.allocator);
    defer max_int_align.deinit();
    try std.fmt.format(max_int_align.writer(), "{}", .{std.Target.maxIntAlignment(target.toTarget())});

    const example = b.addExecutable(.{
        .name = "Example",
        .target = target,
        .optimize = optimize,
    });
    if (libc) example.linkLibC();
    example.addCSourceFile("example/main.c", &[_][]const u8{"-std=c11"});
    example.addIncludePath("include");
    example.c_std = .C11;
    example.linkLibrary(lib);
    example.emit_llvm_ir = .emit;

    const run = b.addRunArtifact(example);
    // for (kernels) |kernel| {
    //     run.step.dependOn(&kernel.step);
    // }

    const example_step = b.step("example", "Run the included example");
    example_step.dependOn(&run.step);

    return example;
}

fn addComptimeInfo(b: *std.Build, target: CrossTarget, optimize: Optimize, linkage: Linkage, libc: bool) *std.build.Step.Compile {
    const options = .{
        .name = "__comptime_info__",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    };

    const lib = addLibrary(b, options, false, linkage, libc);
    lib.emit_h = true;
    lib.expect_errors = &[_][]const u8{"FileNotFound"};
    return lib;
}

const Utils = struct {
    fn parseComptimeInfo(b: *std.Build) !*std.Build.Step.WriteFile {
        const s = std.fs.cwd().readFileAlloc(b.allocator, "__comptime_info__.h", std.math.maxInt(usize)) catch |e| brk: {
            if (e == error.FileNotFound) break :brk &[0]u8{};
            return e;
        };
        defer b.allocator.free(s);

        const START_STR = "zig_extern void TYPEINFO_";
        const END_STR = "(void);";
        var lines = if (build_target.os.tag == .windows)
            std.mem.splitSequence(u8, s, "\r\n")
        else
            std.mem.splitScalar(u8, s, '\n');

        var output_lines = std.ArrayList(u8).init(b.allocator);
        defer output_lines.deinit();

        while (lines.next()) |line| {
            if (!std.mem.startsWith(u8, line, START_STR) or !std.mem.endsWith(u8, line, END_STR)) continue;
            var info = std.mem.splitBackwardsScalar(u8, line[START_STR.len .. line.len - END_STR.len], '_');

            const value = info.next().?;
            const param = try std.ascii.allocUpperString(b.allocator, info.next().?);
            defer b.allocator.free(param);

            var ty = std.ArrayList(u8).init(b.allocator);
            defer ty.deinit();
            while (info.next()) |chunk| {
                try ty.appendSlice(chunk);
            }

            var parts = std.mem.splitScalar(u8, ty.items, '.');
            if (parts.next()) |lhs| {
                if (parts.next()) |rhs| {
                    if (parts.next() == null and std.ascii.eqlIgnoreCase(lhs, rhs)) {
                        ty.clearRetainingCapacity();
                        try ty.ensureTotalCapacity(rhs.len);
                        ty.items = std.ascii.upperString(ty.allocatedSlice(), rhs);
                    }
                }
            }

            try std.fmt.format(
                output_lines.writer(),
                "#define {s}_{s} {s}\n",
                .{ ty.items, param, value },
            );
        }

        // allocate a large enough buffer to store the cwd
        var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        const path = try std.fs.path.join(b.allocator, &[_][]const u8{
            try std.os.getcwd(&buf),
            "include/uc_extern_sizes.h",
        });
        defer b.allocator.free(path);

        return b.addWriteFile(path, output_lines.items);
    }

    fn getCudaPath(alloc: std.mem.Allocator) !?[]const u8 {
        if (std.os.getenvW(std.unicode.utf8ToUtf16LeStringLiteral("CUDA_PATH"))) |utf16_path| {
            const path = try std.unicode.utf16leToUtf8Alloc(alloc, utf16_path);
            defer alloc.free(path);

            return switch (build_target.cpu.arch) {
                .x86 => try std.fs.path.join(alloc, &[_][]const u8{ path, "lib", "Win32" }),
                .x86_64 => try std.fs.path.join(alloc, &[_][]const u8{ path, "lib", "x64" }),
                else => brk: {
                    std.debug.warn("Unsupported target");
                    break :brk null;
                },
            };
        }
        return null;
    }
};
