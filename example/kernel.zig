const bridge = @import("uc-bridge");
const UCAPI = bridge.UCAPI;

pub export fn main(n: u32, a: [*]const f32, b: [*]const f32, c: [*]f32) callconv(.Kernel) void {
    _ = b;
    var i = bridge.globalId(0);
    while (i < n) {
        c[i] = a[i];
        i += bridge.globalSize(0);
    }
}
