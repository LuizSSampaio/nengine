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
