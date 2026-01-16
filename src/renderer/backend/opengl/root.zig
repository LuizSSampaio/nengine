const opengl = @import("opengl");
const gl = opengl.bindings;

pub const OpenGLRenderer = struct {
    pub fn init(_: *OpenGLRenderer) !void {}

    pub fn deinit(_: *OpenGLRenderer) void {}

    pub fn beginFrame(_: *OpenGLRenderer) !void {}

    pub fn endFrame(_: *OpenGLRenderer) !void {}

    pub fn clear(_: *OpenGLRenderer, color: ?[4]f32, depth: ?f32, stencil: ?u32) !void {
        var mask: gl.Bitfield = 0;

        if (color) |data| {
            gl.clearColor(data[0], data[1], data[2], data[3]);
            mask |= gl.COLOR_BUFFER_BIT;
        }
        if (depth) |data| {
            gl.clearDepth(data);
            mask |= gl.DEPTH_BUFFER_BIT;
        }
        if (stencil) |data| {
            gl.clearStencil(@intCast(data));
            mask |= gl.STENCIL_BUFFER_BIT;
        }

        gl.clear(mask);
    }
};
