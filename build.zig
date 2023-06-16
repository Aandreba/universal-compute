const std = @import("std");
const builtin = @import("builtin");
const build_target: std.Target = builtin.target;

const CrossTarget = std.zig.CrossTarget;
const Optimize = std.builtin.Mode;

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Libraries
    const libcpuid = build_libcpuid(b, target);

    const lib = b.addSharedLibrary(.{
        .name = "universal-compute",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    lib.emit_docs = .emit;
    // lib.emit_h = true;

    if (libcpuid) |cpuid| {
        lib.addIncludePath("lib/libcpuid/libcpuid");
        lib.addObjectFile("lib/libcpuid/libcpuid/.libs/libcpuid.a");
        lib.step.dependOn(&cpuid.step);
    }

    b.installArtifact(lib);

    build_tests(b, target, optimize);
}

fn build_libcpuid(b: *std.Build, target: CrossTarget) ?*std.build.Step.Run {
    if (!target.getCpuArch().isX86()) return null;

    if (build_target.os.tag == .linux or build_target.os.tag.isDarwin()) {
        const libtoolize = b.addSystemCommand(&[_][]const u8{"libtoolize"});
        libtoolize.cwd = "lib/libcpuid";

        const autoreconf = b.addSystemCommand(&[_][]const u8{ "autoreconf", "--install" });
        autoreconf.cwd = "lib/libcpuid";
        autoreconf.step.dependOn(&libtoolize.step);

        const configure = b.addSystemCommand(&[_][]const u8{"./configure"});
        configure.cwd = "lib/libcpuid";
        configure.step.dependOn(&autoreconf.step);

        const make = b.addSystemCommand(&[_][]const u8{"make"});
        make.cwd = "lib/libcpuid";
        make.step.dependOn(&configure.step);

        return make;
    }

    // TODO windows
    @compileError("not yet implemented");
}

fn build_tests(b: *std.Build, target: CrossTarget, optimize: Optimize) void {
    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const main_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_main_tests = b.addRunArtifact(main_tests);

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build test`
    // This will evaluate the `test` step rather than the default, which is "install".
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_main_tests.step);
}
