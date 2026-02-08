const std = @import("std");

var initialized = false;

pub fn init(allocator: std.mem.Allocator) !void {
    if (initialized) {
        return error.alreadyInitialized;
    }
    _ = allocator;
}
pub fn deinit() void {}

pub const Logger = struct {
    pub fn init() Logger {}
    pub fn deinit() void {}
};

pub fn debug() Logger {}
pub fn info() Logger {}
pub fn warn() Logger {}
pub fn err() Logger {}
pub fn fatal() Logger {}
