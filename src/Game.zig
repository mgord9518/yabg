// This file exists to share variables over all areas of the game

const rl = @import("raylib");
const Chunk = @import("Chunk.zig").Chunk;
const Tile = @import("Tile.zig").Tile;

pub const Game = struct {
    pub var delta: f32 = 0;
    pub var screen_width: f32 = 0;
    pub var screen_height: f32 = 0;
    pub const tps = 30;
    pub var scale: f32 = 6;
    pub const title = "Yet Another Block Game (YABG)";
    pub const id = "io.github.mgord9518.yabg";

    pub var font: rl.Font = undefined;
    pub var chunks: [9]Chunk = undefined;
    pub var sounds: [256]rl.Sound = undefined;

    pub var tiles: [256]rl.Texture = undefined;

    pub fn tileTexture(tile_id: Tile.Id) rl.Texture {
        return tiles[@enumToInt(tile_id)];
    }

    pub fn setTileTexture(tile_id: Tile.Id, texture: rl.Texture) void {
        tiles[@enumToInt(tile_id)] = texture;
    }
};
