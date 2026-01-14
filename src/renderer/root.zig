const opengl = @import("opengl");

pub const BackendKind = enum { opengl };

pub const Renderer = struct {
    ctx: *anyopaque,
    backend: *const Backend,

    const Backend = struct {
        init: fn (*anyopaque) anyerror!void,
        deinit: fn (*anyopaque) void,
        beginFrame: fn (*anyopaque) anyerror!void,
        endFrame: fn (*anyopaque) anyerror!void,
    };

    pub fn create(backend: BackendKind) Renderer {
        return switch (backend) {
            .opengl => createOpenGLRenderer(),
        };
    }

    fn createOpenGLRenderer() Renderer {
        const gl = opengl.OpenGLRenderer{};
        const backend = Backend{
            .init = struct {
                fn call(ctx: *anyopaque) anyerror!void {
                    const self = @as(*opengl.OpenGLRenderer, @ptrCast(@alignCast(ctx)));
                    try self.init();
                }
            }.call,
            .deinit = struct {
                fn call(ctx: *anyopaque) void {
                    const self = @as(*opengl.OpenGLRenderer, @ptrCast(@alignCast(ctx)));
                    self.deinit();
                }
            }.call,
            .beginFrame = struct {
                fn call(ctx: *anyopaque) anyerror!void {
                    const self = @as(*opengl.OpenGLRenderer, @ptrCast(@alignCast(ctx)));
                    try self.beginFrame();
                }
            }.call,
            .endFrame = struct {
                fn call(ctx: *anyopaque) anyerror!void {
                    const self = @as(*opengl.OpenGLRenderer, @ptrCast(@alignCast(ctx)));
                    try self.endFrame();
                }
            }.call,
        };

        return .{
            .ctx = gl,
            .backend = backend,
        };
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
