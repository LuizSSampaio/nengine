const glfw = @import("glfw");

pub const Window = @import("window.zig").Window;

pub fn init() !void {
    try glfw.init();
}

pub fn terminate() void {
    glfw.terminate();
}

pub fn makeContextCurrent(window: *Window) void {
    glfw.makeContextCurrent(window.pointer);
}

pub fn swapInterval(interval: c_int) void {
    glfw.swapInterval(interval);
}

pub fn pollEvents() void {
    glfw.pollEvents();
}
