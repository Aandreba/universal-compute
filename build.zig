const std = @import("std");
const bridge = @import("bridge.zig");
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

    // Library options
    const options = .{
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
    const lib: *std.build.Step.Compile = if (linkage == .static) b.addStaticLibrary(options) else b.addSharedLibrary(options);
    lib.addIncludePath("include");
    if (libc) lib.linkLibC();
    lib.rdynamic = linkage == .dynamic;
    lib.emit_docs = if (docs) .emit else .default;
    lib.emit_analysis = .emit;
    b.installArtifact(lib);

    // Tests
    const tests = addTests(b, target, optimize, libc);
    const example = try addExample(b, lib, target, optimize, libc);

    // Import libraries
    const compiles = &[_]*std.build.Step.Compile{ lib, tests, example };
    addModules(compiles, submodule, &[_]ModuleEntry{
        .{ "zigrc", zigrc },
    });
    //if (libc) try build_libcpuid(b, compiles, target, submodule);
    if (opencl) |cl| try buildOpenCl(b, cl, compiles, submodule);
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
fn buildOpenCl(b: *std.Build, raw_version: []const u8, compiles: []const *std.build.Step.Compile, submodule: *std.build.Step.Run) !void {
    const semver = try std.SemanticVersion.parse(raw_version);
    var version = std.ArrayList(u8).init(b.allocator);
    defer version.deinit();
    try std.fmt.format(version.writer(), "{}{}{}", .{ semver.major, semver.minor, semver.patch });

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

        compile.defineCMacro("CL_TARGET_OPENCL_VERSION", version.items);
    }
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

    const run = b.addRunArtifact(example);
    // for (kernels) |kernel| {
    //     run.step.dependOn(&kernel.step);
    // }

    const example_step = b.step("example", "Run the included example");
    example_step.dependOn(&run.step);
    example_step.dependOn(&lib.step);

    return example;
}

const Utils = struct {
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
