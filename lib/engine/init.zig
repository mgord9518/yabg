// This file exists to share variables over all areas of the game

pub const ui = @import("ui.zig");

const std = @import("std");
const rl = @import("raylib");

const engine = @import("../engine.zig");
const Chunk = @import("Chunk.zig");
const Player = @import("Player.zig");
const textures = @import("textures.zig");
const tick = @import("tick.zig");

const psf = @import("psf.zig");

pub fn init(allocator: std.mem.Allocator, comptime onEveryTickFn: fn() anyerror!void) !void {
    var env_map = try std.process.getEnvMap(allocator);
    defer env_map.deinit();

    var initialization_arena = std.heap.ArenaAllocator.init(allocator);
    defer initialization_arena.deinit();

    engine.entities = std.SegmentedList(engine.Entity, 0){};

    _ = try std.Thread.spawn(.{}, tick.tickMainThread, .{onEveryTickFn});

    engine.rand = std.Random.DefaultPrng.init(0);

    // Get enviornment variables and set window size to them if they exist
    const w_env: []const u8 = env_map.get("WINDOW_WIDTH") orelse "";
    const h_env: []const u8 = env_map.get("WINDOW_HEIGHT") orelse "";
    const scale_env: []const u8 = env_map.get("SCALE_FACTOR") orelse "";

    engine.scale = std.fmt.parseInt(u15, scale_env, 10) catch engine.scale;

    const w = std.fmt.parseInt(u15, w_env, 10) catch engine.screen_width * engine.scale;
    const h = std.fmt.parseInt(u15, h_env, 10) catch engine.screen_height * engine.scale;

    // Enable vsync, resizing and init audio devices
    rl.setConfigFlags(.{
        .vsync_hint = true,
        .window_resizable = true,
        //.window_highdpi= true,
    });

    rl.setTraceLogLevel(.debug);
    rl.initAudioDevice();

    const title = try std.fmt.allocPrintZ(initialization_arena.allocator(), "YABG {}", .{engine.version});

    rl.initWindow(@intCast(w), @intCast(h), title);
    rl.setWindowMinSize(@intCast(128 * engine.scale), @intCast(128 * engine.scale));
    rl.setWindowSize(@intCast(w), @intCast(h));

    engine.psf_font = try psf.Font.parse(allocator, engine.font_data);

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

    engine.font = .{
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

        try engine.font.glyph_offsets.put(key.*, off);
    }

    engine.font.atlas = try rl.loadTextureFromImage(font_image);

    try initTextures();
    try initSounds();

    // Disable exit on keypress
    //rl.setExitKey(.null);
}

fn initTextures() !void {
    // UI elements
    textures.hotbar_item = engine.loadTextureEmbedded("ui/hotbar_item");

    // Tiles
    inline for (std.meta.fields(engine.Tile.Id)) |tile| {
        const tile_id: engine.Tile.Id = @enumFromInt(tile.value);

        // Exceptions
        switch (tile_id) {
            .air => continue,
            else => {},
        }

        const tile_texture = engine.loadTextureEmbedded("tiles/" ++ tile.name);

        engine.tileTextures[tile.value] = tile_texture;
    }
}

fn initSounds() !void {
    // Tiles
    inline for (std.meta.fields(engine.Tile.Id)) |tile| {
        const tile_id: engine.Tile.Id = @enumFromInt(tile.value);

        // Exceptions
        switch (tile_id) {
            .air => continue,
            else => {},
        }

        const tile_sound = engine.loadSoundEmbedded("tiles/" ++ tile.name);

        engine.tileSounds[tile.value] = tile_sound;
    }
}
