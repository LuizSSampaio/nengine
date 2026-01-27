const std = @import("std");
const build_options = @import("build_options");
const Backend = switch (build_options.pipeline) {
    .opengl => @import("opengl").Backend,
};

pub const Renderer = struct {
    ctx: Backend,
    arena: std.heap.ArenaAllocator,

    pub fn init(allocator: std.mem.Allocator, loader: *const fn ([*:0]const u8) callconv(.c) ?*const anyopaque) !Renderer {
        return .{
            .ctx = try Backend.init(loader),
            .arena = std.heap.ArenaAllocator.init(allocator),
        };
    }

    pub fn deinit(self: *Renderer) void {
        self.ctx.deinit();
        self.arena.deinit();
    }

    pub fn beginFrame(self: *Renderer) anyerror!void {
        try self.ctx.beginFrame();
    }

    pub fn endFrame(self: *Renderer) anyerror!void {
        try self.ctx.endFrame();
        _ = self.arena.reset(.free_all);
    }

    pub fn clear(self: *Renderer, cmd: struct {
        color: ?[4]f32 = null,
        depth: ?f32 = null,
        stencil: ?u32 = null,
    }) anyerror!void {
        try self.ctx.clear(cmd.color, cmd.depth, cmd.stencil);
    }
};
