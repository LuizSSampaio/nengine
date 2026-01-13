const platform = @import("platform");

pub fn run() !void {
    try platform.init();
    defer platform.terminate();

    var window = try platform.Window.create(600, 600, "NEngine Window", null);
    defer window.destroy();

    while (!window.shouldClose()) {
        platform.pollEvents();

        window.swapBuffers();
    }
}
