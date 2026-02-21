const std = @import("std");

const logger = @import("logger");
const renderer = @import("renderer");
const win = @import("window");
const Window = win.Window;
const windowProcAddress = win.windowProcAddress;

export fn run() callconv(.c) void {
    logger.info().string("engine", "Starting Engine").log();

    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer {
        const status = gpa.deinit();
        if (status == .leak) std.debug.panic("Memory leak detected", .{});
    }
    const allocator = gpa.allocator();

    var window = Window.init(allocator, 1280, 720, "Nengine Window", true) catch {
        logger.fatal().string("@err", "Failed to initialize window").log();
        return;
    };
    defer window.deinit();

    var render = renderer.Renderer.init(allocator, windowProcAddress) catch {
        logger.fatal().string("@err", "Failed to initialize renderer").log();
        return;
    };
    defer render.deinit();

    while (!window.shouldClose()) {
        render.beginFrame() catch {
            // TODO: Add log
            return;
        };

        render.clear(.{ .color = .{ 0.1, 0.2, 0.3, 1.0 } }) catch {
            // TODO: Add log
            return;
        };

        render.endFrame() catch {
            // TODO: Add log
            return;
        };
        window.update();
    }
}
