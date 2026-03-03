const std = @import("std");

const event_mod = @import("event.zig");
pub const Event = event_mod.Event;
pub const WindowEvent = event_mod.WindowEvent;
pub const KeyEvent = event_mod.KeyEvent;
pub const MouseEvent = event_mod.MouseEvent;

pub const EventContext = *anyopaque;
pub const EventCallback = *const fn (context: EventContext, event: *const Event) void;
pub const EventTypes = blk: {
    if (@typeInfo(Event) != .@"union") {
        @compileError("Event must be an union");
    }
    break :blk std.meta.fields(Event).len;
};

pub const HandlerNode = struct {
    context: EventContext,
    callback: EventCallback,
    event: std.meta.Tag(Event),
    node: std.SinglyLinkedList.Node = .{},
};

pub var manager: ?EventManager = null;
pub const EventManager = struct {
    pool_mutex: std.Thread.Mutex,

    pool: std.ArrayList(Event),
    handlers: [EventTypes]std.SinglyLinkedList,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, buffer_size: usize) !void {
        var pool: std.ArrayList(Event) = .empty;
        errdefer pool.deinit(allocator);

        var handlers: [EventTypes]std.SinglyLinkedList = undefined;
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

        var self = manager.?;

        self.pool.deinit(self.allocator);

        for (&self.handlers) |*list| {
            var handler = list.first;
            while (handler) |h| {
                const next = h.next;
                const node: *HandlerNode = @fieldParentPtr("node", h);
                self.allocator.destroy(node);
                handler = next;
            }
        }

        manager = null;
    }
};

pub fn dispatch(event: Event) !void {
    if (manager == null) {
        return error.NullManager;
    }

    var self = manager.?;
    self.pool_mutex.lock();
    defer self.pool_mutex.unlock();
    errdefer self.pool_mutex.unlock();

    try self.pool.append(self.allocator, event);
}

pub fn addHandler(event: std.meta.Tag(Event), context: EventContext, callback: EventCallback) !*HandlerNode {
    if (manager == null) {
        return error.NullManager;
    }

    var self = manager.?;
    const idx = @intFromEnum(event);

    const node = self.allocator.create(HandlerNode);
    node.* = .{
        .context = context,
        .callback = callback,
        .event = event,
        .node = .{},
    };

    self.handlers[idx].prepend(node);
    return node;
}

pub fn removeHandler(handler: *HandlerNode) !void {
    if (manager == null) {
        return error.NullManager;
    }

    var self = manager.?;
    const idx = @intFromEnum(handler.event);

    self.handlers[idx].remove(handler);
    self.allocator.destroy(handler);
}

// export fn dispatchWindowCloseEvent() callconv(.c) c_int {}
