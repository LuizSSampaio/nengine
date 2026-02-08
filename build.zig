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

    const platform_mod = b.addModule("platform", .{
        .root_source_file = b.path("src/platform/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "logger", .module = logger_mod },
        },
    });

    const renderer_mod = b.addModule("renderer", .{
        .root_source_file = b.path("src/renderer/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "logger", .module = logger_mod },
            .{ .name = "platform", .module = platform_mod },
        },
    });
    renderer_mod.addOptions("build_options", options);

    switch (pipeline) {
        .opengl => enableOpenGL(b, target, optimize, platform_mod, renderer_mod),
    }

    const mod = b.addModule("nengine", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "logger", .module = logger_mod },
            .{ .name = "platform", .module = platform_mod },
            .{ .name = "renderer", .module = renderer_mod },
        },
    });

    const exe = b.addExecutable(.{
        .name = "nengine",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "nengine", .module = mod },
            },
        }),
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}

fn enableOpenGL(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, platform: *std.Build.Module, renderer: *std.Build.Module) void {
    const zglfw = b.dependency("zglfw", .{});
    platform.addImport("glfw", zglfw.module("root"));

    if (target.result.os.tag != .emscripten) {
        platform.linkLibrary(zglfw.artifact("glfw"));
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
