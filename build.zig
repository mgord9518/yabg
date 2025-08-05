const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "yabg",
        .root_source_file = b.path("src/main.zig"),
        //.root_source_file = b.path("src/wasm_test.zig"),
        .target = target,
        .optimize = optimize,
        // <https://github.com/Not-Nik/raylib-zig/issues/219>
        //.use_lld = false,
    });


    const known_folders_dep = b.dependency("known-folders", .{});
    const perlin_dep = b.dependency("perlin", .{});

    const yabg_engine_module = b.addModule("engine", .{
        .root_source_file = b.path("lib/engine.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{
                .name = "perlin",
                .module = perlin_dep.module("perlin"),
            },
        },
    });

    switch (target.result.cpu.arch) {
        .wasm32 => {
            exe.entry = .disabled;
            exe.rdynamic = true;
        },
//        .x86_64 => {
//            yabg_engine_module.linkSystemLibrary("glfw", .{});
//            yabg_engine_module.linkSystemLibrary("GL", .{});
//            yabg_engine_module.addIncludePath(b.path("lib/engine/backends/glfw/glad/include"));
//            yabg_engine_module.addCSourceFile(.{ .file = b.path("lib/engine/backends/glfw/glad/src/glad.c") });
//        },
        else => {
            const raylib_dep = b.dependency("raylib", .{
                .target = target,
                .optimize = optimize,
                //.platform = .drm,
                //.shared = true,
            });

            const raylib_artifact = raylib_dep.artifact("raylib");

            yabg_engine_module.linkLibrary(raylib_artifact);

            exe.linkLibC();
        },
    }

    exe.root_module.addImport("engine", yabg_engine_module);

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

fn linkRaylib(b: *std.Build, mod: *std.Build.Module, options: std.Build.ExecutableOptions) void {
    const raylib_dep = b.dependency("raylib", .{
        .target = options.target,
        .optimize = options.optimize,
        //.platform = .drm,
        //.shared = true,
    });

    const raylib_artifact = raylib_dep.artifact("raylib");

   // yabg_engine_module.linkLibrary(raylib_artifact);
    mod.linkLibrary(raylib_artifact);
}
