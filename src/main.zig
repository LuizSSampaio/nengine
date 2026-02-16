const std = @import("std");

const Config = extern struct {
    pool_size: usize = 32,
    buffer_size: usize = 4096,
    minimum_level: u8 = 0,
    large_buffer_count: u16 = 8,
    large_buffer_size: usize = 16384,
};

extern "nengine" fn logger_init(config: Config) callconv(.c) c_int;
extern "nengine" fn logger_deinit() callconv(.c) void;
extern "nengine" fn run() callconv(.c) void;

pub fn main() !void {
    _ = logger_init(.{});
    defer logger_deinit();
    run();
}
