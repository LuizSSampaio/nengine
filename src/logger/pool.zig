const std = @import("std");

const Logger = @import("root.zig").Logger;
const Config = @import("config.zig").Config;

pub const Pool = struct {
    log_mutex: std.Thread.Mutex,
    pool_mutex: std.Thread.Mutex,

    avaible: usize,
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

        var initialized: usize = 0;
        errdefer {
            for (0..initialized) |i| {
                pool.destroyLogger(loggers[i]);
            }
        }

        for (0..config.pool_size) |i| {
            loggers[i] = try pool.createLogger();
            initialized += 1;
        }

        return pool;
    }

    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.loggers);
        self.allocator.destroy(self);
    }

    pub fn acquire(self: *@This()) Logger {
        self.pool_mutex.lock();

        if (self.avaible == 0) {
            self.pool_mutex.unlock();

            return self.createLogger();
        }

        const index = self.avaible - 1;
        const l = self.loggers[index];
        self.avaible = index;

        self.pool_mutex.unlock();
        return l;
    }

    pub fn release(self: *@This(), l: Logger) void {
        self.pool_mutex.lock();

        if (self.avaible == self.loggers.len) {
            self.pool_mutex.unlock();
            self.destroyLogger(l);
            return;
        }

        self.loggers[self.avaible] = l;
        self.avaible += 1;
        self.pool_mutex.unlock();
    }

    pub fn createLogger(self: *@This()) Logger {
        return .{ .pool = self };
    }

    pub fn destroyLogger(self: *@This(), l: Logger) void {
        _ = self;
        _ = l;
    }
};
