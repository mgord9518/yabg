// This file exists to share variables over all areas of the game

const rl = @import("raylib");
const Chunk = @import("Chunk.zig").Chunk;

pub const Game = struct {
    pub var delta: f32 = 0;
    pub var screen_width: f32 = 0;
    pub var screen_height: f32 = 0;
    pub const tps = 30;
    pub var scale: f32 = 6;
    pub const title = "Yet Another Block Game (YABG)";
    pub const id = "io.github.mgord9518.yabg";
    pub var tiles: [256]rl.Texture = undefined;
    pub var pixel_snap: bool = false;
    pub var font: rl.Font = undefined;
    pub var chunks: [9]Chunk = undefined;
};
