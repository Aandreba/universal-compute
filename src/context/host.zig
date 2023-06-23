const std = @import("std");
const root = @import("../main.zig");

pub const Context = union(enum) {
    Single: SingleContext,
    Multi: MultiContext,
};

pub fn createContext(options: root.context.ContextConfig) !Context {
    _ = options;
}

// Context for single-threaded devices
const SingleContext = struct {};

const MultiContext = struct {};
