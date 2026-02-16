const std = @import("std");
const Config = @import("config.zig").Config;

pub const Buffer = struct {
    pos: usize,
    buf: []u8,
    static: []u8,
    pool: *Pool,
    rewind: ?RewindState = null,

    pub fn reset(self: *@This(), pos: usize) void {
        self.pos = pos;
        if (self.buf.ptr != self.static.ptr) {
            self.pool.releaseLarge(self.buf);
            self.buf = self.static;
        }
    }

    pub fn deinit(self: *@This()) void {
        if (self.buf.ptr != self.static.ptr) {
            self.pool.releaseLarge(self.buf);
        }
        self.pool.allocator.free(self.static);
    }

    pub fn writeAll(self: *@This(), data: []const u8) !void {
        switch (self.sizeCheck(data.len)) {
            .buf => self.writeAllBuf(data),
            .acquire_large => |available| {
                const larger = (self.pool.acquireLarge() catch return error.NoSpaceLeft) orelse return error.NoSpaceLeft;

                const pos = self.pos;
                const buf = self.buf;

                @memcpy(buf[pos..], data[0..available]);

                const end = data.len - available;
                @memcpy(larger[0..end], data[available..]);
                self.buf = larger;
                self.pos = end;
            },
            .none => return error.NoSpaceLeft,
        }
    }

    pub fn writeByte(self: *@This(), b: u8) !void {
        const pos = self.pos;
        const buf = self.buf;

        if (buf.len >= pos + 1) {
            buf[pos] = b;
            self.pos = pos + 1;
            return;
        }

        if (buf.ptr != self.static.ptr) {
            return error.NoSpaceLeft;
        }

        const large = (self.pool.acquireLarge() catch return error.NoSpaceLeft) orelse return error.NoSpaceLeft;
        large[0] = b;
        self.buf = large;
        self.pos = 1;
    }

    pub fn writeByteNTimes(self: *@This(), b: u8, n: usize) !void {
        const pos = self.pos;
        const buf = self.buf;

        switch (self.sizeCheck(n)) {
            .buf => {
                for (0..n) |i| {
                    buf[pos + i] = b;
                }
                self.pos = pos + n;
            },
            .acquire_large => |available| {
                const larger = (self.pool.acquireLarge() catch return error.NoSpaceLeft) orelse return error.NoSpaceLeft;

                for (0..available) |i| {
                    buf[pos + i] = b;
                }

                const remaining = n - available;
                for (0..remaining) |i| {
                    larger[i] = b;
                }
                self.buf = larger;
                self.pos = remaining;
            },
            .none => return error.NoSpaceLeft,
        }
    }

    pub fn writeBytesNTimes(self: *@This(), data: []const u8, n: usize) !void {
        if (self.sizeCheck(data.len * n) == .none) {
            return;
        }

        for (0..n) |_| {
            try self.writeAll(data);
        }
    }

    pub fn writeAllBuf(self: *@This(), data: []const u8) void {
        const pos = self.pos;
        const end = pos + data.len;
        @memcpy(self.buf[pos..end], data);
        self.pos = end;
    }

    pub fn writeByteBuf(self: *@This(), b: u8) void {
        const pos = self.pos;
        self.buf[pos] = b;
        self.pos = pos + 1;
    }

    pub fn attributeWriter(self: *@This(), len: usize, exact: bool) ?AttributeWriter {
        switch (self.sizeCheck(len)) {
            .none => return null,
            else => |other| return .{
                .buffer = self,
                ._rollback = false,
                .initial_pos = self.pos,
                .fits_in_buf = exact and other == .buf,
                .initial_static = self.buf.ptr == self.static.ptr,
            },
        }
    }

    const SizeCheckResult = union(enum) {
        buf: void,
        none: void,
        acquire_large: usize,
    };

    pub fn sizeCheck(self: *@This(), n: usize) SizeCheckResult {
        const available = self.buf.len - self.pos;
        if (available >= n) {
            return .{ .buf = {} };
        }

        if (self.buf.ptr == self.static.ptr and available + self.pool.large_buffer_size >= n) {
            return .{ .acquire_large = available };
        }
        return .{ .none = {} };
    }

    pub const RewindState = struct {
        pos: usize,
        static: bool,
    };

    pub fn begin(self: *Buffer) RewindState {
        return .{
            .pos = self.pos,
            .static = self.buf.ptr == self.static.ptr,
        };
    }

    pub fn rollback(self: *Buffer, rewind: RewindState) void {
        if (rewind.static) {
            if (self.buf.ptr != self.static.ptr) {
                self.pool.releaseLarge(self.buf);
                self.buf = self.static;
            }
        }
        self.pos = rewind.pos;
    }

    pub fn writer(self: *Buffer) Writer.IOWriter {
        return .{ .context = Writer.init(self) };
    }

    pub const Writer = struct {
        w: *Buffer,

        pub const Error = std.Allocator.Error;
        pub const IOWriter = std.io.Writer(Writer, error{OutOfMemory}, Writer.write);

        fn init(w: *Buffer) Writer {
            return .{ .w = w };
        }

        pub fn write(self: Writer, data: []const u8) std.Allocator.Error!usize {
            self.w.writeAll(data) catch return error.OutOfMemory;
            return data.len;
        }
    };
};

pub const AttributeWriter = struct {
    buffer: *Buffer,
    _rollback: bool,
    initial_pos: usize,
    initial_static: bool,
    fits_in_buf: bool,

    pub fn writeAll(self: *@This(), data: []const u8) void {
        const pos = self.buffer.pos;
        if (self.fits_in_buf) {
            const end = pos + data.len;
            @memcpy(self.buffer.buf[pos..end], data);
            self.buffer.pos = end;
            return;
        }

        self.buffer.writeAll(data) catch {
            self._rollback = true;
        };
    }

    pub fn writeAllB(self: *@This(), data: []const u8, suffix: u8) void {
        if (self.fits_in_buf) {
            const end = self.buffer.pos + data.len;
            @memcpy(self.buffer.buf[self.buffer.pos..end], data);
            self.buffer.buf[end] = suffix;
            self.buffer.pos = end + 1;
            return;
        }

        self.buffer.writeAll(data) catch {
            self._rollback = true;
            return;
        };

        self.buffer.writeByte(suffix) catch {
            self._rollback = true;
            return;
        };
    }

    pub fn writeAllAll(self: *@This(), data: []const u8, suffix: []const u8) void {
        if (self.fits_in_buf) {
            const end1 = self.buffer.pos + data.len;
            @memcpy(self.buffer.buf[self.buffer.pos..end1], data);

            const end2 = end1 + suffix.len;
            @memcpy(self.buffer.buf[end1..end2], suffix);
            self.buffer.pos = end2;
            return;
        }

        self.buffer.writeAll(data) catch {
            self._rollback = true;
            return;
        };

        self.buffer.writeAll(suffix) catch {
            self._rollback = true;
            return;
        };
    }

    pub fn writeByte(self: *@This(), b: u8) void {
        const pos = self.buffer.pos;
        if (self.fits_in_buf) {
            self.buffer.buf[pos] = b;
            self.buffer.pos = pos + 1;
            return;
        }

        self.buffer.writeByte(b) catch {
            self._rollback = true;
        };
    }

    pub fn rollback(self: *@This()) void {
        self._rollback = true;
        self.done();
    }

    pub fn done(self: *@This()) void {
        if (self._rollback == false) {
            return;
        }

        self.buffer.pos = self.initial_pos;
        if (self.initial_static == false) {
            return;
        }

        if (self.buffer.buf.ptr != self.buffer.static.ptr) {
            self.buffer.pool.releaseLarge(self.buffer.buf);
            self.buffer.buf = self.buffer.static;
        }
    }
};

pub const Pool = struct {
    mutex: std.Thread.Mutex,
    buffers: [][]u8,
    avaible: usize,
    allocator: std.mem.Allocator,
    buffer_size: usize,
    large_buffer_size: usize,

    pub fn init(allocator: std.mem.Allocator, config: *const Config) !@This() {
        const large_buffer_size = config.large_buffer_size;
        const large_buffer_count = if (large_buffer_size == 0) 0 else config.large_buffer_count;
        const buffers = try allocator.alloc([]u8, large_buffer_count);
        errdefer allocator.free(buffers);

        var initialized: usize = 0;
        errdefer {
            for (0..initialized) |i| {
                allocator.free(buffers[i]);
            }
        }

        for (0..large_buffer_count) |i| {
            buffers[i] = try allocator.alloc(u8, large_buffer_size);
            initialized += 1;
        }

        return .{
            .mutex = .{},
            .buffers = buffers,
            .avaible = large_buffer_count,
            .allocator = allocator,
            .buffer_size = config.buffer_size,
            .large_buffer_size = if (large_buffer_count == 0) 0 else large_buffer_size,
        };
    }

    pub fn deinit(self: *@This()) void {
        for (self.buffers) |buf| {
            self.allocator.free(buf);
        }
        self.allocator.free(self.buffers);
    }

    pub fn create(self: *@This()) !Buffer {
        const static = try self.allocator.alloc(u8, self.buffer_size);
        return .{
            .pos = 0,
            .pool = self,
            .buf = static,
            .static = static,
        };
    }

    pub fn acquireLarge(self: *@This()) ![]u8 {
        self.mutex.lock();

        if (self.avaible == 0) {
            self.mutex.unlock();
            return try self.allocator.alloc(u8, self.large_buffer_size);
        }

        const index = self.avaible - 1;
        const buf = self.buffers[index];
        self.avaible = index;
        self.mutex.unlock();
        return buf;
    }

    pub fn releaseLarge(self: *@This(), buf: []u8) void {
        self.mutex.lock();
        if (self.avaible == self.buffers.len) {
            self.mutex.unlock();
            self.allocator.free(buf);
            return;
        }
        self.buffers[self.avaible] = buf;
        self.avaible += 1;
        self.mutex.unlock();
    }
};
