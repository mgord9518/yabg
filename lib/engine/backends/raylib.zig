const std = @import("std");
const raylib = @import("raylib");

pub const Image = raylib.Image;
pub const Texture = raylib.Texture;
pub const Sound = raylib.Sound;

const engine = @import("../../engine.zig");
const resource_root = "../../engine/";

pub fn init(allocator: std.mem.Allocator, window_width: u32, window_height: u32) !void {
    // Enable vsync, resizing and init audio devices
    raylib.setConfigFlags(.{
        .vsync_hint = true,
        .window_resizable = true,
        //.window_undecorated = true,
        //.window_highdpi = true,
    });

    raylib.setTraceLogLevel(.debug);
    raylib.initAudioDevice();

    const title = try std.fmt.allocPrintZ(allocator, "YABG {}", .{engine.version});

    raylib.initWindow(@intCast(window_width), @intCast(window_height), title);
    raylib.setWindowMinSize(@intCast(128 * engine.scale), @intCast(128 * engine.scale));
}

pub fn getFps() usize {
    return @intCast(raylib.getFPS());
}

pub fn shouldContinueRunning() bool {
    return !raylib.windowShouldClose();
}

pub fn playSound(sound: Sound, pitch: f32) void {
    raylib.setSoundPitch(sound, pitch);
    raylib.playSound(sound);
}

pub fn loadTextureEmbedded(comptime path: []const u8) Texture {
    const format = ".png";

    const image = raylib.loadImageFromMemory(
        ".png",
        @embedFile(resource_root ++ "textures/" ++ path ++ format),
    ) catch unreachable;

    return raylib.loadTextureFromImage(image) catch unreachable;
}

pub fn loadSoundEmbedded(comptime path: []const u8) Sound {
    const format = ".ogg";

    const wave = raylib.loadWaveFromMemory(
        format,
        @embedFile(resource_root ++ "sounds/" ++ path ++ format),
    ) catch unreachable;

    return raylib.loadSoundFromWave(wave);
}
