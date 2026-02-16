const std = @import("std");

const Format = @import("format.zig").Format;
const Pool = @import("pool.zig").Pool;
const Config = @import("config.zig").Config;

var init = false;
var global: *Pool = undefined;

pub fn setup(allocator: std.mem.Allocator, config: Config) !void {
    if (init) {
        global.deinit();
    }
    global = try Pool.init(allocator, config);
    init = true;
}

pub fn deinit() void {
    if (init) {
        global.deinit();
        init = false;
    }
}

pub const Level = enum(u3) {
    Debug,
    Info,
    Warn,
    Error,
    Fatal,
    None,

    pub fn parse(input: []const u8) ?Level {
        if (input.len < 4 or input.len > 5) return null;
        var buf: [5]u8 = undefined;

        const lower = std.ascii.lowerString(&buf, input);
        if (std.mem.eql(u8, lower, "debug")) return .Debug;
        if (std.mem.eql(u8, lower, "info")) return .Info;
        if (std.mem.eql(u8, lower, "warn")) return .Warn;
        if (std.mem.eql(u8, lower, "error")) return .Error;
        if (std.mem.eql(u8, lower, "fatal")) return .Fatal;
        if (std.mem.eql(u8, lower, "none")) return .None;
        return null;
    }
};

pub const Logger = struct {
    pool: *Pool,
    inner: union(enum) {
        noop: void,
        format: *Format,
    },

    pub fn multiuse(self: @This()) @This() {
        switch (self.inner) {
            .noop => {},
            inline else => |l| l.multiuse(),
        }
        return self;
    }

    pub fn ctx(self: @This(), value: []const u8) @This() {
        switch (self.inner) {
            .noop => {},
            inline else => |l| l.ctx(value),
        }
        return self;
    }

    pub fn src(self: @This(), value: std.builtin.SourceLocation) @This() {
        switch (self.inner) {
            .noop => {},
            inline else => |l| l.src(value),
        }
        return self;
    }

    pub fn fmt(self: @This(), key: []const u8, comptime format: []const u8, values: anytype) @This() {
        switch (self.inner) {
            .noop => {},
            inline else => |l| l.fmt(key, format, values),
        }
        return self;
    }

    pub fn string(self: @This(), key: []const u8, value: ?[]const u8) @This() {
        switch (self.inner) {
            .noop => {},
            inline else => |l| l.string(key, value),
        }
        return self;
    }

    pub fn stringZ(self: @This(), key: []const u8, value: ?[*:0]const u8) @This() {
        switch (self.inner) {
            .noop => {},
            inline else => |l| l.stringZ(key, value),
        }
        return self;
    }

    pub fn stringSafe(self: @This(), key: []const u8, value: ?[]const u8) @This() {
        switch (self.inner) {
            .noop => {},
            inline else => |l| l.stringSafe(key, value),
        }
        return self;
    }

    pub fn stringSafeZ(self: @This(), key: []const u8, value: ?[*:0]const u8) @This() {
        switch (self.inner) {
            .noop => {},
            inline else => |l| l.stringSafeZ(key, value),
        }
        return self;
    }

    pub fn binary(self: @This(), key: []const u8, value: ?[]const u8) @This() {
        switch (self.inner) {
            .noop => {},
            inline else => |l| l.binary(key, value),
        }
        return self;
    }

    pub fn any(self: @This(), key: []const u8, val: anytype) @This() {
        switch (self.inner) {
            .noop => {},
            inline else => |l| l.any(key, val),
        }
        return self;
    }

    pub fn slice(self: @This(), key: []const u8, values: anytype) @This() {
        switch (self.inner) {
            .noop => {},
            inline else => |l| l.slice(key, values),
        }
        return self;
    }

    pub fn sliceFmt(self: @This(), key: []const u8, values: anytype, formatter: SliceItemFormatCallback(@TypeOf(values))) @This() {
        switch (self.inner) {
            .noop => {},
            inline else => |l| l.sliceFmt(key, values, formatter),
        }
        return self;
    }

    pub fn int(self: @This(), key: []const u8, value: anytype) @This() {
        switch (self.inner) {
            .noop => {},
            inline else => |l| l.int(key, value),
        }
        return self;
    }

    pub fn float(self: @This(), key: []const u8, value: anytype) @This() {
        switch (self.inner) {
            .noop => {},
            inline else => |l| l.float(key, value),
        }
        return self;
    }

    pub fn boolean(self: @This(), key: []const u8, value: anytype) @This() {
        switch (self.inner) {
            .noop => {},
            inline else => |l| l.boolean(key, value),
        }
        return self;
    }

    pub fn errK(self: @This(), key: []const u8, value: anyerror) @This() {
        switch (self.inner) {
            .noop => {},
            inline else => |l| l.errK(key, value),
        }
        return self;
    }

    pub fn err(self: @This(), value: anyerror) @This() {
        switch (self.inner) {
            .noop => {},
            inline else => |l| l.err(value),
        }
        return self;
    }

    pub fn level(self: @This(), lvl: Level) @This() {
        switch (self.inner) {
            .noop => {},
            inline else => |l| l.level(lvl),
        }
        return self;
    }

    pub fn tryLog(self: @This()) !void {
        switch (self.inner) {
            .noop => {},
            inline else => |l| {
                defer self.maybeRelease(l);
                if (self.pool.shouldLog(l.lvl)) try l.tryLog();
            },
        }
    }

    pub fn log(self: @This()) void {
        switch (self.inner) {
            .noop => {},
            inline else => |l| {
                if (self.pool.shouldLog(l.lvl)) l.log();
                self.maybeRelease(l);
            },
        }
    }

    pub fn logTo(self: @This(), out: anytype) !void {
        switch (self.inner) {
            .noop => {},
            inline else => |l| {
                defer self.maybeRelease(l);
                if (self.pool.shouldLog(l.lvl)) try l.logTo(out);
            },
        }
    }

    pub fn release(self: @This()) void {
        switch (self.inner) {
            .noop => {},
            inline else => self.pool.release(self),
        }
    }

    pub fn deinit(self: @This()) void {
        switch (self.inner) {
            .noop => {},
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
        switch (self.inner) {
            .noop => {},
            inline else => |l| l.reset(),
        }
    }
};

pub fn level() Level {
    return @enumFromInt(global.level);
}

pub fn newLogger() !Logger {
    return global.createLogger();
}

pub fn shouldLog(l: Level) bool {
    return global.shouldLog(l);
}

pub fn debug() Logger {
    return global.debug();
}

pub fn info() Logger {
    return global.info();
}

pub fn warn() Logger {
    return global.warn();
}

pub fn err() Logger {
    return global.err();
}

pub fn fatal() Logger {
    return global.fatal();
}

pub fn logger() Logger {
    return global.logger();
}

pub fn loggerL(lvl: Level) Logger {
    return global.loggerL(lvl);
}

pub fn SliceItemFormatCallback(comptime T: type) type {
    const C = std.meta.Child(T);
    if (@typeInfo(C) == .@"struct") {
        return *const fn (*const std.meta.Child(T), *std.Io.Writer) error{WriteFailed}!void;
    }
    return *const fn (std.meta.Child(T), *std.Io.Writer) error{WriteFailed}!void;
}
