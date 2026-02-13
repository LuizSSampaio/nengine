const std = @import("std");

extern fn run() callconv(.c) void;

pub fn main() !void {
    run();
}
