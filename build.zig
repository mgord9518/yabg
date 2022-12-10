const std = @import("std");
const Builder = std.build.Builder;
const raylib = @import("raylib-zig/lib.zig");

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const target = b.standardTargetOptions(.{});

    const system_lib = b.option(bool, "system-raylib", "link to preinstalled raylib libraries") orelse false;

    const exe = b.addExecutable("yabg", "src/main.zig");
    exe.setBuildMode(mode);
    exe.setTarget(target);
    exe.linkLibC();

    raylib.link(exe, system_lib);
    raylib.addAsPackage("raylib", exe);
    raylib.math.addAsPackage("raylib-math", exe);

    exe.addPackagePath("perlin", "perlin-zig/lib.zig");

    const run_cmd = exe.run();
    const run_step = b.step("run", "run YABG");
    run_step.dependOn(&run_cmd.step);

    exe.install();
}
