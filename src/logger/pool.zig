const std = @import("std");

const Logger = @import("root.zig").Logger;
const Config = @import("config.zig").Config;

pub const Pool = struct {
    log_mutex: std.Thread.Mutex,
    pool_mutex: std.Thread.Mutex,

    loggers: []Logger,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, config: Config) !*Pool {
        const loggers = try allocator.alloc(Logger, config.pool_size);
        errdefer allocator.free(loggers);

        const pool = try allocator.create(Pool);
        errdefer allocator.destroy(pool);

        pool.* = .{
            .log_mutex = .{},
            .pool_mutex = .{},
            .loggers = loggers,
            .allocator = allocator,
        };

        return pool;
    }

    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.loggers);
        self.allocator.destroy(self);
    }
};
