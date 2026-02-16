const std = @import("std");

const Format = @import("format.zig").Format;
const Pool = @import("pool.zig").Pool;
const Config = @import("config.zig").Config;

var initialized = false;
var global: *Pool = undefined;

export fn logger_init(config: Config) callconv(.c) c_int {
    if (initialized) {
        global.deinit();
    }
    global = Pool.init(std.heap.c_allocator, config) catch {
        return -1;
    };
    initialized = true;
    return 0;
}

export fn logger_deinit() callconv(.c) void {
    if (initialized) {
        global.deinit();
        initialized = false;
    }
}

pub const Level = enum(u8) {
    Debug,
    Info,
    Warn,
    Error,
    Fatal,
    None,
};

pub const Logger = extern struct {
    pool: *Pool,
    noop: bool,
    format: *Format,

    pub fn multiuse(self: @This()) @This() {
        switch (self.noop) {
            true => {},
            inline else => self.format.multiuse(),
        }
        return self;
    }

    pub fn ctx(self: @This(), value: []const u8) @This() {
        switch (self.noop) {
            true => {},
            inline else => self.format.ctx(value),
        }
        return self;
    }

    pub fn src(self: @This(), value: std.builtin.SourceLocation) @This() {
        switch (self.noop) {
            true => {},
            inline else => self.format.src(value),
        }
        return self;
    }

    pub fn fmt(self: @This(), key: []const u8, comptime format: []const u8, values: anytype) @This() {
        switch (self.noop) {
            true => {},
            inline else => self.format.fmt(key, format, values),
        }
        return self;
    }

    pub fn string(self: @This(), key: []const u8, value: ?[]const u8) @This() {
        switch (self.noop) {
            true => {},
            inline else => self.format.string(key, value),
        }
        return self;
    }

    pub fn binary(self: @This(), key: []const u8, value: ?[]const u8) @This() {
        switch (self.noop) {
            true => {},
            inline else => self.format.binary(key, value),
        }
        return self;
    }

    pub fn any(self: @This(), key: []const u8, val: anytype) @This() {
        switch (self.noop) {
            true => {},
            inline else => self.format.any(key, val),
        }
        return self;
    }

    pub fn slice(self: @This(), key: []const u8, values: anytype) @This() {
        switch (self.noop) {
            true => {},
            inline else => self.format.slice(key, values),
        }
        return self;
    }

    pub fn sliceFmt(self: @This(), key: []const u8, values: anytype, formatter: SliceItemFormatCallback(@TypeOf(values))) @This() {
        switch (self.noop) {
            true => {},
            inline else => self.format.sliceFmt(key, values, formatter),
        }
        return self;
    }

    pub fn int(self: @This(), key: []const u8, value: anytype) @This() {
        switch (self.noop) {
            true => {},
            inline else => self.format.int(key, value),
        }
        return self;
    }

    pub fn float(self: @This(), key: []const u8, value: anytype) @This() {
        switch (self.noop) {
            true => {},
            inline else => self.format.float(key, value),
        }
        return self;
    }

    pub fn boolean(self: @This(), key: []const u8, value: anytype) @This() {
        switch (self.noop) {
            true => {},
            inline else => self.format.boolean(key, value),
        }
        return self;
    }

    pub fn errK(self: @This(), key: []const u8, value: anyerror) @This() {
        switch (self.noop) {
            true => {},
            inline else => self.format.errK(key, value),
        }
        return self;
    }

    pub fn err(self: @This(), value: anyerror) @This() {
        switch (self.noop) {
            true => {},
            inline else => self.format.err(value),
        }
        return self;
    }

    pub fn level(self: @This(), lvl: Level) @This() {
        switch (self.noop) {
            true => {},
            inline else => self.format.level(lvl),
        }
        return self;
    }

    pub fn tryLog(self: @This()) !void {
        switch (self.noop) {
            true => {},
            inline else => {
                defer self.maybeRelease(self.format);
                if (self.pool.shouldLog(self.format.lvl)) try self.format.tryLog();
            },
        }
    }

    pub fn log(self: @This()) void {
        switch (self.noop) {
            true => {},
            inline else => {
                if (self.pool.shouldLog(self.format.lvl)) self.format.log();
                self.maybeRelease(self.format);
            },
        }
    }

    pub fn logTo(self: @This(), out: anytype) !void {
        switch (self.noop) {
            true => {},
            inline else => {
                defer self.maybeRelease(self.format);
                if (self.pool.shouldLog(self.format.lvl)) try self.format.logTo(out);
            },
        }
    }

    pub fn release(self: @This()) void {
        switch (self.noop) {
            true => {},
            inline else => self.pool.release(self),
        }
    }

    pub fn deinit(self: @This()) void {
        switch (self.noop) {
            true => {},
            inline else => self.pool.destroyLogger(self),
        }
    }

    pub fn done(_: @This()) void {
        return;
    }

    fn maybeRelease(self: @This(), l: anytype) void {
        if (l.multiuse_length == null) {
            self.pool.release(self);
        } else {
            l.reuse();
        }
    }

    pub fn reset(self: @This()) void {
        switch (self.noop) {
            true => {},
            inline else => self.format.reset(),
        }
    }
};

export fn log_multiuse(self: Logger) callconv(.c) Logger {
    return self.multiuse();
}

export fn log_ctx(self: Logger, value: [*:0]const u8) callconv(.c) Logger {
    return self.ctx(std.mem.span(value));
}

export fn log_string(self: Logger, key: [*:0]const u8, value: ?[*:0]const u8) callconv(.c) Logger {
    return self.string(std.mem.span(key), if (value) |v| std.mem.span(v) else null);
}

export fn log_int(self: Logger, key: [*:0]const u8, value: i64) callconv(.c) Logger {
    return self.int(std.mem.span(key), value);
}

export fn log_float(self: Logger, key: [*:0]const u8, value: f64) callconv(.c) Logger {
    return self.float(std.mem.span(key), value);
}

export fn log_boolean(self: Logger, key: [*:0]const u8, value: bool) callconv(.c) Logger {
    return self.boolean(std.mem.span(key), value);
}

export fn log_level(self: Logger, lvl: Level) callconv(.c) Logger {
    return self.level(lvl);
}

export fn log_log(self: Logger) callconv(.c) void {
    self.log();
}

export fn log_release(self: Logger) callconv(.c) void {
    self.release();
}

export fn log_deinit(self: Logger) callconv(.c) void {
    self.deinit();
}

export fn log_reset(self: Logger) callconv(.c) void {
    self.reset();
}

pub export fn debug() callconv(.c) Logger {
    return global.debug();
}

pub export fn info() callconv(.c) Logger {
    return global.info();
}

pub export fn warn() callconv(.c) Logger {
    return global.warn();
}

pub export fn err() callconv(.c) Logger {
    return global.err();
}

pub export fn fatal() callconv(.c) Logger {
    return global.fatal();
}

fn SliceItemFormatCallback(comptime T: type) type {
    const C = std.meta.Child(T);
    if (@typeInfo(C) == .@"struct") {
        return *const fn (*const std.meta.Child(T), *std.Io.Writer) error{WriteFailed}!void;
    }
    return *const fn (std.meta.Child(T), *std.Io.Writer) error{WriteFailed}!void;
}
