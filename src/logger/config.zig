const logger = @import("root.zig");

pub const Config = struct {
    pool_size: usize = 32,
    default_level: logger.Level = .Debug,
};
