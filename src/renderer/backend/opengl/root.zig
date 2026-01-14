pub const OpenGLRenderer = struct {
    pub fn init(_: *OpenGLRenderer) !void {}

    pub fn deinit(_: *OpenGLRenderer) void {}

    pub fn beginFrame(_: *OpenGLRenderer) !void {}

    pub fn endFrame(_: *OpenGLRenderer) !void {}
};
