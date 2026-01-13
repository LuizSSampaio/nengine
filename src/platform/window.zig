const glfw = @import("glfw");

pub const Window = struct {
    pointer: *glfw.Window,

    pub fn create(width: c_int, height: c_int, title: [:0]const u8, monitor: ?*glfw.Monitor) !Window {
        const window = try glfw.createWindow(width, height, title, monitor);
        return .{ .pointer = window };
    }

    pub fn destroy(window: *Window) void {
        window.pointer.destroy();
    }

    pub fn shouldClose(window: *Window) bool {
        return window.pointer.shouldClose();
    }

    pub fn swapBuffers(window: *Window) void {
        window.pointer.swapBuffers();
    }
};
