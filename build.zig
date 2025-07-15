const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "yabg",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        // <https://github.com/Not-Nik/raylib-zig/issues/219>
        //.use_lld = false,
    });

    exe.linkLibC();

    const known_folders_dep = b.dependency("known-folders", .{});
    const perlin_dep = b.dependency("perlin", .{});

    //    const psftools_dep = b.dependency("psftools", .{
    //        .target = target,
    //        .optimize = optimize,
    //    });

    // Only needed for building font
    //    const txt2psf = b.addExecutable(.{
    //        .name = "txt2psf",
    //        .target = target,
    //        .optimize = optimize,
    //    });
    //
    //    txt2psf.addCSourceFiles(.{
    //        .root = b.path("tools/psftools-1.1.2"),
    //        .files = &.{
    //            "tools/txt2psf.c",
    //            "lib/psflib.c",
    //            "lib/psfucs.c",
    //            "lib/psfio.c",
    //            "lib/psferror.c",
    //        },
    //    });
    //
    //    txt2psf.linkLibC();

    const raylib_dep = b.dependency("raylib", .{
        .target = target,
        .optimize = optimize,
        //.platform = .drm,
        //.shared = true,
    });

    const yabg_engine_module = b.addModule("engine", .{
        .root_source_file = b.path("lib/engine.zig"),
        .imports = &.{
            .{
                .name = "perlin",
                .module = perlin_dep.module("perlin"),
            },
        },
    });

    exe.root_module.addImport("engine", yabg_engine_module);

    const raylib_artifact = raylib_dep.artifact("raylib");

    yabg_engine_module.linkLibrary(raylib_artifact);

    exe.root_module.addImport("known-folders", known_folders_dep.module("known-folders"));
    exe.root_module.addImport("perlin", perlin_dep.module("perlin"));

    const font_step = b.step("font", "Build font (requires psftools)");
    const run_txt2psf = b.addSystemCommand(&.{"txt2psf"});

    run_txt2psf.addFileArg(b.path("lib/engine/fonts/5x8.txt"));
    run_txt2psf.addFileArg(b.path("lib/engine/fonts/5x8.psfu"));

    font_step.dependOn(&run_txt2psf.step);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "run YABG");
    run_step.dependOn(&run_cmd.step);

    b.installArtifact(exe);
}
