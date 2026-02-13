const std = @import("std");
const platform = @import("platform");
const renderer = @import("renderer");
const logger = @import("logger");

export fn run() callconv(.c) void {
    platform.init() catch {
        // TODO: Add log
        return;
    };
    defer platform.terminate();

    var window = platform.Window.create(600, 600, "NEngine Window", null) catch {
        // TODO: Add log
        return;
    };
    defer window.destroy();

    platform.makeContextCurrent(&window);
    platform.swapInterval(1);

    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer {
        const status = gpa.deinit();
        if (status == .leak) std.debug.panic("Memory leak detected", .{});
    }

    const allocator = gpa.allocator();

    var render = renderer.Renderer.init(allocator, platform.getProcAddress) catch {
        // TODO: Add log
        return;
    };
    defer render.deinit();

    while (!window.shouldClose()) {
        platform.pollEvents();
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
        window.swapBuffers();
    }
}
