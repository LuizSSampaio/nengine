pub const Renderer = struct {
    ctx: *anyopaque,
    backend: *const Backend,

    const Backend = struct {
        init: fn (*anyopaque) anyerror!void,
        deinit: fn (*anyopaque) void,
        beginFrame: fn (*anyopaque) anyerror!void,
        endFrame: fn (*anyopaque) anyerror!void,
    };

    pub fn create() !Renderer {}

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
