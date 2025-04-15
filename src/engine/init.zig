// This file exists to share variables over all areas of the game

pub const ui = @import("ui.zig");

const std = @import("std");
const rl = @import("raylib");
const Chunk = @import("../Chunk.zig");
const Tile = @import("../Tile.zig").Tile;
const Player = @import("../Player.zig");

const psf = @import("psf.zig");

const known_folders = @import("known-folders");

const Font = struct {
    atlas: rl.Texture,
    glyph_offsets: std.AutoHashMap(u21, usize),
};

const Vec = struct {
    x: u16,
    y: u16,
};

pub const ItemType = union(enum) {
    tile: Tile.Id,
};

pub const Item = struct {
    value: ItemType,
    count: u8,
};

pub var delta: f32 = 0;
pub var screen_width: f32 = 0;
pub var screen_height: f32 = 0;
pub const tps = 24;
pub var scale: f32 = 4;
pub const title = "Yet Another Block Game (YABG)";
pub const id = "io.github.mgord9518.yabg";

pub const font_data = @embedFile("font.psfu");
pub var font: Font = undefined;
pub var psf_font: psf.Font = undefined;

pub const version = std.SemanticVersion{
    .pre = "pre-alpha",

    .major = 0,
    .minor = 0,
    .patch = 54,
};

pub var chunks: [9]Chunk = undefined;
pub var sounds: [256]rl.Sound = undefined;

pub var tileTextures: [256]rl.Texture2D = undefined;
pub var tileSounds: [256]rl.Sound = undefined;
pub var tileMap: std.StringHashMap(Tile) = undefined;

pub fn init(allocator: std.mem.Allocator) !void {
    var env_map = try std.process.getEnvMap(allocator);
    defer env_map.deinit();

    var initialization_arena = std.heap.ArenaAllocator.init(allocator);
    defer initialization_arena.deinit();

    // Get enviornment variables and set window size to them if they exist
    const w_env: []const u8 = env_map.get("WINDOW_WIDTH") orelse "";
    const h_env: []const u8 = env_map.get("WINDOW_HEIGHT") orelse "";
    const scale_env: []const u8 = env_map.get("SCALE_FACTOR") orelse "";

    scale = @floor(std.fmt.parseFloat(f32, scale_env) catch scale);

    const scale_i: i32 = @intFromFloat(scale);
    const width_i: u31 = @intFromFloat(screen_width);
    const height_i: u31 = @intFromFloat(screen_height);

    const w = std.fmt.parseInt(i32, w_env, 10) catch width_i * scale_i;
    const h = std.fmt.parseInt(i32, h_env, 10) catch height_i * scale_i;

    // Enable vsync, resizing and init audio devices
    rl.setConfigFlags(.{
        .vsync_hint = true,
        .window_resizable = true,
        //.window_highdpi= true,
    });

    rl.setTraceLogLevel(.debug);
    rl.initAudioDevice();

    rl.initWindow(w, h, title);
    rl.setWindowMinSize(128 * scale_i, 128 * scale_i);
    rl.setWindowSize(160 * scale_i, 144 * scale_i);

    psf_font = try psf.Font.parse(allocator, font_data);

    const data = try allocator.alloc(u16, 9 * (1024 * 4) + 1);

    @memset(data, 0);

    const font_image = rl.Image{
        .data = data.ptr,

        // Room for 1024 characters
        // Should be expanded in the future as needed
        .width = 1024 * 4 + 1,

        // One extra pixel for the shadow
        .height = 8 + 1,
        .mipmaps = 1,
        .format = .uncompressed_gray_alpha,
    };

    font = .{
        .atlas = undefined,
        .glyph_offsets = std.AutoHashMap(u21, usize).init(allocator),
    };

    var off: usize = 0;

    var key_it = psf_font.glyphs.keyIterator();
    while (key_it.next()) |key| : (off += (psf_font.w + 1)) {
        try drawCharToImage(font_image, key.*, .{
            .x = @intCast(off),
            .y = 0,
        });

        try font.glyph_offsets.put(key.*, off);
    }

    font.atlas = try rl.loadTextureFromImage(font_image);

    inline for (std.meta.fields(Tile.Id)) |tile| {
        const tile_id: Tile.Id = @enumFromInt(tile.value);
        // Exceptions
        switch (tile_id) {
            .air => continue,
            else => {},
        }

        const tile_texture = loadTextureEmbedded("tiles/" ++ tile.name);

        const tile_sound = loadSoundEmbedded("tiles/" ++ tile.name);

        Tile.setTexture(tile_id, tile_texture);
        Tile.setSound(tile_id, tile_sound);
    }

    // Disable exit on keypress
    rl.setExitKey(.null);
}

pub fn loadTextureEmbedded(comptime path: []const u8) rl.Texture {
    const image = rl.loadImageFromMemory(
        ".png",
        @embedFile("textures/" ++ path ++ ".png"),
    ) catch unreachable;

    return rl.loadTextureFromImage(image) catch unreachable;
}

pub fn loadSoundEmbedded(comptime path: []const u8) rl.Sound {
    const wave = rl.loadWaveFromMemory(
        ".wav",
        @embedFile("sounds/" ++ path ++ ".wav"),
    ) catch unreachable;

    return rl.loadSoundFromWave(wave);
}

pub fn tileTexture(tile_id: Tile.Id) rl.Texture {
    return tileTextures[@intFromEnum(tile_id)];
}

fn drawCharToImage(image: rl.Image, char: u21, pos: Vec) !void {
    const bitmap = psf_font.glyphs.get(char) orelse return;

    const imgw: usize = @intCast(image.width);
    const imgh: usize = @intCast(image.height);

    const image_data: []align(1) u16 = @as([*]u16, @ptrCast(@alignCast(image.data)))[0 .. imgw * imgh];

    const color = 0x7f_ee;
    const shadow_color = 0x7f_00;

    const x = pos.x;
    var y = pos.y;

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
            y = pos.y;
        }
    }
}
