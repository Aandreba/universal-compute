const std = @import("std");
const builtin = @import("builtin");
const build_target: std.Target = builtin.target;

const win32 = @cImport(@cInclude("Windows.h"));
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
    const msbuild = if (build_target.os.tag == .windows) try getMsbuildPath(b.allocator) else undefined;
    defer b.allocator.free(msbuild);

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
    const tests = add_tests(b, target, optimize, libc);

    // Import libraries
    const compiles = &[2]*std.build.Step.Compile{ lib, tests };
    if (libc) try build_libcpuid(b, compiles, target, msbuild, submodule);
    if (opencl) |cl| try build_opencl(b, cl, compiles, submodule);
}

fn build_libcpuid(b: *std.Build, compiles: []const *std.build.Step.Compile, target: CrossTarget, submodule: *std.build.Step.Run) !void {
    if (!target.getCpuArch().isX86()) return;

    const wsl = if (build_target.os.tag == .windows) null else null;
    _ = wsl;

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
    configure.setEnvironmentVariable("CC", "zig cc");
    configure.cwd = "lib/libcpuid";
    configure.step.dependOn(&autoreconf.step);

    const make = b.addSystemCommand(&[_][]const u8{"make"});
    make.cwd = "lib/libcpuid";
    make.step.dependOn(&configure.step);

    for (compiles) |compile| {
        compile.addIncludePath("lib/libcpuid/libcpuid");
        compile.addObjectFile("lib/libcpuid/libcpuid/.libs/libcpuid" ++ comptime build_target.staticLibSuffix());
        compile.step.dependOn(&make.step);
    }
}

fn build_opencl(b: *std.Build, raw_version: []const u8, compiles: []const *std.build.Step.Compile, submodule: *std.build.Step.Run) !void {
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

fn add_tests(b: *std.Build, target: CrossTarget, optimize: Optimize, libc: bool) *std.build.Step.Compile {
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

fn getMsbuildPath(alloc: std.mem.Allocator) ![]const u8 {
    const utf16_main_drive = std.os.getenvW(std.unicode.utf8ToUtf16LeStringLiteral("SystemDrive")) orelse return error.SystemDriveNotFound;
    const main_drive = try std.unicode.utf16leToUtf8Alloc(alloc, utf16_main_drive);
    defer alloc.free(main_drive);

    const mvs_path = try std.fs.path.join(alloc, &[_][]const u8{
        main_drive,
        "Program Files",
        "Microsoft Visual Studio",
    });
    defer alloc.free(mvs_path);

    var mvs_dir = try std.fs.openIterableDirAbsolute(mvs_path, .{});
    defer mvs_dir.close();

    // Get latest version
    var latest_version: ?struct { u32, []const u8 } = null;
    var mvs_iter = mvs_dir.iterate();
    while (try mvs_iter.next()) |entry| {
        if (entry.kind != .directory) continue;
        const idx = std.fmt.parseUnsigned(u32, entry.name, 10) catch continue;
        if (latest_version) |latest| {
            if (idx < latest[0]) {
                alloc.free(latest[1]);
                latest_version = .{ idx, try alloc.dupe(u8, entry.name) };
            }
        } else {
            latest_version = .{ idx, try alloc.dupe(u8, entry.name) };
        }
    }

    if (latest_version) |version| {
        // TODO use versions of VS other than "Community"
        defer alloc.free(version[1]);
        return std.fs.path.join(
            alloc,
            &[_][]const u8{
                mvs_path,
                version[1],
                "Community",
                "Msbuild",
                "Current",
                "Bin",
                if (build_target.cpu.arch == .x86) "MSBuild.exe" else "amd64\\MSBuild.exe",
            },
        );
    } else {
        return error.NotFound;
    }
}
