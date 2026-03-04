const std = @import("std");
const glfw = @import("glfw");
const event = @import("event");
const log = @import("logger");

pub const windowProcAddress = glfw.getProcAddress;

var global: ?*Window = null;

pub const Window = struct {
    pointer: *glfw.Window,
    width: i32,
    height: i32,
    title: [:0]const u8,
    vsync: bool,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, width: i32, height: i32, title: [:0]const u8, vsync: bool) !*@This() {
        try glfw.init();
        errdefer glfw.terminate();

        glfw.windowHint(.client_api, .opengl_api);
        glfw.windowHint(.context_version_major, 3);
        glfw.windowHint(.context_version_minor, 3);
        glfw.windowHint(.opengl_profile, .opengl_core_profile);
        glfw.windowHint(.opengl_forward_compat, true);
        glfw.windowHint(.doublebuffer, true);

        const pointer = try glfw.createWindow(width, height, title, null);
        errdefer pointer.destroy();

        glfw.makeContextCurrent(pointer);
        glfw.swapInterval(if (vsync) 1 else 0);

        _ = glfw.setFramebufferSizeCallback(pointer, glfwResizeCallback);
        _ = glfw.setWindowCloseCallback(pointer, glfwWindowCloseCallback);
        _ = glfw.setKeyCallback(pointer, glfwWindowKeyCallback);

        const window = try allocator.create(Window);
        errdefer allocator.destroy(window);

        window.* = .{
            .pointer = pointer,
            .width = width,
            .height = height,
            .title = title,
            .vsync = vsync,
            .allocator = allocator,
        };

        global = window;

        return window;
    }

    pub fn deinit(self: *@This()) void {
        global = null;
        self.pointer.destroy();
        self.allocator.destroy(self);
        glfw.terminate();
    }

    pub fn update(self: *@This()) void {
        glfw.pollEvents();
        self.pointer.swapBuffers();
    }

    // TODO: Remove this method
    pub fn shouldClose(self: *@This()) bool {
        return self.pointer.shouldClose();
    }

    pub fn setVsync(self: *@This(), enable: bool) void {
        self.vsync = enable;
        glfw.swapInterval(if (enable) 1 else 0);
    }

    fn glfwResizeCallback(window: *glfw.Window, width: c_int, height: c_int) callconv(.c) void {
        _ = window;
        if (global) |g| {
            g.width = width;
            g.height = height;
        }

        event.dispatch(.{
            .window = .{
                .resize = .{
                    .width = width,
                    .height = height,
                },
            },
        }, 0) catch |err| {
            log.err().string("msg", "Error on dispatch window resize event").err(err).log();
        };
    }

    fn glfwWindowCloseCallback(window: *glfw.Window) callconv(.c) void {
        _ = window;
        event.dispatch(.{
            .window = .close,
        }, 0) catch |err| {
            log.err().string("msg", "Error on dispatch window close event").err(err).log();
        };
    }

    fn glfwWindowKeyCallback(
        window: *glfw.Window,
        key: glfw.Key,
        scancode: c_int,
        action: glfw.Action,
        mods: glfw.Mods,
    ) callconv(.c) void {
        _ = window;
        _ = key;
        _ = scancode;
        _ = action;
        _ = mods;
        // TODO: Emit window key event
    }
};
