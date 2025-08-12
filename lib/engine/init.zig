pub const ui = @import("ui.zig");

const std = @import("std");

const engine = @import("../engine.zig");
const tick = @import("tick.zig");

const psf = @import("psf.zig");

pub fn init(
    comptime IdType: type,
    comptime ItemIdType: type,
    allocator: std.mem.Allocator,
) !void {
    var env_map = try std.process.getEnvMap(allocator);
    defer env_map.deinit();

    var initialization_arena = std.heap.ArenaAllocator.init(allocator);
    defer initialization_arena.deinit();

    engine.entities = std.SegmentedList(engine.Entity, 0){};

    engine.rand = std.Random.DefaultPrng.init(0);

    // Get enviornment variables and set window size to them if they exist
    const w_env: []const u8 = env_map.get("WINDOW_WIDTH") orelse "";
    const h_env: []const u8 = env_map.get("WINDOW_HEIGHT") orelse "";
    const scale_env: []const u8 = env_map.get("SCALE_FACTOR") orelse "";

    engine.scale = std.fmt.parseInt(u15, scale_env, 10) catch engine.scale;

    const w = std.fmt.parseInt(u15, w_env, 10) catch engine.screen_width * engine.scale;
    const h = std.fmt.parseInt(u15, h_env, 10) catch engine.screen_height * engine.scale;

    try engine.backend.init(allocator, w, h);

    const Engine = engine.engine(IdType, ItemIdType);

    Engine.chunks = std.AutoHashMap(Engine.world.ChunkCoordinate, *Engine.world.Chunk).init(allocator);

    try initFonts(allocator);
    try initSounds(IdType);
}

fn initFonts(allocator: std.mem.Allocator) !void {
    const psf_font = try psf.Font.parse(allocator, engine.font_data);

    // One extra pixel for the shadow
    const font_image_w = psf_font.glyphs.count() * (psf_font.w + 1);
    const font_image_h = psf_font.h + 1;

    // Won't need this after the texture has been loaded from the image
    const data = try allocator.alloc(u16, font_image_w * font_image_h);
    defer allocator.free(data);
    @memset(data, 0);

    const font_image = engine.ImageOld{
        .data = data.ptr,

        .width = @intCast(font_image_w),
        .height = @intCast(font_image_h),

        .mipmaps = 1,
        .format = @intFromEnum(engine.backend.ImageFormat.uncompressed_gray_alpha),
    };

    engine.font = .{
        .atlas = undefined,
        .glyph_offsets = std.AutoHashMap(u21, usize).init(allocator),
    };

    var x_off: u15 = 0;

    var key_it = psf_font.glyphs.keyIterator();
    while (key_it.next()) |key| : (x_off += (@as(u15, @truncate(psf_font.w)) + 1)) {
        try engine.drawCharToImage(psf_font, font_image, key.*, .{
            .x = x_off,
            .y = 0,
        });

        try engine.font.glyph_offsets.put(key.*, x_off);
    }
    engine.font.atlas = engine.loadTextureFromImage(font_image);
}

fn initSounds(comptime IdType: type) !void {
    // Tiles
    inline for (std.meta.fields(IdType)) |tile| {
        const tile_id: IdType = @enumFromInt(tile.value);

        // Exceptions
        switch (tile_id) {
            .air => continue,
            else => {},
        }

        const tile_sound = engine.loadSoundEmbedded("tiles/" ++ tile.name);

        engine.tileSounds[tile.value] = tile_sound;
    }
}
