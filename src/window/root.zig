const glfw = @import("glfw");

pub const windowProcAddress = glfw.getProcAddress;

pub const Window = struct {
    pointer: *glfw.Window,
    width: i32,
    height: i32,
    title: [:0]const u8,
    vsync: bool,

    pub fn init(width: i32, height: i32, title: [:0]const u8, vsync: bool) !@This() {
        try glfw.init();
        errdefer glfw.terminate();

        glfw.windowHint(.client_api, .opengl_api);
        glfw.windowHint(.context_version_major, 3);
        glfw.windowHint(.context_version_minor, 3);
        glfw.windowHint(.opengl_profile, .opengl_core_profile);
        glfw.windowHint(.opengl_forward_compat, true);
        glfw.windowHint(.doublebuffer, true);

        const window = try glfw.createWindow(width, height, title, null);
        errdefer window.destroy();

        glfw.makeContextCurrent(window);
        glfw.swapInterval(if (vsync) 1 else 0);

        return .{
            .pointer = window,
            .width = width,
            .height = height,
            .title = title,
            .vsync = vsync,
        };
    }

    pub fn deinit(self: *@This()) void {
        self.pointer.destroy();
        glfw.terminate();
    }

    pub fn update(self: *@This()) void {
        glfw.pollEvents();
        self.pointer.swapBuffers();
    }

    pub fn shouldClose(self: *@This()) bool {
        return self.pointer.shouldClose();
    }

    pub fn setVsync(self: *@This(), enable: bool) void {
        self.vsync = enable;
        glfw.swapInterval(if (enable) 1 else 0);
    }
};
