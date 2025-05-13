// This file exists to share variables over all areas of the game

pub const ui = @import("ui.zig");

const std = @import("std");
const rl = @import("raylib");

const Chunk = @import("Chunk.zig");
const Player = @import("Player.zig");
const engine = @import("../engine.zig");

const psf = @import("psf.zig");

const Font = struct {
    atlas: rl.Texture,
    glyph_offsets: std.AutoHashMap(u21, usize),
};

const Vec = struct {
    x: u16,
    y: u16,
};

pub var screen_width: u15 = 160;
pub var screen_height: u15 = 144;
pub var scale: u15 = 4;
pub const title = "Yet Another Block Game (YABG)";
pub const id = "io.github.mgord9518.yabg";

pub const font_data = @embedFile("fonts/font.psfu");
pub var font: Font = undefined;

pub const version = std.SemanticVersion{
    .pre = "pre-alpha",

    .major = 0,
    .minor = 0,
    .patch = 57,
};

pub fn init(allocator: std.mem.Allocator) !void {
    var env_map = try std.process.getEnvMap(allocator);
    defer env_map.deinit();

    var initialization_arena = std.heap.ArenaAllocator.init(allocator);
    defer initialization_arena.deinit();

    engine.rand = std.Random.DefaultPrng.init(0);

    // Get enviornment variables and set window size to them if they exist
    const w_env: []const u8 = env_map.get("WINDOW_WIDTH") orelse "";
    const h_env: []const u8 = env_map.get("WINDOW_HEIGHT") orelse "";
    const scale_env: []const u8 = env_map.get("SCALE_FACTOR") orelse "";

    scale = std.fmt.parseInt(u15, scale_env, 10) catch scale;

    const w = std.fmt.parseInt(u15, w_env, 10) catch screen_width * scale;
    const h = std.fmt.parseInt(u15, h_env, 10) catch screen_height * scale;

    // Enable vsync, resizing and init audio devices
    rl.setConfigFlags(.{
        .vsync_hint = true,
        .window_resizable = true,
        //.window_highdpi= true,
    });

    rl.setTraceLogLevel(.debug);
    rl.initAudioDevice();

    rl.initWindow(@intCast(w), @intCast(h), title);
    rl.setWindowMinSize(@intCast(128 * scale), @intCast(128 * scale));
    rl.setWindowSize(@intCast(w), @intCast(h));

    engine.psf_font = try psf.Font.parse(allocator, font_data);

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

    var key_it = engine.psf_font.glyphs.keyIterator();
    while (key_it.next()) |key| : (off += (engine.psf_font.w + 1)) {
        try engine.drawCharToImage(font_image, key.*, .{
            .x = @intCast(off),
            .y = 0,
        });

        try font.glyph_offsets.put(key.*, off);
    }

    font.atlas = try rl.loadTextureFromImage(font_image);

    inline for (std.meta.fields(engine.Tile.Id)) |tile| {
        const tile_id: engine.Tile.Id = @enumFromInt(tile.value);

        // Exceptions
        switch (tile_id) {
            .air => continue,
            else => {},
        }

        const tile_texture = engine.loadTextureEmbedded("tiles/" ++ tile.name);
        const tile_sound = engine.loadSoundEmbedded("tiles/" ++ tile.name);

        engine.tileTextures[tile.value] = tile_texture;
        engine.tileSounds[tile.value] = tile_sound;
    }

    // Disable exit on keypress
    //rl.setExitKey(.null);
}
