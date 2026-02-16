pub const Level = enum(u8) { Debug, Info, Warn, Error, Fatal, None };

extern "nengine" fn log_multiuse(self: Logger) callconv(.c) Logger;
extern "nengine" fn log_ctx(self: Logger, value: [*:0]const u8) callconv(.c) Logger;
extern "nengine" fn log_string(self: Logger, key: [*:0]const u8, value: ?[*:0]const u8) callconv(.c) Logger;
extern "nengine" fn log_int(self: Logger, key: [*:0]const u8, value: i64) callconv(.c) Logger;
extern "nengine" fn log_float(self: Logger, key: [*:0]const u8, value: f64) callconv(.c) Logger;
extern "nengine" fn log_boolean(self: Logger, key: [*:0]const u8, value: bool) callconv(.c) Logger;
extern "nengine" fn log_level(self: Logger, lvl: Level) callconv(.c) Logger;
extern "nengine" fn log_log(self: Logger) callconv(.c) void;
extern "nengine" fn log_release(self: Logger) callconv(.c) void;
extern "nengine" fn log_deinit(self: Logger) callconv(.c) void;
extern "nengine" fn log_reset(self: Logger) callconv(.c) void;

pub const Logger = opaque {
    pub fn multiuse(self: @This()) @This() {
        return log_multiuse(self);
    }

    pub fn ctx(self: @This(), value: []const u8) @This() {
        return log_ctx(self, value);
    }

    pub fn string(self: @This(), key: []const u8, value: []const u8) @This() {
        log_string(self, key, value);
    }

    pub fn int(self: @This(), key: []const u8, value: i64) @This() {
        return log_int(self, key, value);
    }

    pub fn float(self: @This(), key: []const u8, value: f64) @This() {
        return log_float(self, key, value);
    }

    pub fn boolean(self: @This(), key: []const u8, value: bool) @This() {
        return log_boolean(self, key, value);
    }

    pub fn level(self: @This(), lvl: Level) @This() {
        return log_level(self, lvl);
    }

    pub fn log(self: @This()) void {
        return log_log(self);
    }

    pub fn release(self: @This()) void {
        return log_release(self);
    }

    pub fn deinit(self: @This()) void {
        return log_deinit(self);
    }

    pub fn reset(self: @This()) void {
        return log_reset(self);
    }
};

pub extern "nengine" fn debug() callconv(.c) Logger;
pub extern "nengine" fn info() callconv(.c) Logger;
pub extern "nengine" fn warn() callconv(.c) Logger;
pub extern "nengine" fn err() callconv(.c) Logger;
pub extern "nengine" fn faltal() callconv(.c) Logger;
