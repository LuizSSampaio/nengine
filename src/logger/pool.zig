const std = @import("std");

const BufferPool = @import("buffer.zig").Pool;
const Config = @import("config.zig").Config;
const Format = @import("format.zig").Format;
const log = @import("root.zig");
const Logger = log.Logger;

const noop = Logger{ .pool = undefined, .noop = true, .format = undefined };

pub const Pool = struct {
    config: Config,

    log_mutex: std.Thread.Mutex,
    pool_mutex: std.Thread.Mutex,

    avaible: usize,
    loggers: []Logger,
    allocator: std.mem.Allocator,
    buffer_pool: BufferPool,

    file: std.fs.File,

    pub fn init(allocator: std.mem.Allocator, config: Config) !*Pool {
        const loggers = try allocator.alloc(Logger, config.pool_size);
        errdefer allocator.free(loggers);

        var buffer_pool = try BufferPool.init(allocator, &config);
        errdefer buffer_pool.deinit();

        const pool = try allocator.create(Pool);
        errdefer allocator.destroy(pool);

        const file = blk: {
            var f = std.fs.cwd().openFile(config.output, .{ .mode = .read_write }) catch |e| switch (e) {
                error.FileNotFound => break :blk try std.fs.cwd().createFile(config.output, .{}),
                else => return e,
            };

            const stat = try f.stat();
            try f.seekTo(stat.size);
            break :blk f;
        };

        pool.* = .{
            .config = config,
            .log_mutex = .{},
            .pool_mutex = .{},
            .avaible = config.pool_size,
            .loggers = loggers,
            .allocator = allocator,
            .buffer_pool = buffer_pool,
            .file = file,
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
        for (self.loggers) |l| {
            self.allocator.free(l);
        }
        self.buffer_pool.deinit();
        self.allocator.free(self.loggers);

        const handle = self.file.handle;
        if (handle != std.fs.File.stderr().handle and handle != std.fs.File.stdout().handle) {
            self.file.close();
        }
        self.allocator.destroy(self);
    }

    pub fn acquire(self: *@This()) Logger {
        self.pool_mutex.lock();

        if (self.available == 0) {
            self.pool_mutex.unlock();

            const l = self.createLogger() catch |e| {
                logDynamicAllocationFailure(e);
                return noop;
            };
            return l;
        }
        const index = self.available - 1;
        const l = self.loggers[index];
        self.available = index;
        self.pool_mutex.unlock();
        return l;
    }

    pub fn release(self: *@This(), l: Logger) void {
        l.reset();
        self.pool_mutex.lock();

        if (self.available == self.loggers.len) {
            self.pool_mutex.unlock();
            self.destroyLogger(l);
            return;
        }
        self.loggers[self.available] = l;
        self.available += 1;
        self.pool_mutex.unlock();
    }

    pub fn debug(self: *@This()) Logger {
        return if (self.shouldLog(.Debug)) self.loggerWithLevel(.Debug) else noop;
    }

    pub fn info(self: *@This()) Logger {
        return if (self.shouldLog(.Info)) self.loggerWithLevel(.Info) else noop;
    }

    pub fn warn(self: *@This()) Logger {
        return if (self.shouldLog(.Warn)) self.loggerWithLevel(.Warn) else noop;
    }

    pub fn err(self: *@This()) Logger {
        return if (self.shouldLog(.Error)) self.loggerWithLevel(.Error) else noop;
    }

    pub fn fatal(self: *@This()) Logger {
        return if (self.shouldLog(.Fatal)) self.loggerWithLevel(.Fatal) else noop;
    }

    pub fn logger(self: *@This()) Logger {
        if (self.level == @intFromEnum(log.Level.None)) return noop;
        return self.acquire();
    }

    pub fn loggerL(self: *@This(), lvl: log.Level) Logger {
        var l = self.acquire();
        _ = l.level(lvl);
        return l;
    }

    pub fn shouldLog(self: *@This(), level: log.Level) bool {
        return @intFromEnum(level) >= self.config.level;
    }

    fn loggerWithLevel(self: *@This(), lvl: log.Level) Logger {
        var l = self.acquire();
        _ = l.level(lvl);
        return l;
    }

    pub fn createLogger(self: *@This()) !Logger {
        const fmt = try self.allocator.create(Format);
        errdefer self.allocator.destroy(fmt);

        fmt.* = try Format.init(self.allocator, self);
        return .{ .pool = self, .noop = false, .format = fmt };
    }

    pub fn destroyLogger(self: *@This(), l: Logger) void {
        if (l.noop) {
            unreachable;
        }
        l.format.deinit(self.allocator);
        self.allocator.destroy(l.format);
    }
};

fn logDynamicAllocationFailure(err: anyerror) void {
    const msg = "Logged pool is empty and we failed to dynamically allowcate a new loggger. Log will be dropped. Error was: {}";
    std.log.err(msg, .{err});
}
