const platform = @import("platform");

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

    while (!window.shouldClose()) {
        platform.pollEvents();

        window.swapBuffers();
    }
}
