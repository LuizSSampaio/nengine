const std = @import("std");

const AllocatorContext = @import("allocator_context.zig").AllocatorContext;
const backend_factory = @import("backend_factory.zig");
const commands = @import("commands.zig");

pub const BackendKind = enum {
    opengl,
};

pub const Backend = struct {
    init: *const fn (*anyopaque) anyerror!void,
    deinit: *const fn (*anyopaque) void,
    beginFrame: *const fn (*anyopaque) anyerror!void,
    endFrame: *const fn (*anyopaque) anyerror!void,

    clear: *const fn (*anyopaque, ?[4]f32, ?f32, ?u32) anyerror!void,
};

pub const Renderer = struct {
    ctx: *anyopaque,
    backend: *const Backend,
    allocator_ctx: AllocatorContext,

    pub fn create(kind: BackendKind) !Renderer {
        var allocator_ctx = try AllocatorContext.init();
        errdefer allocator_ctx.deinit();

        const backend_ctx = try backend_factory.create(kind, allocator_ctx.allocator());

        var renderer = Renderer{
            .ctx = backend_ctx.ctx,
            .backend = backend_ctx.vtable,
            .allocator_ctx = allocator_ctx,
        };

        try renderer.backend.init(renderer.ctx);

        return renderer;
    }

    pub fn destroy(self: *Renderer) void {
        self.backend.deinit(self.ctx);
        self.allocator_ctx.deinit();
    }

    pub fn beginFrame(self: *Renderer) anyerror!void {
        try self.backend.beginFrame(self.ctx);
    }

    pub fn endFrame(self: *Renderer) anyerror!void {
        try self.backend.endFrame(self.ctx);
        self.allocator_ctx.resetArena();
    }

    pub fn clear(self: *Renderer, cmd: commands.ClearCommand) anyerror!void {
        self.backend.clear(self.ctx, cmd.color, cmd.depth, cmd.stencil);
    }
};
