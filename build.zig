const std = @import("std");
const Builder = std.build.Builder;
//const raylib = @import("raylib-zig/lib.zig");
const raylib = @import("raylib.zig/build.zig");

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const no_pie = b.option(bool, "no-pie", "do not build as a PIE (position independent executable) on Linux systems") orelse false;

    const exe = b.addExecutable(.{
        .name = "yabg",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    exe.linkLibC();

    const perlin_module = b.addModule("perlin", .{
        .source_file = .{
            .path = "perlin-zig/lib.zig",
        },
    });

    const basedirs_mod = b.addModule("basedirs", .{
        .source_file = .{
            .path = "basedirs-zig/lib.zig",
        },
    });

    raylib.addTo(b, exe, target, optimize);

    exe.addModule("perlin", perlin_module);
    exe.addModule("basedirs", basedirs_mod);

    if (exe.target.getOsTag() == .linux) {
        exe.pie = !no_pie;
    }

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "run YABG");
    run_step.dependOn(&run_cmd.step);

    b.installArtifact(exe);
}
