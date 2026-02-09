const std = @import("std");

const pool = @import("pool.zig");

var initialized = false;

pub fn init(allocator: std.mem.Allocator) !void {
    if (initialized) {
        return error.alreadyInitialized;
    }
    _ = allocator;
}
pub fn deinit() void {}

pub const Level = enum {
    Debug,
    Info,
    Warn,
    Error,
    Fatal,
};

pub const Logger = struct {
    pool: *pool.Pool,

    pub fn init() Logger {}
    pub fn deinit() void {}
};

pub fn debug() Logger {}
pub fn info() Logger {}
pub fn warn() Logger {}
pub fn err() Logger {}
pub fn fatal() Logger {}
