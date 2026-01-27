const std = @import("std");
const platform = @import("platform");
const renderer = @import("renderer");

pub fn run() !void {
    try platform.init();
    defer platform.terminate();

    platform.windowHint(.client_api, .opengl_api);
    platform.windowHint(.context_version_major, 3);
    platform.windowHint(.context_version_minor, 3);
    platform.windowHint(.opengl_profile, .opengl_core_profile);
    platform.windowHint(.opengl_forward_compat, true);
    platform.windowHint(.doublebuffer, true);

    var window = try platform.Window.create(600, 600, "NEngine Window", null);
    defer window.destroy();

    platform.makeContextCurrent(&window);
    platform.swapInterval(1);

    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer {
        const status = gpa.deinit();
        if (status == .leak) std.debug.panic("Memory leak detected", .{});
    }

    const allocator = gpa.allocator();

    var render = try renderer.Renderer.init(allocator, platform.getProcAddress);
    defer render.deinit();

    while (!window.shouldClose()) {
        platform.pollEvents();
        try render.beginFrame();

        try render.clear(.{ .color = .{ 0.1, 0.2, 0.3, 1.0 } });

        try render.endFrame();
        window.swapBuffers();
    }
}
