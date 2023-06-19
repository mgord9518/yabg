const std = @import("std");
const Builder = std.build.Builder;
//const raylib = @import("raylib-zig/lib.zig");
const raylib = @import("raylib.zig/build.zig");

pub fn build(b: *Builder) void {
    //    const mode = b.standardReleaseOptions();

    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    //    const system_lib = b.option(bool, "system-raylib", "link to preinstalled raylib libraries") orelse false;
    const no_pie = b.option(bool, "no-pie", "do not build as a PIE (position independent executable) on Linux systems") orelse false;

    const exe = b.addExecutable(.{
        .name = "yabg",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    exe.linkLibC();

    //raylib.link(exe, system_lib);
    //raylib.addAsPackage("raylib", exe);
    //raylib.addAsPackage("raylib", exe);
    //raylib.math.addAsPackage("raylib-math", exe);

    const perlin_mod = b.addModule("perlin", .{ .source_file = .{ .path = "perlin-zig/lib.zig" } });

    //      const raylib_mod = b.addModule("raylib", .{ .source_file = .{ .path = "raylib.zig/raylib.zig" } });

    const toml_mod = b.addModule("toml", .{ .source_file = .{ .path = "zig-toml/src/toml.zig" } });

    const basedirs_mod = b.addModule("basedirs", .{ .source_file = .{ .path = "basedirs-zig/lib.zig" } });

    raylib.addTo(b, exe, target, optimize);

    exe.addModule("perlin", perlin_mod);
    //    exe.addModule("raylib", raylib_mod);
    exe.addModule("toml", toml_mod);
    exe.addModule("basedirs", basedirs_mod);

    //    exe.addPackagePath("perlin", "perlin-zig/lib.zig");
    //   exe.addPackagePath("raylib", "raylib.zig/raylib.zig");
    //    exe.addPackagePath("toml", "zig-toml/src/toml.zig");
    //    exe.addPackagePath("basedirs", "basedirs-zig/lib.zig");

    if (exe.target.getOsTag() == .linux) {
        exe.pie = !no_pie;
    }

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "run YABG");
    run_step.dependOn(&run_cmd.step);

    b.installArtifact(exe);
}
