const std = @import("std");
pub const backend = @import("engine/backends/raylib.zig");

const psf = @import("engine/psf.zig");

pub const textures = @import("engine/textures.zig");
pub const ui = @import("engine/ui.zig");
pub const world = @import("engine/world.zig");
pub const Player = @import("engine/Player.zig");
pub const Entity = @import("engine/Entity.zig");
pub const Inventory = @import("engine/Inventory.zig");
pub const Item = @import("engine/item.zig").Item;

pub const init = @import("engine/init.zig").init;

const Font = struct {
    atlas: Texture,
    glyph_offsets: std.AutoHashMap(u21, usize),
};

pub const Coordinate = struct {
    x: i64,
    y: i64,
};

pub var screen_width: u15 = 160;
pub var screen_height: u15 = 144;
pub var scale: u15 = 4;
pub const id = "io.github.mgord9518.yabg";

pub const font_data = @embedFile("engine/fonts/5x8.psfu");
pub var font: Font = undefined;

pub var entities: std.SegmentedList(Entity, 0) = undefined;

pub const version = std.SemanticVersion{
    .pre = "pre-alpha",

    .major = 0,
    .minor = 0,
    .patch = 60,
};

pub var rand: std.Random.DefaultPrng = undefined;

pub const tps = 24;
pub var delta: f32 = 0;

pub const Image = backend.Image;
pub const Texture = backend.Texture;
pub const Sound = backend.Sound;

pub var tileSounds: [256]Sound = undefined;

pub var chunks: [9]world.Chunk = undefined;

pub const getFps = backend.getFps;
pub const shouldContinueRunning = backend.shouldContinueRunning;
pub const loadTextureEmbedded = backend.loadTextureEmbedded;
pub const loadSoundEmbedded = backend.loadSoundEmbedded;

pub fn playSound(sound: Sound) void {
    const pitch_offset = rand.random().float(f32) / 4;

    backend.playSound(
        sound,
        pitch_offset + 0.875,
    );
}

pub fn drawCharToImage(psf_font: psf.Font, image: Image, char: u21, pos: ui.NewVec) !void {
    const bitmap = psf_font.glyphs.get(char) orelse return;

    const imgw: usize = @intCast(image.width);
    const imgh: usize = @intCast(image.height);

    const image_data: []align(1) u16 = @as([*]u16, @ptrCast(@alignCast(image.data)))[0 .. imgw * imgh];

    const color = 0x7f_ee;
    const shadow_color = 0x7f_00;

    const x: u15 = @intCast(pos.x);
    var y: u15 = @intCast(pos.y);

    for (bitmap) |byte| {
        // Shadow
        if (byte & 0b10000000 != 0) image_data[x + 1 + (y + 1) * imgw] = shadow_color;
        if (byte & 0b01000000 != 0) image_data[x + 2 + (y + 1) * imgw] = shadow_color;
        if (byte & 0b00100000 != 0) image_data[x + 3 + (y + 1) * imgw] = shadow_color;
        if (byte & 0b00010000 != 0) image_data[x + 4 + (y + 1) * imgw] = shadow_color;
        if (byte & 0b00001000 != 0) image_data[x + 5 + (y + 1) * imgw] = shadow_color;

        if (byte & 0b10000000 != 0) image_data[x + 0 + y * imgw] = color;
        if (byte & 0b01000000 != 0) image_data[x + 1 + y * imgw] = color;
        if (byte & 0b00100000 != 0) image_data[x + 2 + y * imgw] = color;
        if (byte & 0b00010000 != 0) image_data[x + 3 + y * imgw] = color;
        if (byte & 0b00001000 != 0) image_data[x + 4 + y * imgw] = color;

        y += 1;

        if (y == psf_font.h) {
            y = @intCast(pos.y);
        }
    }
}
