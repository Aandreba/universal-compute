const std = @import("std");
pub const features = @import("features.zig");
pub const backend = @import("backend.zig");
pub const device = @import("device.zig");
pub const context = @import("context.zig");
pub const buffer = @import("buffer.zig");
pub const event = @import("event.zig");

pub usingnamespace @import("utils.zig");
pub usingnamespace @import("error.zig");
usingnamespace backend;
usingnamespace device;
usingnamespace context;
usingnamespace buffer;
usingnamespace event;

pub const Backend = backend.Kind;

pub const cl = if (features.opencl) |cl_version| struct {
    const root = @import("main.zig");
    const c = @cImport({
        @cDefine("CL_TARGET_OPENCL_VERSION", cl_version);
        @cInclude("CL/cl.h");
    });
    pub usingnamespace c;

    pub fn clError(e: c.cl_int) !void {
        if (e >= 0) return;
        return switch (e) {
            c.CL_SUCCESS => unreachable,
            c.CL_DEVICE_NOT_FOUND => error.DeviceNotFound,
            c.CL_DEVICE_NOT_AVAILABLE => error.DeviceNotAvailable,
            c.CL_COMPILER_NOT_AVAILABLE => error.CompilerNotAvailable,
            c.CL_MEM_OBJECT_ALLOCATION_FAILURE => error.MemObjectAllocationFailure,
            c.CL_OUT_OF_RESOURCES => error.OutOfResources,
            c.CL_OUT_OF_HOST_MEMORY => error.OutOfMemory,
            c.CL_PROFILING_INFO_NOT_AVAILABLE => error.ProfilingInfoNotAvailable,
            c.CL_MEM_COPY_OVERLAP => error.MemCopyOverlap,
            c.CL_IMAGE_FORMAT_MISMATCH => error.ImageFormatMismatch,
            c.CL_IMAGE_FORMAT_NOT_SUPPORTED => error.ImageFormatNotSupported,
            c.CL_BUILD_PROGRAM_FAILURE => error.BuildProgramFailure,
            c.CL_MAP_FAILURE => error.MapFailure,
            c.CL_MISALIGNED_SUB_BUFFER_OFFSET => error.MisalignedSubBufferOffset,
            c.CL_EXEC_STATUS_ERROR_FOR_EVENTS_IN_WAIT_LIST => error.ExecStatusErrorForEventsInWaitList,
            c.CL_COMPILE_PROGRAM_FAILURE => error.CompileProgramFailure,
            c.CL_LINKER_NOT_AVAILABLE => error.LinkerNotAvailable,
            c.CL_LINK_PROGRAM_FAILURE => error.LinkProgramFailure,
            c.CL_DEVICE_PARTITION_FAILED => error.DevicePartitionFailed,
            c.CL_KERNEL_ARG_INFO_NOT_AVAILABLE => error.KernelArgInfoNotAvailable,
            c.CL_INVALID_VALUE => error.InvalidValue,
            c.CL_INVALID_DEVICE_TYPE => error.InvalidDeviceType,
            c.CL_INVALID_PLATFORM => error.InvalidPlatform,
            c.CL_INVALID_DEVICE => error.InvalidDevice,
            c.CL_INVALID_CONTEXT => error.InvalidContext,
            c.CL_INVALID_QUEUE_PROPERTIES => error.InvalidQueueProperties,
            c.CL_INVALID_COMMAND_QUEUE => error.InvalidCommandQueue,
            c.CL_INVALID_HOST_PTR => error.InvalidHostPtr,
            c.CL_INVALID_MEM_OBJECT => error.InvalidMemObject,
            c.CL_INVALID_IMAGE_FORMAT_DESCRIPTOR => error.InvalidImageFormatDescriptor,
            c.CL_INVALID_IMAGE_SIZE => error.InvalidImageSize,
            c.CL_INVALID_SAMPLER => error.InvalidSampler,
            c.CL_INVALID_BINARY => error.InvalidBinary,
            c.CL_INVALID_BUILD_OPTIONS => error.InvalidBuildOptions,
            c.CL_INVALID_PROGRAM => error.InvalidProgram,
            c.CL_INVALID_PROGRAM_EXECUTABLE => error.InvalidProgramExecutable,
            c.CL_INVALID_KERNEL_NAME => error.InvalidKernelName,
            c.CL_INVALID_KERNEL_DEFINITION => error.InvalidKernelDefinition,
            c.CL_INVALID_KERNEL => error.InvalidKernel,
            c.CL_INVALID_ARG_INDEX => error.InvalidArgIndex,
            c.CL_INVALID_ARG_VALUE => error.InvalidArgValue,
            c.CL_INVALID_ARG_SIZE => error.InvalidArgSize,
            c.CL_INVALID_KERNEL_ARGS => error.InvalidKernelArgs,
            c.CL_INVALID_WORK_DIMENSION => error.InvalidWorkDimension,
            c.CL_INVALID_WORK_GROUP_SIZE => error.InvalidWorkGroupSize,
            c.CL_INVALID_WORK_ITEM_SIZE => error.InvalidWorkItemSize,
            c.CL_INVALID_GLOBAL_OFFSET => error.InvalidGlobalOffset,
            c.CL_INVALID_EVENT_WAIT_LIST => error.InvalidEventWaitList,
            c.CL_INVALID_EVENT => error.InvalidEvent,
            c.CL_INVALID_OPERATION => error.InvalidOperation,
            c.CL_INVALID_GL_OBJECT => error.InvalidGlObject,
            c.CL_INVALID_BUFFER_SIZE => error.InvalidBufferSize,
            c.CL_INVALID_MIP_LEVEL => error.InvalidMipLevel,
            c.CL_INVALID_GLOBAL_WORK_SIZE => error.InvalidGlobalWorkSize,
            c.CL_INVALID_PROPERTY => error.InvalidProperty,
            c.CL_INVALID_IMAGE_DESCRIPTOR => error.InvalidImageDescriptor,
            c.CL_INVALID_COMPILER_OPTIONS => error.InvalidCompilerOptions,
            c.CL_INVALID_LINKER_OPTIONS => error.InvalidLinkerOptions,
            c.CL_INVALID_DEVICE_PARTITION_COUNT => error.InvalidDevicePartitionCount,
            c.CL_INVALID_PIPE_SIZE => error.InvalidPipeSize,
            c.CL_INVALID_DEVICE_QUEUE => error.InvalidDeviceQueue,
            //c.CL_INVALID_SPEC_ID => error.InvalidSpecId,
            //c.CL_MAX_SIZE_RESTRICTION_EXCEEDED => error.MaxSizeRestrictionExceeded,
            else => error.Unkown,
        };
    }

    pub fn externError(e: c.cl_int) root.uc_result_t {
        clError(e) catch |err| return root.externError(err);
        return root.UC_RESULT_SUCCESS;
    }
} else struct {};

pub fn castOpaque(comptime T: type, ptr: *anyopaque, len: usize) !*T {
    if (len < @sizeOf(T)) return error.InvalidSize;
    return @ptrCast(*T, @alignCast(@alignOf(T), ptr));
}

pub fn exportLayout(comptime T: type) void {
    const Impl = struct {
        fn s() callconv(.C) void {}
        fn a() callconv(.C) void {}
    };

    @export(Impl.a, .{ .name = "TYPEINFO_" ++ @typeName(T) ++ "_size_" ++ std.fmt.comptimePrint("{}", .{@sizeOf(T)}) });
    @export(Impl.s, .{ .name = "TYPEINFO_" ++ @typeName(T) ++ "_align_" ++ std.fmt.comptimePrint("{}", .{@alignOf(T)}) });
}
