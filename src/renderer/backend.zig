const Backend = @import("root.zig").Backend;

pub fn VTable(comptime Impl: type) type {
    return struct {
        pub const backend = Backend{
            .init = wrapFallible("init"),
            .deinit = wrapVoid("deinit"),
            .beginFrame = wrapFallible("beginFrame"),
            .endFrame = wrapFallible("endFrame"),
        };

        fn wrapFallible(comptime name: []const u8) fn (*anyopaque) anyerror!void {
            return struct {
                fn call(ctx: *anyopaque) anyerror!void {
                    const self: *Impl = @ptrCast(@alignCast(ctx));
                    try @call(.auto, @field(Impl, name), .{self});
                }
            }.call;
        }

        fn wrapVoid(comptime name: []const u8) fn (*anyopaque) void {
            return struct {
                fn call(ctx: *anyopaque) void {
                    const self: *Impl = @ptrCast(@alignCast(ctx));
                    @call(.auto, @field(Impl, name), .{self});
                }
            }.call;
        }
    };
}
