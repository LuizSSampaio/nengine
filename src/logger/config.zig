const logger = @import("root.zig");

pub const Config = extern struct {
    pool_size: usize = 32,
    buffer_size: usize = 4096,
    minimum_level: logger.Level = .Info,
    large_buffer_count: u16 = 8,
    large_buffer_size: usize = 16384,
    output: []const u8,
};
