const std = @import("std");
const b64 = std.base64.url_safe_no_pad.Encoder;

const Buffer = @import("buffer.zig").Buffer;
const logger = @import("root.zig");
const Pool = @import("pool.zig").Pool;

const META_LEN = "{\"@l\":\"ERROR\",".len;

pub const Format = struct {
    out: *std.Io.Writer,
    lvl: logger.Level,
    meta: []u8,
    buffer: Buffer,
    multiuse_length: ?usize,
    mutex: *std.Thread.Mutex,
    interface: std.Io.Writer,

    pub fn init(allocator: std.mem.Allocator, pool: *Pool) !@This() {
        var buffer = try pool.buffer_pool.create();
        errdefer buffer.deinit();

        const meta = try allocator.alloc(u8, META_LEN);
        errdefer allocator.free(meta);

        return .{
            .out = &pool.file_writer.interface,
            .lvl = .None,
            .meta = meta,
            .buffer = buffer,
            .multiuse_length = null,
            .mutex = &pool.log_mutex,
            .interface = .{
                .buffer = &.{},
                .vtable = &.{ .drain = @This().drain },
            },
        };
    }

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        allocator.free(self.meta);
        self.buffer.deinit();
    }

    fn drain(io_w: *std.Io.Writer, data: []const []const u8, splat: usize) !usize {
        _ = splat;
        const self: *@This() = @fieldParentPtr("interface", io_w);
        self.buffer.writeAll(data[0]) catch return error.WriteFailed;
        return data[0].len;
    }

    pub fn multiuse(self: *@This()) void {
        self.multiuse_length = self.buffer.pos;
    }

    pub fn reset(self: *@This()) void {
        self.lvl = .None;
        self.multiuse_length = null;
        self.buffer.reset(0);
    }

    pub fn reuse(self: *@This()) void {
        self.lvl = .None;
        self.buffer.reset(self.multiuse_length orelse 0);
    }

    pub fn level(self: *@This(), lvl: logger.Level) void {
        self.lvl = lvl;
    }

    pub fn ctx(self: *@This(), value: []const u8) void {
        self.string("@ctx", value);
    }

    pub fn src(self: *@This(), value: std.builtin.SourceLocation) void {
        self.writeObject("@src", .{ .file = value.file, .@"fn" = value.fn_name, .line = value.line });
    }

    pub fn string(self: *@This(), key: []const u8, nvalue: ?[]const u8) void {
        const value = nvalue orelse {
            self.writeNull(key);
            return;
        };

        const rewind = self.startKeyValue(key, value.len) orelse return;

        std.json.Stringify.encodeJsonString(value, .{}, &self.interface) catch {
            self.buffer.rollback(rewind);
            return;
        };
        self.buffer.writeByte(',') catch self.buffer.rollback(rewind);
    }

    pub fn fmt(self: *@This(), key: []const u8, comptime format: []const u8, values: anytype) void {
        const rewind = self.startKeyValue(key, 2) orelse return;

        var buffer = &self.buffer;

        buffer.writeByte('"') catch {
            buffer.rollback(rewind);
            return;
        };

        var writter = FmtWriter.init(self);
        writter.interface.print(format, values) catch {
            buffer.rollback(rewind);
            return;
        };

        buffer.writeAll("\",") catch {
            buffer.rollback(rewind);
            return;
        };
    }

    pub fn int(self: *@This(), key: []const u8, value: anytype) void {
        const f = switch (@typeInfo(@TypeOf(value))) {
            .optional => blk: {
                if (value) |v| {
                    break :blk v;
                }
                self.writeNull(key);
                return;
            },
            .null => {
                self.writeNull(key);
                return;
            },
            else => value,
        };

        const rewind = self.startKeyValue(key, 0) orelse return;
        self.interface.print("{d}", .{f}) catch {
            self.buffer.rollback(rewind);
            return;
        };
        self.buffer.writeByte(',') catch self.buffer.rollback(rewind);
    }

    pub fn float(self: *@This(), key: []const u8, value: anytype) void {
        const f = switch (@typeInfo(@TypeOf(value))) {
            .optional => blk: {
                if (value) |v| {
                    break :blk v;
                }
                self.writeNull(key);
                return;
            },
            .null => {
                self.writeNull(key);
                return;
            },
            else => value,
        };

        const rewind = self.startKeyValue(key, 0) orelse return;
        self.interface.print("{d}", .{f}) catch {
            self.buffer.rollback(rewind);
            return;
        };
        self.buffer.writeByte(',') catch self.buffer.rollback(rewind);
    }

    pub fn boolean(self: *@This(), key: []const u8, value: anytype) void {
        const b = switch (@typeInfo(@TypeOf(value))) {
            .optional => blk: {
                if (value) |v| {
                    break :blk v;
                }
                self.writeNull(key);
                return;
            },
            .null => {
                self.writeNull(key);
                return;
            },
            else => value,
        };

        const l: usize = if (b) 4 else 5;
        var aw = self.buffer.attributeWriter(4 + key.len + l, true) orelse return;
        aw.writeByte('"');
        if (b) {
            aw.writeAllAll(key, "\":true,");
        } else {
            aw.writeAllAll(key, "\":false,");
        }
        aw.done();
    }

    pub fn binary(self: *@This(), key: []const u8, nvalue: ?[]const u8) void {
        const value = nvalue orelse {
            self.writeNull(key);
            return;
        };

        var aw = self.buffer.attributeWriter(6 + key.len + b64.calcSize(value.len), true) orelse return;
        aw.writeByte('"');
        aw.writeAllAll(key, "\":\"");

        var pos: usize = 0;
        var end: usize = 12;
        var scratch: [16]u8 = undefined;
        while (end < value.len) {
            _ = b64.encode(&scratch, value[pos..end]);
            pos = end;
            end += 12;
            aw.writeAll(&scratch);
        }

        if (pos < value.len) {
            const leftover = b64.encode(&scratch, value[pos..]);
            aw.writeAll(leftover);
        }
        aw.writeAll("\",");
        aw.done();
    }

    pub fn any(self: *@This(), key: []const u8, val: anytype) void {
        const T = @TypeOf(val);

        switch (@typeInfo(T)) {
            .optional => if (val) |v| {
                self.any(key, v);
            } else {
                self.writeNull(key);
            },
            .null => self.writeNull(key),
            else => {
                const rewind = self.startKeyValue(key, 0) orelse return;
                self.writeValueOnly(val) catch {
                    self.buffer.rollback(rewind);
                    return;
                };
                self.buffer.writeByte(',') catch self.buffer.rollback(rewind);
            },
        }
    }

    pub fn slice(self: *@This(), key: []const u8, values: anytype) void {
        const rewind = self.startKeyValue(key, 0) orelse return;
        self.buffer.writeByte('[') catch {
            self.buffer.rollback(rewind);
            return;
        };

        if (values.len > 0) {
            self.writeValueOnly(values[0]) catch {
                return self.buffer.rollback(rewind);
            };
        }

        if (values.len > 1) {
            for (values[1..]) |elem| {
                self.buffer.writeByte(',') catch {
                    return self.buffer.rollback(rewind);
                };
                self.writeValueOnly(elem) catch {
                    return self.buffer.rollback(rewind);
                };
            }
        }
        self.buffer.writeAll("],") catch self.buffer.rollback(rewind);
    }

    pub fn sliceFmt(self: *@This(), key: []const u8, values: anytype, formatter: logger.SliceItemFormatCallback(@TypeOf(values))) void {
        _ = formatter;
        self.slice(key, values);
    }

    fn writeValueOnly(self: *@This(), val: anytype) !void {
        const T = @TypeOf(val);

        switch (@typeInfo(T)) {
            .int, .comptime_int => try self.interface.print("{d}", .{val}),
            .float, .comptime_float => try self.interface.print("{d}", .{val}),
            .bool => if (val) {
                try self.interface.writeAll("true");
            } else {
                try self.interface.writeAll("false");
            },
            .pointer => |ptr| {
                if (ptr.size == .many and ptr.child == u8) {
                    try self.interface.writeByte('"');
                    try std.json.Stringify.encodeJsonStringChars(val, .{}, &self.interface);
                    try self.interface.writeByte('"');
                } else if (ptr.size == .one and @typeInfo(ptr.child) == .array) {
                    if (@typeInfo(ptr.child).array.child == u8) {
                        try self.interface.writeByte('"');
                        try std.json.Stringify.encodeJsonStringChars(val, .{}, &self.interface);
                        try self.interface.writeByte('"');
                    } else {
                        try std.json.Stringify.value(val, .{}, &self.interface);
                    }
                } else if (ptr.size == .one and @typeInfo(ptr.child) == .@"struct") {
                    try std.json.Stringify.value(val, .{}, &self.interface);
                } else {
                    try std.json.Stringify.value(val, .{}, &self.interface);
                }
            },
            .array => |arr| if (arr.child == u8) {
                try self.interface.writeByte('"');
                try std.json.Stringify.encodeJsonStringChars(&val, .{}, &self.interface);
                try self.interface.writeByte('"');
            } else {
                try std.json.Stringify.value(val, .{}, &self.interface);
            },
            .@"enum" => {
                try self.interface.writeByte('"');
                try self.interface.writeAll(@tagName(val));
                try self.interface.writeByte('"');
            },
            .error_set => {
                try self.interface.writeByte('"');
                try self.interface.writeAll(@errorName(val));
                try self.interface.writeByte('"');
            },
            .@"struct" => try std.json.Stringify.value(val, .{}, &self.interface),
            .@"union" => try std.json.Stringify.value(val, .{}, &self.interface),
            .null => try self.interface.writeAll("null"),
            .optional => if (val) |v| {
                try self.writeValueOnly(v);
            } else {
                try self.interface.writeAll("null");
            },
            else => try std.json.Stringify.value(val, .{}, &self.interface),
        }
    }

    pub fn err(self: *@This(), value: anyerror) void {
        const T = @TypeOf(value);

        switch (@typeInfo(T)) {
            .optional => {
                if (value) |v| {
                    self.string("@err", @errorName(v));
                } else {
                    self.writeNull("@err");
                }
            },
            else => self.string("@err", @errorName(value)),
        }
    }

    pub fn errK(self: *@This(), key: []const u8, value: anyerror) void {
        const T = @TypeOf(value);

        switch (@typeInfo(T)) {
            .optional => {
                if (value) |v| {
                    self.string(key, @errorName(v));
                } else {
                    self.writeNull(key);
                }
            },
            else => self.string(key, @errorName(value)),
        }
    }

    pub fn tryLog(self: *@This()) !void {
        try self.logTo(self.out);
    }

    pub fn log(self: *@This()) void {
        self.logTo(self.out) catch |e| {
            const msg = "Failed to write log. Log will be dropped. Error was: {}";
            std.log.err(msg, .{e});
        };
    }

    pub fn logTo(self: *@This(), out: anytype) !void {
        const buffer = &self.buffer;
        var pos = buffer.pos;

        if (pos == 0) {
            return;
        }

        const meta = self.meta;
        const meta_len = blk: {
            const prefix_len = meta.len - META_LEN;
            const meta_buf = meta[prefix_len..];

            switch (self.lvl) {
                .Debug => {
                    @memcpy(meta_buf[0..META_LEN], "{\"@l\":\"DEBUG\",");
                    break :blk meta.len;
                },
                .Info => {
                    @memcpy(meta_buf[0 .. META_LEN - 1], "{\"@l\":\"INFO\",");
                    break :blk meta.len - 1;
                },
                .Warn => {
                    @memcpy(meta_buf[0 .. META_LEN - 1], "{\"@l\":\"WARN\",");
                    break :blk meta.len - 1;
                },
                .Error => {
                    @memcpy(meta_buf[0..META_LEN], "{\"@l\":\"ERROR\",");
                    break :blk meta.len;
                },
                .Fatal => {
                    @memcpy(meta_buf[0..META_LEN], "{\"@l\":\"FATAL\",");
                    break :blk meta.len;
                },
                else => {
                    meta_buf[0] = '{';
                    break :blk prefix_len + 1;
                },
            }
        };

        var buf = buffer.buf;
        buf[pos - 1] = '}';

        const static = buffer.static;

        var flush_newline = false;
        if (pos < buf.len) {
            buf[pos] = '\n';
            pos += 1;
        } else {
            flush_newline = true;
        }

        self.mutex.lock();
        defer self.mutex.unlock();

        try out.writeAll(meta[0..meta_len]);
        if (buf.ptr != static.ptr) {
            try out.writeAll(static);
        }

        try out.writeAll(buf[0..pos]);
        if (flush_newline) {
            try out.writeAll("\n");
        }
    }

    fn startKeyValue(self: *@This(), key: []const u8, min_value_len: usize) ?Buffer.RewindState {
        var buffer = &self.buffer;
        const rewind = buffer.begin();
        switch (buffer.sizeCheck(key.len + 4 + min_value_len)) {
            .none => return null,
            .buf => {
                buffer.writeByteBuf('"');
                buffer.writeAllBuf(key);
                buffer.writeAllBuf("\":");
            },
            .acquire_large => {
                buffer.writeByte('"') catch return null;
                buffer.writeAll(key) catch {
                    buffer.rollback(rewind);
                    return null;
                };
                buffer.writeAll("\":") catch {
                    buffer.rollback(rewind);
                    return null;
                };
            },
        }

        return rewind;
    }

    fn writeNull(self: *@This(), key: []const u8) void {
        var aw = self.buffer.attributeWriter(8 + key.len, true) orelse return;
        aw.writeByte('"');
        aw.writeAllAll(key, "\":null,");
        aw.done();
    }

    fn writeObject(self: *@This(), key: []const u8, value: anytype) void {
        const rewind = self.startKeyValue(key, 2) orelse return;
        var buffer = &self.buffer;
        std.json.Stringify.value(value, .{}, &self.interface) catch {
            buffer.rollback(rewind);
            return;
        };
        buffer.writeByte(',') catch buffer.rollback(rewind);
    }

    pub const FmtWriter = struct {
        json: *@This(),
        interface: std.Io.Writer,

        fn init(json: *@This()) FmtWriter {
            return .{
                .json = json,
                .interface = .{
                    .buffer = &.{},
                    .vtable = &.{ .drain = FmtWriter.drain },
                },
            };
        }

        fn drain(io_w: *std.Io.Writer, data: []const []const u8, splat: usize) !usize {
            _ = splat;
            const self: *@This() = @fieldParentPtr("interface", io_w);
            std.json.Stringify.encodeJsonStringChars(data[0], .{}, &self.json.interface) catch return error.WriteFailed;
            return data[0].len;
        }
    };
};
