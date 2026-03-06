pub const Event = union(enum) {
    window: WindowEvent,
    key: KeyEvent,
    mouse: MouseEvent,
    none,
};

pub const WindowEvent = union(enum) {
    close,
    resize: struct { width: i32, height: i32 },
    focus: bool,
    moved: struct { x: i32, y: i32 },
};

pub const KeyEvent = union(enum) {
    pressed: struct { keycode: i32, repeat: i32 },
    released: struct { keycode: i32 },
};

pub const MouseEvent = union(enum) {
    moved: struct { x: i32, y: i32 },
    scrolled: struct { xOffset: i32, yOffset: i32 },
};

extern "nengine" fn dispatchWindowCloseEvent(priority: u8) callconv(.c) c_int;
extern "nengine" fn dispatchWindowResizeEvent(width: i32, height: i32, priority: u8) callconv(.c) c_int;
extern "nengine" fn dispatchWindowFocusEvent(focused: bool, priority: u8) callconv(.c) c_int;
extern "nengine" fn dispatchWindowMovedEvent(x: i32, y: i32, priority: u8) callconv(.c) c_int;
extern "nengine" fn dispatchKeyPressedEvent(keycode: i32, repeat: i32, priority: u8) callconv(.c) c_int;
extern "nengine" fn dispatchKeyReleasedEvent(keycode: i32, priority: u8) callconv(.c) c_int;
extern "nengine" fn dispatchMouseMovedEvent(x: i32, y: i32, priority: u8) callconv(.c) c_int;
extern "nengine" fn dispatchMouseScrolledEvent(x_offset: i32, y_offset: i32, priority: u8) callconv(.c) c_int;

pub fn dispatch(event: Event, priority: u8) !void {
    switch (event) {
        .window => |w| switch (w) {
            .close => try dispatchErrorHandler(dispatchWindowCloseEvent(priority)),
            .resize => |r| try dispatchErrorHandler(dispatchWindowResizeEvent(r.width, r.height, priority)),
            .focus => |f| try dispatchErrorHandler(dispatchWindowFocusEvent(f, priority)),
            .moved => |m| try dispatchErrorHandler(dispatchWindowMovedEvent(m.x, m.y, priority)),
        },
        .key => |k| switch (k) {
            .pressed => |p| try dispatchErrorHandler(dispatchKeyPressedEvent(p.keycode, p.repeat, priority)),
            .released => |r| try dispatchErrorHandler(dispatchKeyReleasedEvent(r.keycode, priority)),
        },
        .mouse => |m| switch (m) {
            .moved => |mv| try dispatchErrorHandler(dispatchMouseMovedEvent(mv.x, mv.y, priority)),
            .scrolled => |s| try dispatchErrorHandler(dispatchMouseScrolledEvent(s.xOffset, s.yOffset, priority)),
        },
        .none => {},
    }
}

fn dispatchErrorHandler(code: c_int) !void {
    if (code == -1) {
        return error.NullManager;
    }
}
