const std = @import("std");
const builtin = @import("builtin");
const build_target: std.Target = builtin.target;

const CrossTarget = std.zig.CrossTarget;
const Optimize = std.builtin.Mode;

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) !void {
    if (build_target.os.tag == .windows) {
        @compileError("Compilation on Windows is not supported. Use WSL instead");
    }

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

    // Flags and options
    const docs = b.option(bool, "docs", "Generate docs (defaults to false)") orelse false;
    const static = b.option(bool, "static", "Compile as static library, otherwise compile as shared library (defaults to false)") orelse false;
    const libc = b.option(bool, "libc", "Links libc to the output library (defaults to true)") orelse true;
    const opencl = b.option([]const u8, "opencl", "Add OpenCL backend with the specified OpenCL version (defaults to null)") orelse null;

    // Library
    const lib: *std.build.Step.Compile = if (static) b.addStaticLibrary(options) else b.addSharedLibrary(options);
    if (libc) lib.linkLibC();
    lib.emit_docs = if (docs) .emit else .default;
    b.installArtifact(lib);

    // Tests
    const tests = addTests(b, target, optimize, libc);

    // Import libraries
    const compiles = &[2]*std.build.Step.Compile{ lib, tests };
    if (libc) try build_libcpuid(b, compiles, target, submodule);
    if (opencl) |cl| try buildOpenCl(b, cl, compiles, submodule);
}

fn build_libcpuid(b: *std.Build, compiles: []const *std.build.Step.Compile, target: CrossTarget, submodule: *std.build.Step.Run) !void {
    if (!target.getCpuArch().isX86()) return;

    const libtoolize = b.addSystemCommand(&[_][]const u8{"libtoolize"});
    libtoolize.cwd = "lib/libcpuid";
    libtoolize.step.dependOn(&submodule.step);

    const autoreconf = b.addSystemCommand(&[_][]const u8{ "autoreconf", "--install" });
    autoreconf.cwd = "lib/libcpuid";
    autoreconf.step.dependOn(&libtoolize.step);

    const zig_triple = try target.linuxTriple(b.allocator);
    defer b.allocator.free(zig_triple);
    var host_str = std.ArrayList(u8).init(b.allocator);
    defer host_str.deinit();
    try host_str.appendSlice("--host=");
    try host_str.appendSlice(zig_triple);

    const configure = b.addSystemCommand(&[_][]const u8{ "./configure", host_str.items });
    //configure.setEnvironmentVariable("CC", "zig cc");
    configure.cwd = "lib/libcpuid";
    configure.step.dependOn(&autoreconf.step);

    const make = b.addSystemCommand(&[_][]const u8{"make"});
    make.cwd = "lib/libcpuid";
    make.step.dependOn(&configure.step);

    for (compiles) |compile| {
        compile.addIncludePath("lib/libcpuid/libcpuid");
        compile.addObjectFile("lib/libcpuid/libcpuid/.libs/libcpuid.a");
        compile.step.dependOn(&make.step);
    }
}

fn buildOpenCl(b: *std.Build, raw_version: []const u8, compiles: []const *std.build.Step.Compile, submodule: *std.build.Step.Run) !void {
    _ = submodule;
    const semver = try std.SemanticVersion.parse(raw_version);
    var version = std.ArrayList(u8).init(b.allocator);
    defer version.deinit();
    try std.fmt.format(version.writer(), "{}{}{}", .{ semver.major, semver.minor, semver.patch });

    // TODO non-unix include opencl headers

    for (compiles) |compile| {
        compile.linkSystemLibrary("OpenCL");
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

    const run_main_tests = b.addRunArtifact(main_tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_main_tests.step);
    return main_tests;
}
