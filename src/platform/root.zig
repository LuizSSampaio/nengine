const glfw = @import("glfw");

pub fn init() !void {
    glfw.init();
}

pub fn terminate() !void {
    glfw.terminate();
}
