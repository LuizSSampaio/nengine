const std = @import("std");
const logger = @import("logger");

const event_mod = @import("event.zig");
pub const Event = event_mod.Event;
pub const WindowEvent = event_mod.WindowEvent;
pub const KeyEvent = event_mod.KeyEvent;
pub const MouseEvent = event_mod.MouseEvent;
pub const handler = @import("handler.zig");
pub const queue = @import("queue.zig");

pub var manager: ?EventManager = null;
pub const EventManager = struct {
    queue: queue.EventQueue,
    handlers: [handler.EventCount]handler.ListType,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) void {
        const q = queue.EventQueue.init(allocator);

        var handlers: [handler.EventCount]handler.ListType = undefined;
        for (&handlers) |*h| h.* = .{};

        manager = .{
            .queue = q,
            .handlers = handlers,
            .allocator = allocator,
        };
    }

    pub fn deinit() !void {
        if (manager == null) {
            return error.NullManager;
        }

        var self = &manager.?;

        self.queue.deinit();

        for (&self.handlers) |*list| {
            var current = list.first;
            while (current) |h| {
                const next = h.next;
                const node: *handler.Node = @fieldParentPtr("node", h);
                self.allocator.destroy(node);
                current = next;
            }
        }

        manager = null;
    }
};

pub fn dispatch(event: Event, priority: u8) !void {
    if (manager == null) {
        return error.NullManager;
    }

    var self = &manager.?;
    try self.queue.push(event, priority);
}

pub fn addHandler(event: std.meta.Tag(Event), context: handler.Context, callback: handler.Callback) !*handler.Node {
    if (manager == null) {
        return error.NullManager;
    }

    var self = &manager.?;
    const idx = @intFromEnum(event);

    const node = try self.allocator.create(handler.Node);
    node.* = .{
        .context = context,
        .callback = callback,
        .event = event,
        .node = .{},
    };

    self.handlers[idx].prepend(&node.node);
    return node;
}

pub fn removeHandler(node: *handler.Node) !void {
    if (manager == null) {
        return error.NullManager;
    }

    var self = &manager.?;
    const idx = @intFromEnum(node.event);

    self.handlers[idx].remove(&node.node);
    self.allocator.destroy(node);
}

pub fn poolEvents(config: struct { max_events: u32 = 128 }) !void {
    if (manager == null) {
        return error.NullManager;
    }

    var self = &manager.?;

    var count: u32 = 0;
    while (count < config.max_events) : (count += 1) {
        const event = self.queue.pop() orelse break;

        const idx = @intFromEnum(event);
        var node = self.handlers[idx].first;
        while (node) |n| : (node = n.next) {
            const hn: *handler.Node = @fieldParentPtr("node", n);
            hn.callback(hn.context, &event);
        }
    }
}

export fn dispatchWindowCloseEvent(priority: u8) callconv(.c) c_int {
    dispatch(.{ .window = .close }, priority) catch |e| {
        logger.err().err(e).string("@err", "Fail on dipatch event").log();
        return -1;
    };
    return 0;
}

export fn dispatchWindowResizeEvent(width: i32, height: i32, priority: u8) callconv(.c) c_int {
    dispatch(.{
        .window = .{
            .resize = .{
                .width = width,
                .height = height,
            },
        },
    }, priority) catch |e| {
        logger.err().err(e).string("@err", "Fail on dipatch event").log();
        return -1;
    };
    return 0;
}

export fn dispatchWindowFocusEvent(focused: bool, priority: u8) callconv(.c) c_int {
    dispatch(.{ .window = .{ .focus = focused } }, priority) catch |e| {
        logger.err().err(e).string("@err", "Fail on dipatch event").log();
        return -1;
    };
    return 0;
}

export fn dispatchWindowMovedEvent(x: i32, y: i32, priority: u8) callconv(.c) c_int {
    dispatch(.{
        .window = .{
            .moved = .{
                .x = x,
                .y = y,
            },
        },
    }, priority) catch |e| {
        logger.err().err(e).string("@err", "Fail on dipatch event").log();
        return -1;
    };
    return 0;
}

export fn dispatchKeyPressedEvent(keycode: i32, repeat: i32, priority: u8) callconv(.c) c_int {
    dispatch(.{
        .key = .{
            .pressed = .{
                .keycode = keycode,
                .repeat = repeat,
            },
        },
    }, priority) catch |e| {
        logger.err().err(e).string("@err", "Fail on dipatch event").log();
        return -1;
    };
    return 0;
}

export fn dispatchKeyReleasedEvent(keycode: i32, priority: u8) callconv(.c) c_int {
    dispatch(.{ .key = .{ .released = .{ .keycode = keycode } } }, priority) catch |e| {
        logger.err().err(e).string("@err", "Fail on dipatch event").log();
        return -1;
    };
    return 0;
}

export fn dispatchMouseMovedEvent(x: i32, y: i32, priority: u8) callconv(.c) c_int {
    dispatch(.{
        .mouse = .{
            .moved = .{
                .x = x,
                .y = y,
            },
        },
    }, priority) catch |e| {
        logger.err().err(e).string("@err", "Fail on dipatch event").log();
        return -1;
    };
    return 0;
}

export fn dispatchMouseScrolledEvent(x_offset: i32, y_offset: i32, priority: u8) callconv(.c) c_int {
    dispatch(.{
        .mouse = .{
            .scrolled = .{
                .xOffset = x_offset,
                .yOffset = y_offset,
            },
        },
    }, priority) catch |e| {
        logger.err().err(e).string("@err", "Fail on dipatch event").log();
        return -1;
    };
    return 0;
}
