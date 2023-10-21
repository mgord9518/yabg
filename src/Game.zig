// This file exists to share variables over all areas of the game

const std = @import("std");
const rl = @import("raylib");
const Chunk = @import("Chunk.zig");
const Tile = @import("Tile.zig").Tile;
const Player = @import("Player.zig");

pub var delta: f32 = 0;
pub var screen_width: f32 = 0;
pub var screen_height: f32 = 0;
pub const tps = 30;
pub var scale: f32 = 6;
pub const title = "Yet Another Block Game (YABG)";
pub const id = "io.github.mgord9518.yabg";

pub const version = std.SemanticVersion{
    .pre = "pre-alpha",

    .major = 0,
    .minor = 2,
    .patch = 2,
};

pub var font: rl.Font = undefined;
pub var chunks: [9]Chunk = undefined;
pub var sounds: [256]rl.Sound = undefined;

pub var tileTextures: [256]rl.Texture2D = undefined;
pub var tileSounds: [256]rl.Sound = undefined;
pub var tileMap: std.StringHashMap(Tile) = undefined;
