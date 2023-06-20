const std = @import("std");
const bridge = @import("bridge.zig");
const builtin = @import("builtin");
const build_target: std.Target = builtin.target;

const CrossTarget = std.zig.CrossTarget;
const Optimize = std.builtin.Mode;

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
    const example = addExample(b, lib, target, optimize, libc);

    // Import libraries
    const compiles = &[_]*std.build.Step.Compile{ lib, tests, example };
    //if (libc) try build_libcpuid(b, compiles, target, submodule);
    if (opencl) |cl| try buildOpenCl(b, cl, compiles, submodule);
}

// TODO look into [this](https://github.com/gustavolsson/zig-opencl-test/blob/master/build.zig)
fn buildOpenCl(b: *std.Build, raw_version: []const u8, compiles: []const *std.build.Step.Compile, submodule: *std.build.Step.Run) !void {
    const semver = try std.SemanticVersion.parse(raw_version);
    var version = std.ArrayList(u8).init(b.allocator);
    defer version.deinit();
    try std.fmt.format(version.writer(), "{}{}{}", .{ semver.major, semver.minor, semver.patch });

    for (compiles) |compile| {
        if (build_target.os.tag == .windows) {
            compile.addSystemIncludePath("./lib/OpenCL-Headers");
            compile.step.dependOn(&submodule.step);
        }

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

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&b.addRunArtifact(main_tests).step);
    return main_tests;
}

fn addExample(b: *std.Build, lib: *std.build.Step.Compile, target: CrossTarget, optimize: Optimize, libc: bool) *std.build.Step.Compile {
    const example_kernel = b.addSharedLibrary(.{ .name = "Example Kernel", .target = CrossTarget.fromTarget() });
    _ = example_kernel;

    const example = b.addExecutable(.{
        .name = "Example",
        .root_source_file = .{ .path = "example/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    example.linkLibrary(lib);
    if (libc) example.linkLibC();

    const example_step = b.step("example", "Run the included example");
    example_step.dependOn(&b.addRunArtifact(example).step);
    return example;
}
