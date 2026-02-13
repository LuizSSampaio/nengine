const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const title = b.option([]const u8, "title", "name of the game") orelse "shape2d";

    const options = b.addOptions();
    options.addOption([]const u8, "title", title);

    const nengine = b.dependency("nengine_zig", .{
        .target = target,
        .optimize = optimize,
    });

    const game_lib = b.addLibrary(.{
        .name = title,
        .linkage = .dynamic,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "nengine", .module = nengine.module("nengine") },
            },
        }),
    });
    b.installArtifact(game_lib);

    const exe = b.addExecutable(.{
        .name = title,
        .root_module = nengine.module("entry"),
    });
    exe.root_module.linkLibrary(game_lib);
    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
}
