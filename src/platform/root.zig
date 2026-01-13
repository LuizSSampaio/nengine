const glfw = @import("glfw");

pub fn init() !void {
    try glfw.init();
}

pub fn terminate() void {
    glfw.terminate();
}
