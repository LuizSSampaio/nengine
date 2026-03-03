const std = @import("std");
const Event = @import("event.zig").Event;

pub const ListType = std.SinglyLinkedList;
pub const ListNodeType = std.SinglyLinkedList.Node;

pub const Context = *anyopaque;
pub const Callback = *const fn (context: Context, event: *const Event) void;
pub const EventCount = blk: {
    if (@typeInfo(Event) != .@"union") {
        @compileError("Event must be an union");
    }
    break :blk std.meta.fields(Event).len;
};

pub const Node = struct {
    context: Context,
    callback: Callback,
    event: std.meta.Tag(Event),
    node: ListNodeType = .{},
};
