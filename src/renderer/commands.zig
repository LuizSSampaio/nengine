pub const RendererCommand = union(enum) {
    clear: ClearCommand,
};

pub const ClearCommand = struct {
    color: ?[4]f32 = null,
    depth: ?f32 = null,
    stencil: ?u32 = null,
};
