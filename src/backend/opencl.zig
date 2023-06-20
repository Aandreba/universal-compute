const std = @import("std");
const root = @import("../main.zig");
pub const c = @cImport(@cInclude("CL/cl.h"));
const alloc = root.alloc;

pub fn getDevices(devices: []root.Device) !usize {
    // Platforms
    var num_platforms: c.cl_uint = 0;
    try clError(c.clGetPlatformIDs(0, null, &num_platforms));
    var platforms = try alloc.alloc(c.cl_platform_id, @intCast(usize, num_platforms));
    defer alloc.free(platforms);
    try clError(c.clGetPlatformIDs(num_platforms, @ptrCast([*]c.cl_platform_id, platforms), null));

    // Devices
    var count: usize = 0;
    for (platforms) |platform| {
        if (count >= devices.len) break;

        var num_devices: c.cl_uint = undefined;
        try clError(c.clGetDeviceIDs(
            platform,
            c.CL_DEVICE_TYPE_ALL,
            0,
            null,
            &num_devices,
        ));

        var cl_devices = try alloc.alloc(c.cl_device_id, std.math.min(
            @intCast(usize, num_devices),
            devices.len,
        ));
        defer alloc.free(devices);

        try clError(c.clGetDeviceIDs(
            platform,
            c.CL_DEVICE_TYPE_ALL,
            @intCast(c.cl_uint, cl_devices.len),
            @ptrCast([*]c.cl_device_id, devices),
            null,
        ));

        for (cl_devices, 0..) |cl_device, i| {
            devices[count + i] = .{ .OpenCl = cl_device };
        }

        count += cl_devices.len;
    }

    return count;
}

pub fn getDeviceInfo(info: root.Device.Info, device: c.cl_device_id, raw_ptr: ?*anyopaque, raw_len: *usize) !void {
    if (raw_ptr) |ptr| {
        switch (info) {
            .CORE_COUNT => {},
            else => {
                const raw_info = ucToclDeviceInfo(info);
                return clError(c.clGetDeviceInfo(device, raw_info, raw_len.*, ptr, null));
            },
        }
    } else {
        switch (info) {
            .CORE_COUNT => raw_len.* = @sizeOf(usize),
            else => {
                const raw_info = ucToclDeviceInfo(info);
                return clError(c.clGetDeviceInfo(device, raw_info, 0, null, raw_len));
            },
        }
    }
}

pub fn clError(e: c.cl_int) !void {
    return switch (e) {
        c.CL_SUCCESS => return,
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

fn ucToclDeviceInfo(info: root.Device.Info) c.cl_device_info {
    return switch (info) {
        .VENDOR => c.CL_DEVICE_VENDOR,
        .NAME => c.CL_DEVICE_NAME,
        .CORES => c.CL_DEVICE_MAX_COMPUTE_UNITS,
    };
}
