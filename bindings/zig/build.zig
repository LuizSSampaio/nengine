const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const nengine = b.dependency("nengine", .{
        .target = target,
        .optimize = optimize,
    });

    const nengine_lib = nengine.artifact("nengine");
    b.installArtifact(nengine_lib);

    _ = b.addModule("nengine", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const entry = b.addModule("entry", .{
        .root_source_file = nengine.module("nengine").root_source_file,
        .target = target,
        .optimize = optimize,
    });
    entry.linkLibrary(nengine_lib);
}
