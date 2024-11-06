const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const no_pie = b.option(bool, "no-pie", "do not build as a PIE (position independent executable) on Linux systems") orelse false;

    const exe = b.addExecutable(.{
        .name = "yabg",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.linkLibC();

    const raylib_dep = b.dependency("raylib", .{
        .target = target,
        .optimize = optimize,
    });

    const known_folders_dep = b.dependency("known-folders", .{});
    const perlin_dep = b.dependency("perlin", .{});

    const raylib = raylib_dep.module("raylib");
    const raylib_artifact = raylib_dep.artifact("raylib");

    exe.linkLibrary(raylib_artifact);
    exe.root_module.addImport("raylib", raylib);
    exe.root_module.addImport("known-folders", known_folders_dep.module("known-folders"));
    exe.root_module.addImport("perlin", perlin_dep.module("perlin"));

    if (target.result.os.tag == .linux) {
        exe.pie = !no_pie;
    }

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "run YABG");
    run_step.dependOn(&run_cmd.step);

    b.installArtifact(exe);
}
