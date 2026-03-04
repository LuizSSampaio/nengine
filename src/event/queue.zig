const std = @import("std");

const event_mod = @import("event.zig");
const Event = event_mod.Event;

const EventWrap = struct {
    priority: u8,
    payload: Event,
};

fn cmp(context: void, a: EventWrap, b: EventWrap) std.math.Order {
    _ = context;
    return std.math.order(a.priority, b.priority);
}

const PriorityQueue = std.PriorityQueue(EventWrap, void, cmp);

pub const EventQueue = struct {
    mutex: std.Thread.Mutex,
    pq: PriorityQueue,

    pub fn init(allocator: std.mem.Allocator) @This() {
        return .{
            .mutex = .{},
            .pq = PriorityQueue.init(allocator, {}),
        };
    }

    pub fn deinit(self: *@This()) void {
        self.pq.deinit();
    }

    pub fn push(self: *@This(), event: Event, priority: u8) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        try self.pq.add(.{ .priority = priority, .payload = event });
    }

    pub fn pop(self: *@This()) ?Event {
        self.mutex.lock();
        defer self.mutex.unlock();
        const event = self.pq.removeOrNull();
        return if (event) |e| e.payload else null;
    }
};
