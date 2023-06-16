pub const Host = @import("backend/host.zig");
pub const OpenCl = @import("backend/opencl.zig");
pub const Cuda = @import("backend/cuda.zig");
pub const WebGpu = @import("backend/webgpu.zig");

// Default backend
const Impl = Host;
