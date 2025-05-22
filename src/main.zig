const rl = @import("raylib");
const std = @import("std");
const builtin = @import("builtin");
const known_folders = @import("known-folders");
const assert = std.debug.assert;

const engine = @import("engine");

const ui = engine.ui;

const ChatLog = struct {
    text: std.ArrayList(u8),
};

var debug_menu: DebugMenu = undefined;
var player: engine.Player = undefined;

const Camera = struct {
    pos: engine.Coordinate,

    // Fraction of a tile for positioning
    sub_pos_x: f32,
    sub_pos_y: f32,

    pub fn draw(camera: *const Camera) !void {
        assert(camera.sub_pos_x >= 0 and camera.sub_pos_x < 1);
        assert(camera.sub_pos_y >= 0 and camera.sub_pos_y < 1);
        
        const x_subtile = camera.sub_pos_x * engine.Tile.size;
        const y_subtile = camera.sub_pos_y * engine.Tile.size;

        const remaining_x: i32 = @intFromFloat(x_subtile);

        // Add 3 to offset tiles to player's feet
        const remaining_y: i32 = @intFromFloat(y_subtile + 3);

        // Screen modulo is to draw tiles offset depending on screen resolution
        // this only matters if the window resolution isn't a factor of 12
        // pixels, which may happen if the player resized the window
        const screen_mod_x: u31 = @mod(@divTrunc(engine.screen_width, 2), engine.Tile.size);

        const screen_mod_y: u31 = @mod(@divTrunc(engine.screen_height, 2), engine.Tile.size);

        // TODO: refactor
        var x: i32 = (engine.screen_width / engine.Tile.size / 2) - 2;
        var y: i32 = (engine.screen_height / engine.Tile.size / 2) - 2;
        x = -1;
        y = -3;
        while (y * engine.Tile.size <= engine.screen_height) : (y += 1) {
            x = -1;
            while (x * engine.Tile.size <= engine.screen_width + engine.Tile.size) : (x += 1) {
                for (&engine.chunks) |*chnk| {
                    const y_pos = y * engine.Tile.size - remaining_y + screen_mod_y + 12;

                    const screen_width_in_tiles = engine.screen_width / (engine.Tile.size * 2);
                    const screen_height_in_tiles = engine.screen_height / (engine.Tile.size * 2);

                    const tile_x: i64 = @mod(camera.pos.x + x - screen_width_in_tiles, engine.Chunk.size);
                    const tile_y: i64 = (camera.pos.y + y - screen_height_in_tiles - chnk.y) * engine.Chunk.size;

                    // Skip if tile not on screen
                    if (x + camera.pos.x - screen_width_in_tiles < chnk.x or
                        x + camera.pos.x - screen_width_in_tiles >= chnk.x + engine.Chunk.size or
                        y + camera.pos.y - screen_height_in_tiles < chnk.y or
                        y + camera.pos.y - screen_height_in_tiles >= chnk.y + engine.Chunk.size) continue;

                    if (tile_x + tile_y < 0 or tile_x + tile_y > engine.Chunk.size * engine.Chunk.size) continue;

                    // Only loop through the first half of chunk engine.tiles (floor level)
                    // If wall level tile exists, draw it instead
                    switch (chnk.tile(.wall, @intCast(tile_x), @intCast(tile_y)).id) {
                        .air => {
                            const tile = chnk.tile(.floor, @intCast(tile_x), @intCast(tile_y));

                            drawTexture(tile.texture(), .{
                                .x = @intCast((x * engine.Tile.size) - remaining_x + screen_mod_x - (engine.Tile.size / 2)),
                                .y = @intCast(y * engine.Tile.size - remaining_y + screen_mod_y + 4 + (engine.Tile.size / 2)),
                            }, rl.Color.light_gray);
                        },
                        else => {
                            if (y_pos >= engine.screen_height / 2) continue;

                            const tile = chnk.tile(.wall, @intCast(tile_x), @intCast(tile_y));

                            drawTexture(tile.texture(), .{
                                .x = @intCast((x * engine.Tile.size) - remaining_x + screen_mod_x - (engine.Tile.size / 2)),
                                .y = @intCast(y * engine.Tile.size - remaining_y + screen_mod_y - 4 + (engine.Tile.size / 2)),
                            }, rl.Color.white);
                        },
                    }
                }
            }
        }

        // Draw player in the center of the screen
        drawTextureRect(
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
            .white,
        );

        // Now draw all raised engine.tiles that sit above the player in front to give
        // an illusion of depth
        x = -1;
        y = -3;
        while (y * engine.Tile.size <= engine.screen_height) : (y += 1) {
            x = -1;
            while (x * engine.Tile.size <= engine.screen_width + engine.Tile.size) : (x += 1) {
                for (&engine.chunks) |*chnk| {
                    const y_pos = y * engine.Tile.size - remaining_y + screen_mod_y + 12;

                    const screen_width_in_tiles = engine.screen_width / (engine.Tile.size * 2);
                    const screen_height_in_tiles = engine.screen_height / (engine.Tile.size * 2);

                    const tile_x = @mod(camera.pos.x + x - screen_width_in_tiles, engine.Chunk.size);
                    const tile_y = ((camera.pos.y + y) - screen_height_in_tiles - chnk.y) * engine.Chunk.size;

                    // Skip if tile not on screen
                    if (x + camera.pos.x - screen_width_in_tiles < chnk.x or
                        x + camera.pos.x - screen_width_in_tiles >= chnk.x + engine.Chunk.size or
                        y + camera.pos.y - screen_height_in_tiles < chnk.y or
                        y + camera.pos.y - screen_height_in_tiles >= chnk.y + engine.Chunk.size) continue;

                    if (tile_x + tile_y < 0 or tile_x + tile_y > engine.Chunk.size * engine.Chunk.size) continue;

                    // Only draw raised engine.tiles
                    if (chnk.tile(.wall, @intCast(tile_x), @intCast(tile_y)).id == .air) continue;

                    if (y_pos >= engine.screen_height / 2) {
                        const tile = chnk.tile(.wall, @intCast(tile_x), @intCast(tile_y));

                        drawTexture(tile.texture(), .{
                            .x = @intCast((x * engine.Tile.size) - remaining_x + screen_mod_x - (engine.Tile.size / 2)),
                            .y = @intCast(y * engine.Tile.size - remaining_y + screen_mod_y - 4 + (engine.Tile.size / 2)),
                        }, .white);
                    }
                }
            }
        }
    }
};

const DebugMenu = struct {
    enabled: bool = false,

    x: f32 = 0,
    y: f32 = 0,
    player: *engine.Player,

    fn draw(menu: *DebugMenu, allocator: std.mem.Allocator) !void {
        // Print debug menu
        const string = try std.fmt.allocPrintZ(
            allocator,
            \\YABG {?s} {d}.{d}.{d}
            \\FPS: {d}; (vsync)
            \\
            \\X:{d:>3}
            \\Y:{d:>3}
            \\
            \\Built with Zig {d}.{d}.{d}
        ,
            .{
                engine.version.pre,
                engine.version.major,
                engine.version.minor,
                engine.version.patch,
                engine.getFps(),
                menu.player.entity.pos.x,
                menu.player.entity.pos.y,
                builtin.zig_version.major,
                builtin.zig_version.minor,
                builtin.zig_version.patch,
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
            rl.Color.white,
        );
    }
};

var debug_button_pressed: bool = false;

pub fn onEveryTick() !void {
    //std.debug.print("debug {}\n", .{debug_button_pressed});

    const debug_button_pressed_last_tick = debug_button_pressed;

    if (rl.isKeyDown(.f3) or rl.isGamepadButtonDown(0, .middle_left)) {
        debug_button_pressed = !debug_button_pressed_last_tick;
    }

    if (debug_button_pressed_last_tick != debug_button_pressed) {
        debug_menu.enabled = !debug_menu.enabled;
    }
}

pub fn onEveryFrame(allocator: std.mem.Allocator) !void {
    var arena_allocator = std.heap.ArenaAllocator.init(allocator);
    defer arena_allocator.deinit();

    rl.beginDrawing();
    rl.clearBackground(rl.Color.black);

    // Tile coordinate of player
    var x_num = player.entity.pos.x;
    var y_num = player.entity.pos.y;

    if (player.entity.remaining_x < 0) {
        x_num -= 1;
    }

    if (player.entity.remaining_y < 0) {
        y_num -= 1;
    }

    const camera = Camera{
        .pos = .{ .x = x_num, .y = y_num},

        .sub_pos_x = @mod(1 - player.entity.remaining_x, 1),
        .sub_pos_y = @mod(1 - player.entity.remaining_y, 1)
    };

    try camera.draw();

    if (debug_menu.enabled) {
        // Collision area around player's feet
        ui.drawRect(.{
            .x = @intCast((engine.screen_width / 2) - 6),
            .y = @intCast((engine.screen_height / 2) + 7),
            .w = 12,
            .h = 12,
        }, .{ .r = 255, .g = 0, .b = 255, .a = 0x60 });

        try debug_menu.draw(arena_allocator.allocator());
    }

    try drawHotbar(arena_allocator.allocator());
}

fn mainLoop(allocator: std.mem.Allocator) !void {
    engine.delta = rl.getFrameTime();

    engine.screen_width = @divTrunc(
        @as(u15, @intCast(rl.getScreenWidth())),
        engine.scale,
    );

    engine.screen_height = @divTrunc(
        @as(u15, @intCast(rl.getScreenHeight())),
        engine.scale,
    );

    player.updatePlayerFrames();
    player.reloadChunks();

    player.updateAnimation();

    try player.updateState();

    //const remaining_x_mask: i32 = @intFromFloat(engine.Tile.size - player.entity.remaining_x);
    //const remaining_y_mask: i32 = @intFromFloat(engine.Tile.size - player.entity.remaining_y);

    try onEveryFrame(allocator);



    //const hotbar_y: i16 = @intCast(engine.screen_height - 17);

//    try ui.drawText(
//        ">This will be a chat...\n>More chat",
//        .{
//            .x = 2,
//            .y = hotbar_y - 4,
//        },
//        .white,
//    );

    rl.endDrawing();

}

fn drawHotbar(allocator: std.mem.Allocator) !void {
    const hotbar_item_width = 16;
    const hotbar_item_spacing = 1;

    const hotbar_begin = (engine.screen_width / 2) - ((hotbar_item_width + hotbar_item_spacing) * 3);
    const hotbar_y: i16 = @intCast(engine.screen_height - hotbar_item_width - hotbar_item_spacing);

    for (player.inventory.items, 0..) |maybe_item, idx| {
        const hotbar_x: i16 = @intCast(hotbar_begin + idx * (hotbar_item_width + hotbar_item_spacing));

        var tint = rl.Color.white;
        if (idx == player.inventory.selected_slot) {
            tint = .sky_blue;
        }

        drawTexture(
            engine.textures.hotbar_item,
            .{ .x = hotbar_x, .y = hotbar_y },
            tint,
        );

        const item = maybe_item orelse continue;

        drawTextureRect(
            item.value.tile.texture(),
            .{ .x = 0, .y = 0, .w = 12, .h = 12 },
            .{ .x = hotbar_x + 2, .y = hotbar_y + 2 },
            .white,
        );

        try ui.drawText(
            try std.fmt.allocPrint(allocator, "{d}", .{item.count}),
            .{
                .x = hotbar_x + 3 + @as(u15, if (item.count < 10) 3 else 0),
                .y = hotbar_y + 4,
            },
            .white,
        );
    }
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var initialization_arena = std.heap.ArenaAllocator.init(allocator);
    defer initialization_arena.deinit();

    const env_map = try std.process.getEnvMap(initialization_arena.allocator());

    try engine.init(allocator, onEveryTick);

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

    player = try engine.Player.init(allocator, save_path);
    debug_menu = DebugMenu{ .player = &player };

    debug_menu.enabled = env_map.get("DEBUG_MODE") != null;

    //var settings = Menu{ .player = &player, .texture = menu_frame_texture };

    // Create save directory if it doesn't already exist
    const cwd = std.fs.cwd();
    cwd.makePath(save_path) catch |err| {
        std.debug.print("Error creating save directory: {}", .{err});
    };

    var chunk_x = @divTrunc(player.entity.pos.x, engine.Chunk.size);
    var chunk_y = @divTrunc(player.entity.pos.y, engine.Chunk.size);

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
            engine.chunks[it] = try engine.Chunk.load(save_path, "vanilla0", x_it, y_it);
            it += 1;
        }
        y_it = @intCast(chunk_y - 1);
    }

    while (engine.shouldContinueRunning()) {
        try mainLoop(allocator);
    }

    for (engine.chunks) |chunk| {
        try chunk.save(player.save_path, "vanilla0");
    }

    try player.save();

    rl.closeWindow();
}

fn mainMenuLoop(allocator: std.mem.Allocator) !void {
    var arena_allocator = std.heap.ArenaAllocator.init(allocator);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    rl.beginDrawing();
    rl.clearBackground(rl.Color.dark_gray);

    try ui.drawText(
        try std.fmt.allocPrint(arena, "YABG {?s} {d}.{d}.{d}", .{
            engine.version.pre,
            engine.version.major,
            engine.version.minor,
            engine.version.patch,
        }),
        .{ .x = 2, .y = 2 },
        rl.Color.white,
    );

    try ui.button("Save 1", .{ .x = 2, .y = 40, .w = 38, .h = 17 });

    rl.endDrawing();
}

fn drawTexture(texture: rl.Texture, pos: ui.NewVec, tint: rl.Color) void {
    rl.drawTextureEx(
        texture,
        .{
            .x = @floatFromInt(pos.x * engine.scale),
            .y = @floatFromInt(pos.y * engine.scale),
        },
        0,
        @floatFromInt(engine.scale),
        tint,
    );
}

fn drawTextureRect(texture: rl.Texture, rect: ui.Rectangle, pos: ui.NewVec, tint: rl.Color) void {
    rl.drawTexturePro(
        texture,
        .{
            .x = @as(f32, @floatFromInt(rect.x)),
            .y = @as(f32, @floatFromInt(rect.y)),
            .width = @as(f32, @floatFromInt(rect.w)),
            .height = @as(f32, @floatFromInt(rect.h)),
        },
        .{
            .x = @floatFromInt(pos.x * engine.scale),
            .y = @floatFromInt(pos.y * engine.scale),
            .width = @floatFromInt(rect.w * engine.scale),
            .height = @floatFromInt(rect.h * engine.scale),
        },
        .{ .x = 0, .y = 0 },
        0,
        tint,
    );
}
