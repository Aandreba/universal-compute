const std = @import("std");
const CrossTarget = std.zig.CrossTarget;
const Mode = std.builtin.Mode;

const SpirvFeature = std.Target.spirv.Feature;

pub const Target = enum {
    Host,
    OpenCl,
    Cuda,

    pub const All = enumVariants(Target);

    fn build(self: Target, b: *std.Build, options: BuildOptions, bridge: *std.Build.Module) !*std.build.Step.Compile {
        var name = std.ArrayList(u8).init(b.allocator);
        defer name.deinit();
        try std.fmt.format(name.writer(), "{s}-{s}", .{ options.name, @tagName(self) });

        const target = switch (self) {
            .Host => options.host_target,
            .OpenCl => brk: {
                const features = [_]SpirvFeature{
                    .Kernel,
                    .Addresses,
                    .Int8,
                    .Int16,
                    .Int64,
                    .Float64,
                    .GenericPointer,
                    .SPV_KHR_variable_pointers,
                };

                var target = defaultTarget(.spirv32, .opencl);
                target.cpu.features.addFeatureSet(std.Target.spirv.featureSet(&features));
                break :brk CrossTarget.fromTarget(target);
            },
            .Cuda => CrossTarget.fromTarget(defaultTarget(.nvptx, .cuda)),
        };

        const lib = b.addSharedLibrary(.{
            .name = name.items,
            .root_source_file = options.source,
            .target = target,
            .optimize = options.optimize,
        });
        lib.emit_bin = .emit;
        lib.emit_asm = .emit;
        lib.linkage = .dynamic;
        lib.single_threaded = true;
        lib.addModule("uc-bridge", bridge);

        if (self == .OpenCl) {
            lib.use_llvm = true;
            lib.use_lld = false;
        }

        return lib;
    }
};

pub const BuildOptions = struct {
    name: []const u8,
    host_target: std.zig.CrossTarget,
    optimize: std.builtin.OptimizeMode,
    source: ?std.Build.FileSource = null,
    bridge_path: []const u8 = "bridge/main.zig",
};

pub fn buildKernel(b: *std.Build, raw_device_targets: ?[]const Target, options: BuildOptions) ![]const *std.build.Step.Compile {
    const device_targets = raw_device_targets orelse Target.All[0..];
    const module = b.createModule(.{
        .source_file = .{ .path = options.bridge_path },
    });

    var steps = try b.allocator.alloc(*std.build.Step.Compile, device_targets.len);
    for (device_targets, 0..) |target, i| {
        steps[i] = try target.build(b, options, module);
    }

    return steps;
}

// UTILS
fn enumVariants(comptime T: type) [std.meta.fields(T).len]T {
    const names = std.meta.fields(T);
    var result: [names.len]T = undefined;

    for (names, 0..) |field, i| {
        result[i] = std.meta.intToEnum(T, field.value) catch unreachable;
    }

    return result;
}

fn defaultTarget(arch: std.Target.Cpu.Arch, os_tag: std.Target.Os.Tag) std.Target {
    const os = os_tag.defaultVersionRange(arch);
    return .{
        .cpu = std.Target.Cpu.baseline(arch),
        .abi = std.Target.Abi.default(arch, os),
        .os = os,
        .ofmt = std.Target.ObjectFormat.default(os_tag, arch),
    };
}
