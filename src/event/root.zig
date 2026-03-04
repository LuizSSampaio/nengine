const std = @import("std");

const event_mod = @import("event.zig");
pub const Event = event_mod.Event;
pub const WindowEvent = event_mod.WindowEvent;
pub const KeyEvent = event_mod.KeyEvent;
pub const MouseEvent = event_mod.MouseEvent;
pub const handler = @import("handler.zig");

pub var manager: ?EventManager = null;
pub const EventManager = struct {
    pool_mutex: std.Thread.Mutex,

    pool: std.ArrayList(Event),
    handlers: [handler.EventCount]handler.ListType,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, buffer_size: usize) !void {
        var pool: std.ArrayList(Event) = .empty;
        errdefer pool.deinit(allocator);

        var handlers: [handler.EventCount]handler.ListType = undefined;
        for (&handlers) |*h| h.* = .{};

        try pool.ensureTotalCapacity(allocator, buffer_size);

        manager = .{
            .pool_mutex = .{},
            .pool = pool,
            .handlers = handlers,
            .allocator = allocator,
        };
    }

    pub fn deinit() !void {
        if (manager == null) {
            return error.NullManager;
        }

        var self = &manager.?;

        self.pool.deinit(self.allocator);

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

pub fn dispatch(event: Event) !void {
    if (manager == null) {
        return error.NullManager;
    }

    self.pool_mutex.lock();
    defer self.pool_mutex.unlock();
    errdefer self.pool_mutex.unlock();

    try self.pool.append(self.allocator, event);
    var self = &manager.?;
}

pub fn addHandler(event: std.meta.Tag(Event), context: handler.Context, callback: handler.Callback) !*handler.Node {
    if (manager == null) {
        return error.NullManager;
    }

    var self = &manager.?;
    const idx = @intFromEnum(event);

    const node = self.allocator.create(handler.Node);
    node.* = .{
        .context = context,
        .callback = callback,
        .event = event,
        .node = .{},
    };

    self.handlers[idx].prepend(node);
    return node;
}

pub fn removeHandler(node: *handler.Node) !void {
    if (manager == null) {
        return error.NullManager;
    }

    var self = &manager.?;
    const idx = @intFromEnum(node.event);

    self.handlers[idx].remove(node);
    self.allocator.destroy(node);
}

// export fn dispatchWindowCloseEvent() callconv(.c) c_int {}
