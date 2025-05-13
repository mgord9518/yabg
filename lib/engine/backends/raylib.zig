const raylib = @import("raylib");

pub const Texture = raylib.Texture;
pub const Sound   = raylib.Sound;

const resource_root = "../../engine/";

pub fn getFps() usize {
    return @intCast(raylib.getFPS());
}

pub fn shouldContinueRunning() bool {
    return !raylib.windowShouldClose();
}

pub fn loadTextureEmbedded(comptime path: []const u8) Texture {
    const image = raylib.loadImageFromMemory(
        ".png",
        @embedFile(resource_root ++ "textures/" ++ path ++ ".png"),
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
