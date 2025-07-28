const std = @import("std");
const known_folders = @import("known-folders");
const assert = std.debug.assert;

const engine = @import("engine");
const textures = @import("textures.zig");

const ui = engine.ui;

const ChatLog = struct {
    text: std.ArrayList(u8),
};

var debug_menu: DebugMenu = undefined;
var player: engine.Player(TileIdType) = undefined;

const Camera = struct {
    pos: Coordinate,

    pub const Coordinate = struct {
        x: f64,
        y: f64,
    };

    pub fn draw(camera: *const Camera) !void {
        engine.chunk_mutex.lock();

        const x_pos: i64 = @intFromFloat(@floor(camera.pos.x));
        const y_pos: i64 = @intFromFloat(@floor(camera.pos.y));

        const x_subtile = (camera.pos.x - @floor(camera.pos.x)) * engine.world.tile_size;
        const y_subtile = (camera.pos.y - @floor(camera.pos.y)) * engine.world.tile_size;

        const remaining_x: i32 = @intFromFloat(x_subtile);

        const remaining_y: i32 = @intFromFloat(y_subtile);

        // Screen modulo is to draw tiles offset depending on screen resolution
        // this only matters if the window resolution isn't a factor of 12
        // pixels, which may happen if the player resized the window
        const screen_mod_x: u31 = @mod(@divTrunc(engine.screen_width, 2), engine.world.tile_size);
        const screen_mod_y: u31 = @mod(@divTrunc(engine.screen_height, 2), engine.world.tile_size);

        const screen_width_in_tiles = engine.screen_width / engine.world.tile_size;
        const screen_height_in_tiles = engine.screen_height / engine.world.tile_size;

        // TODO: refactor
        var x: i32 = undefined;
        var y: i32 = -1;
        while (y <= screen_height_in_tiles + 1) : (y += 1) {
            x = -1;

            while (x <= screen_width_in_tiles + 1) : (x += 1) {
                for (engine.chunks(TileIdType)) |*chunk| {
                    const chunk_coord_x = chunk.x * engine.world.chunk_size;
                    const chunk_coord_y = chunk.y * engine.world.chunk_size;

                    const tile_x: i64 = (x_pos + x - (screen_width_in_tiles / 2) - chunk_coord_x);
                    const tile_y: i64 = (y_pos + y - (screen_height_in_tiles / 2) - chunk_coord_y);

                    // Skip if tile not on screen
                    if (x + x_pos - (screen_width_in_tiles / 2) < chunk_coord_x or
                        x + x_pos - (screen_width_in_tiles / 2) >= chunk_coord_x + engine.world.chunk_size or
                        y + y_pos - (screen_height_in_tiles / 2) < chunk_coord_y or
                        y + y_pos - (screen_height_in_tiles / 2) >= chunk_coord_y + engine.world.chunk_size) continue;

                    // Only loop through the first half of chunk engine.tiles (floor level)
                    // If wall level tile exists, draw it instead
                    switch (chunk.getTileAtOffset(.wall, @intCast(tile_x), @intCast(tile_y)).id) {
                        .air => {
                            const tile = chunk.getTileAtOffset(.floor, @intCast(tile_x), @intCast(tile_y));

                            engine.drawTexture(tile.texture(), .{
                                .x = (x * engine.world.tile_size) - remaining_x + screen_mod_x - (engine.world.tile_size / 2),
                                .y = (y * engine.world.tile_size) - remaining_y + screen_mod_y + 4 - (engine.world.tile_size / 2),
                            }, .{ .r = 204, .g = 204, .b = 204, .a = 255 });
//                            }, .{ .r = 255, .g = 255, .b = 255, .a = 255 });
                        },
                        else => {
                            if ((y * engine.world.tile_size) - 1 >= engine.screen_height / 2) continue;

                            const tile = chunk.getTileAtOffset(.wall, @intCast(tile_x), @intCast(tile_y));

                            engine.drawTexture(tile.texture(), .{
                                .x = (x * engine.world.tile_size) - remaining_x + screen_mod_x - (engine.world.tile_size / 2),
                                .y = (y * engine.world.tile_size) - remaining_y + screen_mod_y - 4 - (engine.world.tile_size / 2),
                            }, .{ .r = 255, .g = 255, .b = 255, .a = 255 });
                        },
                    }
                }
            }
        }

        // Draw player in the center of the screen
        engine.drawTextureRect(
            player.entity.animation_texture[@intFromEnum(player.entity.animation)],
            .{
                // Multiply by 12 to shift to the current frame in the player's
                // texture atlas
                .x = @as(u15, player.entity.frame_num) * 12,
                .y = 0,
                .w = 12,
                .h = 24,
            },
            .{
                .x = @intCast((engine.screen_width / 2) - 6),
                .y = @intCast((engine.screen_height / 2) - 10),
            },
            .{ .r = 255, .g = 255, .b = 255, .a = 255 },
        );

        if (debug_menu.enabled) {
            // Collision area around player's feet
            engine.drawRect(.{
                .x = @intCast((engine.screen_width / 2) - 6),
                .y = @intCast((engine.screen_height / 2) + 7),
                .w = 12,
                .h = 12,
            }, .{ .r = 255, .g = 0, .b = 255, .a = 0x60 });
        }

        // Now draw all raised tiles that sit above the player in front to give
        // an illusion of depth
        y = -1;
        while (y <= screen_height_in_tiles + 1) : (y += 1) {
            x = -1;
            while (x <= screen_width_in_tiles + 1) : (x += 1) {
                for (engine.chunks(TileIdType)) |*chunk| {
                    const chunk_coord_x = chunk.x * engine.world.chunk_size;
                    const chunk_coord_y = chunk.y * engine.world.chunk_size;

                    // Camera pos is in middle of the screen, so shift back half a screen
                    const tile_x_world_pos: i64 = (x_pos - (screen_width_in_tiles / 2) + x);
                    const tile_y_world_pos: i64 = (y_pos - (screen_height_in_tiles / 2) + y);

                    const tile_x_chunk_off = std.math.cast(u16, tile_x_world_pos - chunk_coord_x) orelse continue;
                    const tile_y_chunk_off = std.math.cast(u16, tile_y_world_pos - chunk_coord_y) orelse continue;

                    // Skip if tile is beyond chunk border (negatives skipped with the math cast above)
                    if (tile_x_chunk_off >= engine.world.chunk_size) continue;
                    if (tile_y_chunk_off >= engine.world.chunk_size) continue;

                    // Only draw raised tiles
                    const wall_tile = chunk.getTileAtOffset(.wall, tile_x_chunk_off, tile_y_chunk_off);
                    if (wall_tile.id == .air) continue;

                    if ((y * engine.world.tile_size) - 1 >= engine.screen_height / 2) {
                        engine.drawTexture(wall_tile.texture(), .{
                            .x = (x * engine.world.tile_size) - remaining_x + screen_mod_x - (engine.world.tile_size / 2),
                            .y = (y * engine.world.tile_size) - remaining_y + screen_mod_y - 4 - (engine.world.tile_size / 2),
                        }, .{ .r = 255, .g = 255, .b = 255, .a = 255 });
                    }
                }
            }
        }

        engine.chunk_mutex.unlock();
    }
};

const DebugMenu = struct {
    enabled: bool = false,

    x: f32 = 0,
    y: f32 = 0,
    player: *engine.Player(TileIdType),

    fn draw(menu: *DebugMenu, allocator: std.mem.Allocator) !void {
        // Print debug menu
        const string = try std.fmt.allocPrintZ(
            allocator,
            \\YABG {}
            \\FPS: {d}
            \\
            \\X:{d:>3}
            \\Y:{d:>3}
        ,
            .{
                engine.version,
                engine.getFps(),
                menu.player.entity.pos.x,
                menu.player.entity.pos.y,
            },
        );
        defer allocator.free(string);

        var alpha: u8 = undefined;
        if (menu.y < 0) {
            alpha = @intFromFloat(192 + menu.y);
        }

        try ui.drawText(
            string,
            .{
                .x = 2,
                .y = @intFromFloat(menu.y + 1),
            },
            .{ .r = 255, .g = 255, .b = 255, .a = 255 },
        );
    }
};

pub fn onEveryTick() !void {
    try player.reloadChunks();
}

pub fn onEveryFrame(allocator: std.mem.Allocator) !void {
    var arena_allocator = std.heap.ArenaAllocator.init(allocator);
    defer arena_allocator.deinit();

    // Tile coordinate of player
    var x_num: f64 = @floatFromInt(player.entity.pos.x);
    var y_num: f64 = @floatFromInt(player.entity.pos.y);

    if (player.entity.remaining_x < 0) {
        x_num -= 1;
    }

    if (player.entity.remaining_y < 0) {
        y_num -= 1;
    }

    const camera = Camera{
        .pos = .{
            .x = x_num + @mod(1 - player.entity.remaining_x, 1),

            // Offset to position player in the center of the screen
            .y = y_num + @mod(1 - player.entity.remaining_y, 1) - 1 + 0.25,
        },
    };

    engine.beginDrawing();

    try camera.draw();

    if (debug_menu.enabled) {
        try debug_menu.draw(arena_allocator.allocator());
    }

    try drawHotbar(arena_allocator.allocator(), player.inventory);

    if (engine.isButtonPressed(.debug)) {
        debug_menu.enabled = !debug_menu.enabled;
    }

    engine.textures.cursor.draw(engine.mousePosition());

    engine.endDrawing();
}

pub export fn update() void {
    player.updatePlayerFrames();

    player.updateAnimation();

    player.updateState() catch unreachable;

    onEveryFrame(std.heap.page_allocator) catch unreachable;
}

pub export fn init() void {
    initTextures(TileIdType) catch unreachable;
}

pub fn initTextures(comptime IdType: type) !void {
    // UI elements
    engine.textures.hotbar_item = engine.loadTextureEmbedded("ui/hotbar_item");

    engine.textures.cursor = textures.cursor;

    inline for (std.meta.fields(IdType)) |tile| {
        std.debug.print("loading {s}\n", .{tile.name});
        const tile_id: IdType = @enumFromInt(tile.value);

        // Exceptions
        switch (tile_id) {
            .air => continue,
            else => {},
        }

        //const tile_texture = engine.loadTextureEmbedded("tiles/" ++ tile.name);

        //engine.textures.tiles[tile.value] = tile_texture;

        // TODO: replace all PNG files with in-code images
        if (@hasDecl(textures.tiles, tile.name)) {
            engine.textures.tiles[tile.value] = try @field(textures.tiles, tile.name).toTexture();
        }
    }
}

fn drawHotbar(allocator: std.mem.Allocator, inventory: engine.Inventory(TileIdType)) !void {
    const hotbar_item_width = 16;
    const hotbar_item_spacing = 1;

    const hotbar_begin = (engine.screen_width / 2) - ((hotbar_item_width + hotbar_item_spacing) * 3);
    const hotbar_y: i16 = @intCast(engine.screen_height - hotbar_item_width - hotbar_item_spacing);

    for (inventory.items, 0..) |maybe_item, idx| {
        const hotbar_x: i16 = @intCast(hotbar_begin + idx * (hotbar_item_width + hotbar_item_spacing));

        var tint = engine.backend.Color{ .r = 255, .g = 255, .b = 255, .a = 255 };
        if (idx == inventory.selected_slot) {
            tint = .{ .r = 102, .g = 191, .b = 255, .a = 255 };
        }

        engine.drawTexture(
            engine.textures.hotbar_item,
            .{ .x = hotbar_x, .y = hotbar_y },
            tint,
        );

        const item = maybe_item orelse continue;

        engine.drawTextureRect(
            item.value.tile.texture(),
            .{ .x = 0, .y = 0, .w = 12, .h = 12 },
            .{ .x = hotbar_x + 2, .y = hotbar_y + 2 },
            .{ .r = 255, .g = 255, .b = 255, .a = 255 },
        );

        try ui.drawText(
            try std.fmt.allocPrint(allocator, "{d}", .{item.count}),
            .{
                .x = hotbar_x + 3 + @as(u15, if (item.count < 10) 3 else 0),
                .y = hotbar_y + 4,
            },
            .{ .r = 255, .g = 255, .b = 255, .a = 255 },
        );
    }
}

pub const TileIdType = enum(u8) {
    /// Categories should denote the basic qualities of a specific tile.
    /// While different submaterials (eg: grass and sand or cobblestone and brick)
    /// may have different hardnesses and sound, they're still collected with the
    /// same type of tool
    air = 0,

    // Various kinds of soil, sand, gravel, etc.
    dirt = 8,
    grass,
    sand,

    // Logs, planks, bamboo
    //wood = 16,

    // Cobblestone, smooth stone, bricks, ore
    stone = 32,

    //metal = 48,

    // Computers, wires, machines
    //electronic = 64,

    water = 80,

    //misc = 240,

    // Tile dedicated to the `placeholder` texture
    placeholder = 255,

    pub fn texture(self: TileIdType) engine.Texture {
        return engine.textures.tiles[@intFromEnum(self)];
    }

    pub fn sound(self: TileIdType) engine.Sound {
        return engine.tileSounds[@intFromEnum(self)];
    }
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var initialization_arena = std.heap.ArenaAllocator.init(allocator);
    defer initialization_arena.deinit();

    const env_map = try std.process.getEnvMap(initialization_arena.allocator());

    try engine.init(TileIdType, allocator, onEveryTick);
    //try init.initTextures(TileIdType);
    //init();

    const speed_env: []const u8 = env_map.get("PLAYER_SPEED") orelse "";
    engine.Entity.walk_speed = std.fmt.parseFloat(f32, speed_env) catch engine.Entity.walk_speed;

    const data_dir = (try known_folders.getPath(allocator, .data)).?;

    const save_path = try std.fs.path.joinZ(
        allocator,
        &.{
            data_dir,
            engine.id,
            "saves",
            "DEVTEST",
        },
    );

    player = try engine.Player(TileIdType).init(allocator, save_path);
    debug_menu = DebugMenu{ .player = &player };

    debug_menu.enabled = env_map.get("DEBUG_MODE") != null;

    //var settings = Menu{ .player = &player, .texture = menu_frame_texture };

    // Create save directory if it doesn't already exist
    const cwd = std.fs.cwd();
    cwd.makePath(save_path) catch |err| {
        std.debug.print("Error creating save directory: {}", .{err});
    };

    var chunk_x = @divTrunc(player.entity.pos.x, engine.world.chunk_size);
    var chunk_y = @divTrunc(player.entity.pos.y, engine.world.chunk_size);

    if (player.entity.pos.x < 0) {
        chunk_x = chunk_x - 1;
    }

    if (player.entity.pos.y < 0) {
        chunk_y = chunk_y - 1;
    }

    // Init chunk array
    // TODO: lower this number to 4 to so that less iterations have to be done
    var x_it: i32 = @intCast(chunk_x - 1);
    var y_it: i32 = @intCast(chunk_y - 1);
    var it: usize = 0;
    while (x_it <= chunk_x + 1) : (x_it += 1) {
        while (y_it <= chunk_y + 1) : (y_it += 1) {
            engine.chunks(TileIdType)[it] = try engine.world.Chunk(TileIdType).load(save_path, "vanilla0", x_it, y_it);
            it += 1;
        }
        y_it = @intCast(chunk_y - 1);
    }

    engine.run();

    for (engine.chunks(TileIdType)) |chunk| {
        try chunk.save(allocator, player.save_path, "vanilla0");
    }

    try player.save();

    engine.closeWindow();
}

fn mainMenuLoop(allocator: std.mem.Allocator) !void {
    var arena_allocator = std.heap.ArenaAllocator.init(allocator);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    engine.beginDrawing();

    try ui.drawText(
        try std.fmt.allocPrint(arena, "YABG {}", .{
            engine.version,
        }),
        .{ .x = 2, .y = 2 },
        .{ .r = 255, .g = 255, .b = 255, .a = 255 },
    );

    try ui.button("Save 1", .{ .x = 2, .y = 40, .w = 38, .h = 17 });

    engine.endDrawing();
}
