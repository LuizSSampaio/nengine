const std = @import("std");

const opengl = @import("opengl");

const backend_vtable = @import("backend.zig");

pub const BackendKind = enum {
    opengl,
};

pub const Backend = struct {
    init: *const fn (*anyopaque) anyerror!void,
    deinit: *const fn (*anyopaque) void,
    beginFrame: *const fn (*anyopaque) anyerror!void,
    endFrame: *const fn (*anyopaque) anyerror!void,
};

pub const Renderer = struct {
    ctx: *anyopaque,
    backend: *const Backend,
    allocator: std.mem.Allocator,

    pub fn create(allocator: std.mem.Allocator, kind: BackendKind) !Renderer {
        return switch (kind) {
            .opengl => {
                const ctx = try allocator.create(opengl.OpenGLRenderer);
                ctx.* = .{};
                return .{
                    .ctx = ctx,
                    .backend = &backend_vtable.VTable(opengl.OpenGLRenderer).backend,
                    .allocator = allocator,
                };
            },
        };
    }

    pub fn destroy(self: *Renderer) void {
        self.backend.deinit(self.ctx);
        const typed_ctx: *opengl.OpenGLRenderer = @ptrCast(@alignCast(self.ctx));
        self.allocator.destroy(typed_ctx);
    }

    pub fn init(self: *Renderer) anyerror!void {
        try self.backend.init(self.ctx);
    }

    pub fn deinit(self: *Renderer) void {
        self.backend.deinit(self.ctx);
    }

    pub fn beginFrame(self: *Renderer) anyerror!void {
        try self.backend.beginFrame(self.ctx);
    }

    pub fn endFrame(self: *Renderer) anyerror!void {
        try self.backend.endFrame(self.ctx);
    }
};
