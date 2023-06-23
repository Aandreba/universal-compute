const std = @import("std");

pub const uc_result_t = std.meta.Int(.signed, std.math.ceilPowerOfTwo(u16, @bitSizeOf(anyerror) + 1) catch unreachable);
const raw_errot_t = std.meta.Int(.unsigned, 8 * @sizeOf(anyerror));

pub const UC_RESULT_SUCCESS: uc_result_t = 0;
// pub export fn ucErrorFromName(raw_name: [*]const u8, name_len: usize, is_valid: ?*bool) uc_error_t {
//     if (std.meta.stringToEnum(anyerror, raw_name[0..name_len])) |err| {
//         if (is_valid) |valid| valid.* = true;
//         return externError(err);
//     }
//     if (is_valid) |valid| valid.* = false;
//     return undefined;
// }

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
    const e = @intCast(raw_errot_t, -res);
    if (e >= 0) return;
    return @intToError(e);
}
