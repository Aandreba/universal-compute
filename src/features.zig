const features = @import("features");
pub usingnamespace features;

pub const has_opencl: bool = features.opencl != null;
