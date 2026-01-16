const std = @import("std");
const builtin = @import("builtin");

const GPA = std.heap.GeneralPurposeAllocator(.{});

pub const AllocatorContext = struct {
    backing: std.mem.Allocator,
    arena: std.heap.ArenaAllocator,
    gpa: ?*GPA,

    pub fn init() !AllocatorContext {
        var gpa: ?*GPA = null;

        const backing = if (builtin.mode == .Debug) blk: {
            const gpa_ptr = try std.heap.c_allocator.create(GPA);
            gpa_ptr.* = GPA{};
            gpa = gpa_ptr;
            break :blk gpa_ptr.allocator();
        } else std.heap.c_allocator;

        const arena = std.heap.ArenaAllocator.init(backing);

        return .{
            .backing = backing,
            .arena = arena,
            .gpa = gpa,
        };
    }

    pub fn deinit(self: *AllocatorContext) void {
        self.arena.deinit();

        if (self.gpa) |gpa| {
            const check = gpa.deinit();
            if (check == .leak) {
                std.log.err("Memory leak detected in renderer allocator", .{});
            }
            std.heap.c_allocator.destroy(gpa);
        }
    }

    pub fn allocator(self: *AllocatorContext) std.mem.Allocator {
        return self.arena.allocator();
    }

    pub fn resetArena(self: *AllocatorContext) void {
        _ = self.arena.reset(.retain_capacity);
    }
};
