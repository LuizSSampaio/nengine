const std = @import("std");

const event_mod = @import("event.zig");
pub const Event = event_mod.Event;
pub const WindowEvent = event_mod.WindowEvent;
pub const KeyEvent = event_mod.KeyEvent;
pub const MouseEvent = event_mod.MouseEvent;

pub var manager: ?EventManager = null;
pub const EventManager = struct {
    pool_mutex: std.Thread.Mutex,

    pool: std.ArrayList(Event),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, buffer_size: usize) !void {
        const pool: std.ArrayList(Event) = .empty;
        errdefer pool.deinit(allocator);

        try pool.ensureTotalCapacity(allocator, buffer_size);

        manager = .{
            .pool_mutex = .{},
            .pool = pool,
            .allocator = allocator,
        };
    }

    pub fn deinit() !void {
        if (manager == null) {
            return error.NullManager;
        }

        const self = manager.?;
        self.pool.deinit(self.allocator);
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

// export fn dispatchWindowCloseEvent() callconv(.c) c_int {}
