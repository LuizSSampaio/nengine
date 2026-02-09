const glfw = @import("glfw");

pub const Window = @import("window.zig").Window;

pub const getProcAddress = glfw.getProcAddress;

pub fn init() !void {
    try glfw.init();

    glfw.windowHint(.client_api, .opengl_api);
    glfw.windowHint(.context_version_major, 3);
    glfw.windowHint(.context_version_minor, 3);
    glfw.windowHint(.opengl_profile, .opengl_core_profile);
    glfw.windowHint(.opengl_forward_compat, true);
    glfw.windowHint(.doublebuffer, true);
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
