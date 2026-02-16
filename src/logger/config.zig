const logger = @import("root.zig");

pub const Config = struct {
    pool_size: usize = 32,
    buffer_size: usize = 4096,
    default_level: logger.Level = .Debug,
    large_buffer_count: u16 = 8,
    large_buffer_size: usize = 16384,
};
