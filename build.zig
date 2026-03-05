const std = @import("std");

pub const Pipeline = enum { opengl };

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const pipeline = b.option(Pipeline, "pipeline", "renderer pipeline to be used") orelse Pipeline.opengl;

    const options = b.addOptions();
    options.addOption(Pipeline, "pipeline", pipeline);

    const logger_mod = b.addModule("logger", .{
        .root_source_file = b.path("src/logger/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const event_mod = b.addModule("event", .{
        .root_source_file = b.path("src/event/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "logger", .module = logger_mod },
        },
    });

    const window_mod = b.addModule("window", .{
        .root_source_file = b.path("src/window/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "logger", .module = logger_mod },
            .{ .name = "event", .module = event_mod },
        },
    });

    const renderer_mod = b.addModule("renderer", .{
        .root_source_file = b.path("src/renderer/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "logger", .module = logger_mod },
            .{ .name = "window", .module = window_mod },
        },
    });
    renderer_mod.addOptions("build_options", options);

    switch (pipeline) {
        .opengl => enableOpenGL(b, target, optimize, window_mod, renderer_mod),
    }

    const nengine_lib = b.addLibrary(.{
        .name = "nengine",
        .linkage = .dynamic,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "logger", .module = logger_mod },
                .{ .name = "window", .module = window_mod },
                .{ .name = "renderer", .module = renderer_mod },
                .{ .name = "event", .module = event_mod },
            },
        }),
    });
    b.installArtifact(nengine_lib);

    _ = b.addModule("nengine", .{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
}

fn enableOpenGL(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, window: *std.Build.Module, renderer: *std.Build.Module) void {
    const zglfw = b.dependency("zglfw", .{});
    window.addImport("glfw", zglfw.module("root"));

    if (target.result.os.tag != .emscripten) {
        window.linkLibrary(zglfw.artifact("glfw"));
    }

    const zopengl = b.dependency("zopengl", .{});
    const opengl_backend_mod = b.addModule("opengl_backend", .{
        .root_source_file = b.path("src/renderer/backend/opengl/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "opengl", .module = zopengl.module("root") },
        },
    });

    renderer.addImport("opengl", opengl_backend_mod);
}
