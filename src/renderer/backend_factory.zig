const std = @import("std");

const opengl = @import("opengl");
const backend_vtable = @import("backend.zig");
const Backend = @import("root.zig").Backend;
const BackendKind = @import("root.zig").BackendKind;

pub const BackendContext = struct {
    ctx: *anyopaque,
    vtable: *const Backend,
};

pub fn create(kind: BackendKind, allocator: std.mem.Allocator) !BackendContext {
    return switch (kind) {
        .opengl => try createOpenGL(allocator),
    };
}

fn createOpenGL(allocator: std.mem.Allocator) !BackendContext {
    const ctx = try allocator.create(opengl.OpenGLRenderer);
    ctx.* = .{};

    return .{
        .ctx = @ptrCast(ctx),
        .vtable = &backend_vtable.VTable(opengl.OpenGLRenderer).backend,
    };
}
