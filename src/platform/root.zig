const glfw = @import("glfw");

pub const window = @import("window.zig");

pub fn init() !void {
    try glfw.init();
}

pub fn terminate() void {
    glfw.terminate();
}
