const glfw = @import("glfw");

pub const Window = @import("window.zig").Window;

pub fn init() !void {
    try glfw.init();
}

pub fn terminate() void {
    glfw.terminate();
}

pub fn pollEvents() void {
    glfw.pollEvents();
}
