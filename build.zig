const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zglfw = b.dependency("zglfw", .{});

    const platform_mod = b.addModule("platform", .{
        .root_source_file = b.path("src/platform/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "glfw", .module = zglfw.module("root") },
        },
    });

    if (target.result.os.tag != .emscripten) {
        platform_mod.linkLibrary(zglfw.artifact("glfw"));
    }

    const renderer_mod = b.addModule("renderer", .{
        .root_source_file = b.path("src/renderer/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "platform", .module = platform_mod },
        },
    });

    const mod = b.addModule("nengine", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .imports = &.{
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
