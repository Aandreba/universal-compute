const std = @import("std");
const root = @import("main.zig");

pub const uc_result_t = std.meta.Int(.signed, std.math.ceilPowerOfTwo(u16, @bitSizeOf(anyerror) + 1) catch unreachable);
const raw_errot_t = std.meta.Int(.unsigned, 8 * @sizeOf(anyerror));

comptime {
    root.exportLayout(uc_result_t, "ERROR");
}

const errors: []std.builtin.Type.Error = @typeInfo(anyerror).ErrorSet orelse &[0]std.builtin.Type.Error{};
const error_names: [errors.len][*:0]const u8 = brk: {
    var res: [errors.len][*:0]const u8 = undefined;
    for (errors, 0..) |err, i| {
        res[i] = err.name;
    }
    break :brk res;
};
const error_values: [errors.len]uc_result_t = brk: {
    var res: [errors.len]uc_result_t = undefined;
    for (error_names, 0..) |err, i| {
        res[i] = externError(@field(anyerror, err));
    }
    break :brk res;
};

pub const UC_RESULT_SUCCESS: uc_result_t = 0;
// pub export fn ucErrorFromName(raw_name: [*]const u8, name_len: usize, is_valid: ?*bool) uc_error_t {
//     if (std.meta.stringToEnum(anyerror, raw_name[0..name_len])) |err| {
//         if (is_valid) |valid| valid.* = true;
//         return externError(err);
//     }
//     if (is_valid) |valid| valid.* = false;
//     return undefined;
// }

pub export fn ucGetAllErrors(values: ?[*]uc_result_t, names: ?[*][*:0]const u8, len: *usize) uc_result_t {
    if (values == null and names == null) {
        len.* = errors.len;
    } else {
        if (len.* < error_values.len) return externError(error.InvalidSize);
        if (values) |v| @memcpy(v[0..errors.len], &error_values);
        if (names) |n| @memcpy(n[0..errors.len], &error_names);
    }

    return UC_RESULT_SUCCESS;
}

pub export fn ucErrorName(e: uc_result_t) [*:0]const u8 {
    resultToError(e) catch |err| return @errorName(err).ptr;
    return "Success";
}

pub export fn ucErrorHasName(e: uc_result_t, raw_name: [*]const u8, name_len: usize) bool {
    const name = raw_name[0..name_len];
    resultToError(e) catch |err| return std.mem.eql(u8, name, @errorName(err));
    return std.mem.eql(u8, name, "Success");
}

pub fn externError(e: anyerror) uc_result_t {
    return -@intCast(uc_result_t, @errorToInt(e));
}

pub fn resultToError(res: uc_result_t) !void {
    if (res >= 0) return;
    const e = @intCast(raw_errot_t, -res);
    return @intToError(e);
}
