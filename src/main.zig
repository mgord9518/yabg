const rl = @import("raylib");
const std = @import("std");
const builtin = @import("builtin");
const known_folders = @import("known-folders");

const Chunk = @import("Chunk.zig");
const Tile = @import("Tile.zig").Tile;
const Player = @import("Player.zig");
const engine = @import("engine/init.zig");

const ui = engine.ui;

const ChatLog = struct {
    text: std.ArrayList(u8),
};

const Menu = struct {
    enabled: bool = false,

    x: f32 = 0,
    y: f32 = 0,

    player: *Player,
    texture: rl.Texture2D,

    fn draw(menu: *Menu, allocator: std.mem.Allocator) !void {
        _ = allocator;

        const pos = rl.Vector2{
            .x = engine.scale * @divTrunc(engine.screen_width, 2) - 64 * engine.scale + menu.x * engine.scale,
            .y = engine.scale * @divTrunc(engine.screen_height, 2) - 64 * engine.scale + menu.y * engine.scale,
        };

        rl.drawTextureV(menu.texture, pos, rl.Color.white);
    }
};

const DebugMenu = struct {
    enabled: bool = false,

    x: f32 = 0,
    y: f32 = 0,
    player: *Player,

    fn draw(menu: *DebugMenu, allocator: std.mem.Allocator) !void {
        var x_num: i32 = @intFromFloat(@divTrunc(menu.player.entity.x + (Tile.size / 2), Tile.size));
        var y_num: i32 = @intFromFloat(@divTrunc(menu.player.entity.y + (Tile.size / 2), Tile.size));

        if (menu.player.entity.x < 0) {
            x_num = @intFromFloat(@divTrunc(menu.player.entity.x - (Tile.size / 2), Tile.size));
        }

        if (menu.player.entity.y < 0) {
            y_num = @intFromFloat(@divTrunc(menu.player.entity.y - (Tile.size / 2), Tile.size));
        }

        // Print debug menu
        const string = try std.fmt.allocPrintZ(
            allocator,
            \\YABG {?s} {d}.{d}.{d}
            \\FPS: {s}; (vsync)
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
                try int2Dozenal(rl.getFPS(), allocator),
                x_num,
                y_num,
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

const PathBuilder = struct {
    allocator: std.mem.Allocator,
    base: [:0]const u8,

    pub fn init(allocator: std.mem.Allocator, base: [:0]const u8) PathBuilder {
        return PathBuilder{ .allocator = allocator, .base = base };
    }

    pub fn join(self: *const PathBuilder, p: [:0]const u8) [:0]const u8 {
        return std.fs.path.joinZ(self.allocator, &[_][]const u8{ self.base, p }) catch unreachable;
    }
};

fn loadTextureFallback(img_path: [:0]const u8) !rl.Texture2D {
    const img = try rl.loadImage(img_path);
    const data_maybe: ?*anyopaque = @ptrCast(img.data);
    if (data_maybe) |_| {
        return rl.loadTextureFromImage(img);
    }

    unreachable;
}

var target_x_distance: f32 = 0;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var initialization_arena = std.heap.ArenaAllocator.init(allocator);
    defer initialization_arena.deinit();

    const env_map = try std.process.getEnvMap(initialization_arena.allocator());

    const scale_i: i32 = @intFromFloat(engine.scale);
    var width_i: u31 = @intFromFloat(engine.screen_width);
    var height_i: u31 = @intFromFloat(engine.screen_height);

    try engine.init(allocator);

    const speed_env: []const u8 = env_map.get("PLAYER_SPEED") orelse "";
    Player.walk_speed = std.fmt.parseFloat(f32, speed_env) catch Player.walk_speed;

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

    var player = try Player.init(allocator, save_path);
    var menu = DebugMenu{ .player = &player };

    menu.enabled = env_map.get("DEBUG_MODE") != null;

    const hotbar_item_texture = engine.loadTextureEmbedded("ui/hotbar_item");

    //var settings = Menu{ .player = &player, .texture = menu_frame_texture };

    // Create save directory if it doesn't already exist
    const cwd = std.fs.cwd();
    cwd.makePath(save_path) catch |err| {
        std.debug.print("Error creating save directory: {}", .{err});
    };

    var chunk_x = @as(i32, @intFromFloat(@divTrunc(@divTrunc(player.entity.x, Tile.size), Chunk.size)));
    var chunk_y = @as(i32, @intFromFloat(@divTrunc(@divTrunc(player.entity.y, Tile.size), Chunk.size)));

    if (player.entity.x < 0) {
        chunk_x = chunk_x - 1;
    }

    if (player.entity.y < 0) {
        chunk_y = chunk_y - 1;
    }

    // Init chunk array
    // TODO: lower this number to 4 to so that less iterations have to be done
    var x_it = chunk_x - 1;
    var y_it = chunk_y - 1;
    var it: usize = 0;
    while (x_it <= chunk_x + 1) : (x_it += 1) {
        while (y_it <= chunk_y + 1) : (y_it += 1) {
            engine.chunks[it] = try Chunk.load(save_path, "vanilla0", x_it, y_it);
            it += 1;
        }
        y_it = chunk_y - 1;
    }

    // Main game loop
    while (!rl.windowShouldClose()) {
        var arena_allocator = std.heap.ArenaAllocator.init(allocator);
        defer arena_allocator.deinit();
        const arena = arena_allocator.allocator();

        if (false) {
            try mainMenuLoop(allocator);
            continue;
        }

        engine.delta = rl.getFrameTime();

        engine.screen_width = @divTrunc(
            @as(f32, @floatFromInt(rl.getScreenWidth())),
            engine.scale,
        );

        engine.screen_height = @divTrunc(
            @as(f32, @floatFromInt(rl.getScreenHeight())),
            engine.scale,
        );

        width_i = @intFromFloat(engine.screen_width);
        height_i = @intFromFloat(engine.screen_height);

        player.updatePlayerFrames();
        player.reloadChunks();

        // Keyboard/gamepad inputs
        const input_vec = player.inputVector();

        if (input_vec.x > 0) {
            player.entity.direction = .right;
        } else if (input_vec.x < 0) {
            player.entity.direction = .left;
        } else if (input_vec.y > 0) {
            player.entity.direction = .down;
        } else if (input_vec.y < 0) {
            player.entity.direction = .up;
        }

        player.updateAnimation();

        if (rl.isKeyPressed(.f3) or rl.isGamepadButtonPressed(0, .middle_left)) {
            menu.enabled = !menu.enabled;
        }

        const player_x_i: i32 = @intFromFloat(player.entity.x * engine.scale);
        const player_y_i: i32 = @intFromFloat(player.entity.y * engine.scale);

        var player_mod_x: i32 = @mod(player_x_i, Tile.size * scale_i);
        var player_mod_y: i32 = @mod(player_y_i, Tile.size * scale_i);

        // Screen modulo is to draw tiles offset depending on screen resolution
        // this only matters if the window resolution isn't a factor of 16 eg:
        // active resizing
        const screen_mod_x: i32 = @intFromFloat(
            @mod(@divTrunc(engine.screen_width, 2), Tile.size),
        );

        const screen_mod_y: i32 = @intFromFloat(
            @mod(@divTrunc(engine.screen_height, 2), Tile.size),
        );

        // Collision detection
        var player_coordinate_x: i32 = @intFromFloat(@divTrunc(player.entity.x + (Tile.size / 2), Tile.size));
        var player_coordinate_y: i32 = @intFromFloat(@divTrunc(player.entity.y + (Tile.size / 2), Tile.size));

        if (player.entity.x < 0) {
            player_coordinate_x = @intFromFloat(@divTrunc(player.entity.x - (Tile.size / 2), Tile.size));
        }

        if (player.entity.y < 0) {
            player_coordinate_y = @intFromFloat(@divTrunc(player.entity.y - (Tile.size / 2), Tile.size));
        }

        var player_tile_offset_x: u16 = @intCast(@mod(player_coordinate_x, Chunk.size));
        var player_tile_offset_y: u16 = @intCast(@mod(player_coordinate_y, Chunk.size));

        // Middle chunk
        var target_chunk_num: usize = 4;

        // Find chunk player is looking at
        if (player_tile_offset_x == 0 and player.entity.direction == .left ) {
            if (player.entity.x >= 0) {
                target_chunk_num -= 1;
            }

            player_tile_offset_x = Chunk.size;
        } else if (player_tile_offset_y == 0 and player.entity.direction == .up) {
            if (player.entity.y >= 0) {
                target_chunk_num -= 3;
            }

            player_tile_offset_y = Chunk.size;
        } else if (player_tile_offset_x == 0 and player.entity.direction == .right) {
            if (player.entity.x < 0) {
                target_chunk_num += 1;
            }
        } else if (player_tile_offset_y == 0 and player.entity.direction == .down) {
            if (player.entity.y < 0) {
                target_chunk_num += 3;
            }
        }

        switch (player.entity.direction) {
            .left => player_tile_offset_x -= 1,
            .right => player_tile_offset_x += 1,
            .up => player_tile_offset_y -= 1,
            .down => player_tile_offset_y += 1,
        }

        if (player_tile_offset_x == Chunk.size and player.entity.direction == .right) {
            target_chunk_num = 5;

            player_tile_offset_x = 0;
        } else if (player_tile_offset_y == Chunk.size and player.entity.direction == .down) {
            target_chunk_num = 7;

            player_tile_offset_y = 0;
        }

        if (player_tile_offset_x == 0) {
            if (player.entity.direction == .down or player.entity.direction == .up) {
                if (player.entity.x < 0) {
                    target_chunk_num += 1;
                }
            }
        }

        if (player_tile_offset_y == 0) {
            if (player.entity.direction == .left or player.entity.direction == .right) {
                if (player.entity.y < 0) {
                    target_chunk_num += 3;
                }
            }
        }

        const target_chunk = &engine.chunks[target_chunk_num];

        std.debug.print("off {d} {d}\n", .{player_tile_offset_x, player_tile_offset_y});

        var target_tile = target_chunk.tileNew(
            .wall,
            player_tile_offset_x,
            player_tile_offset_y,
        );

        var floor_tile = target_chunk.tileNew(
            .floor,
            player_tile_offset_x,
            player_tile_offset_y,
        );

        if (rl.isKeyPressed(.period) or rl.isGamepadButtonPressed(0, .right_face_left)) {
            rl.playSound(target_tile.sound());

            // Apply damage to tile, break olnce it hits 3
            switch (target_tile.damage) {
                3 => {
                    target_tile.* = .{
                        .id = .air,
                        .damage = 0,
                        .naturally_generated = false,
                        .grade = 0,
                        .direction = .down,
                    };

                    player.inventory[0].?.count += 1;
                },

                else => {
                    target_tile.damage += 1;
                },
            }

            if (floor_tile.id == .grass and target_tile.id != .air) {
                floor_tile.id = .dirt;
            }
        }

        if (
            (rl.isKeyPressed(.slash) or rl.isGamepadButtonPressed(0, .right_face_down)) and
            @abs(player.entity.remaining_x) < 6 and
            @abs(player.entity.remaining_y) < 6
        ) {
            if (player.inventory[0]) |slot| {
                if (slot.count > 0) {
                    const temp_tile = Tile.init(.{ .id = .stone });

                    if (floor_tile.id == .water) {
                        floor_tile.* = temp_tile;
                        player.inventory[0].?.count -= 1;
                        rl.playSound(temp_tile.sound());
                    } else if (target_tile.id == .air) {
                        target_tile.* = temp_tile;
                        player.inventory[0].?.count -= 1;
                        rl.playSound(temp_tile.sound());
                    }
                } else {
                    player.inventory[0] = null;
                }
            }
        }

        if (input_vec.x != 0 and player.entity.remaining_x == 0 and player.entity.remaining_y == 0 and (target_tile.id == .air and floor_tile.id != .water)) {
            player.entity.remaining_x = Tile.size;

            if (player.entity.direction == .left) player.entity.remaining_x = -player.entity.remaining_x;
        }

        if (input_vec.y != 0 and player.entity.remaining_y == 0 and player.entity.remaining_x == 0 and (target_tile.id == .air and floor_tile.id != .water)) {
            player.entity.remaining_y = Tile.size;

            if (player.entity.direction == .up) player.entity.remaining_y = -player.entity.remaining_y;
        }

        if (player.entity.direction == .right and player.entity.remaining_x > 0 or player.entity.direction == .left and player.entity.remaining_x < 0) {
            player.entity.x_speed = engine.tps * Player.walk_speed * engine.delta;
            if (player.entity.direction == .left) player.entity.x_speed = -player.entity.x_speed;

            player.entity.remaining_x -= player.entity.x_speed;
        } else {
            player.entity.x_speed = 0;
            player.entity.x = @floatFromInt((player_coordinate_x) * Tile.size);
            player.entity.remaining_x = 0;
        }

        if (player.entity.direction == .down and player.entity.remaining_y > 0 or player.entity.direction == .up and player.entity.remaining_y < 0) {
            player.entity.y_speed = engine.tps * Player.walk_speed * engine.delta;
            if (player.entity.direction == .up) player.entity.y_speed = -player.entity.y_speed;

            player.entity.remaining_y -= player.entity.y_speed;
        } else {
            player.entity.y_speed = 0;
            player.entity.y = @floatFromInt((player_coordinate_y) * Tile.size);
            player.entity.remaining_y = 0;
        }

        if (input_vec.x == 0 and input_vec.y == 0 and player.entity.remaining_x == 0 and player.entity.remaining_y == 0) {
            player.entity.frame_num = 0;
        }

        if (target_tile.id != .air and player.entity.remaining_x == 0 and player.entity.remaining_y == 0) {
            player.entity.frame_num = 0;
        }

        var x_num: i32 = @intFromFloat(@divTrunc(player.entity.x, Tile.size));
        var y_num: i32 = @intFromFloat(@divTrunc(player.entity.y, Tile.size));

        const px: i32 = @intFromFloat(player.entity.x);
        const py: i32 = @intFromFloat(player.entity.y);

        player_mod_x = @mod(px, Tile.size);
        player_mod_y = @mod(py, Tile.size);

        player.entity.x += player.entity.x_speed;
        player.entity.y += player.entity.y_speed;

        if (player_mod_x != 0 and player.entity.x <= 0) {
            x_num -= 1;
        }

        if (player_mod_y != 0 and player.entity.y <= 0) {
            y_num -= 1;
        }

        // Offset tiles to player's feet
        player_mod_y += 3;

        rl.beginDrawing();

        rl.clearBackground(rl.Color.black);

        // TODO: refactor
        var x: i32 = (width_i / Tile.size / 2) - 2;
        var y: i32 = (height_i / Tile.size / 2) - 2;
        x = -1;
        y = -3;
        while (y * Tile.size <= height_i) : (y += 1) {
            x = -1;
            while (x * Tile.size <= width_i + Tile.size) : (x += 1) {
                for (&engine.chunks) |*chnk| {
                    const y_pos: f32 = @floatFromInt(y * Tile.size * scale_i - player_mod_y + screen_mod_y + 12 * scale_i);

                    const screen_width_in_tiles = width_i / (Tile.size * 2);
                    const screen_height_in_tiles = height_i / (Tile.size * 2);

                    const tile_x: i32 = @mod(x_num + x - screen_width_in_tiles, Chunk.size);
                    const tile_y: i32 = (y_num + y - screen_height_in_tiles - chnk.y) * Chunk.size;

                    // Skip if tile not on screen
                    if (x + x_num - screen_width_in_tiles < chnk.x or
                        x + x_num - screen_width_in_tiles >= chnk.x + Chunk.size or
                        y + y_num - screen_height_in_tiles < chnk.y or
                        y + y_num - screen_height_in_tiles >= chnk.y + Chunk.size) continue;

                    if (tile_x + tile_y < 0 or tile_x + tile_y > Chunk.size * Chunk.size) continue;

                    // Only loop through the first half of chunk engine.tiles (floor level)
                    // If wall level tile exists, draw it instead
                    switch (chnk.tile(.wall, @intCast(tile_x), @intCast(tile_y)).id) {
                        .air => {
                            const tile = chnk.tile(.floor, @intCast(tile_x), @intCast(tile_y));

                            drawTexture(tile.texture(), .{
                                .x = @intCast((x * Tile.size) - player_mod_x + screen_mod_x - (Tile.size / 2)),
                                .y = @intCast(y * Tile.size - player_mod_y + screen_mod_y + 4 + (Tile.size / 2)),
                            }, rl.Color.light_gray);
                        },
                        else => {
                            if (y_pos >= engine.screen_height * engine.scale / 2) continue;

                            const tile = chnk.tile(.wall, @intCast(tile_x), @intCast(tile_y));

                            drawTexture(tile.texture(), .{
                                .x = @intCast((x * Tile.size) - player_mod_x + screen_mod_x - (Tile.size / 2)),
                                .y = @intCast(y * Tile.size - player_mod_y + screen_mod_y - 4 + (Tile.size / 2)),
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
                .x = @as(u15, player.entity.frame_num) * 12,
                .y = 0,
                .w = 12,
                .h = 24,
            },
            .{
                .x = @intFromFloat(
                    (engine.screen_width / 2) - 5,
                ),
                .y = @intFromFloat(
                    (engine.screen_height / 2) - 10,
                ),
            },
            rl.Color.white,
        );

        // Now draw all raised engine.tiles that sit above the player in front to give
        // an illusion of depth
        x = -1;
        y = -3;
        while (y * Tile.size <= height_i) : (y += 1) {
            x = -1;
            while (x * Tile.size <= width_i + Tile.size) : (x += 1) {
                for (&engine.chunks) |*chnk| {
                    const y_pos: f32 = @floatFromInt(y * Tile.size * scale_i - player_mod_y + screen_mod_y + 12 * scale_i);

                    const screen_width_in_tiles = width_i / (Tile.size * 2);
                    const screen_height_in_tiles = height_i / (Tile.size * 2);

                    const tile_x = @mod(x_num + x - screen_width_in_tiles, Chunk.size);
                    const tile_y = ((y_num + y) - screen_height_in_tiles - chnk.y) * Chunk.size;

                    // Skip if tile not on screen
                    if (x + x_num - screen_width_in_tiles < chnk.x or
                        x + x_num - screen_width_in_tiles >= chnk.x + Chunk.size or
                        y + y_num - screen_height_in_tiles < chnk.y or
                        y + y_num - screen_height_in_tiles >= chnk.y + Chunk.size) continue;

                    if (tile_x + tile_y < 0 or tile_x + tile_y > Chunk.size * Chunk.size) continue;

                    // Only draw raised engine.tiles
                    if (chnk.tile(.wall, @intCast(tile_x), @intCast(tile_y)).id == .air) continue;

                    if (y_pos >= engine.screen_height * engine.scale / 2) {
                        const tile = chnk.tile(.wall, @intCast(tile_x), @intCast(tile_y));

                        drawTexture(tile.texture(), .{
                            .x = @intCast((x * Tile.size) - player_mod_x + screen_mod_x - (Tile.size / 2)),
                            .y = @intCast(y * Tile.size - player_mod_y + screen_mod_y - 4 + (Tile.size / 2)),
                        }, rl.Color.white);
                    }
                }
            }
        }

        // Draw hotbar
        var i: u31 = 0;
        const mid = (width_i / 2 - 35 - 15);
        const hotbar_y: i16 = @intCast(height_i - 17);
        while (i < 6) {
            const hotbar_x: i16 = @intCast(mid + i * 17);
            drawTexture(
                hotbar_item_texture,
                .{ .x = hotbar_x, .y = hotbar_y },
                rl.Color.white,
            );

            if (player.inventory[i]) |item| {
                drawTextureRect(
                    engine.tileTexture(item.value.tile),
                    .{ .x = 0, .y = 0, .w = 12, .h = 12 },
                    .{ .x = hotbar_x + 2, .y = hotbar_y + 2 },
                    rl.Color.white,
                );

                try ui.drawText(
                    try std.fmt.allocPrint(arena, "{d}", .{item.count}),
                    .{
                        .x = hotbar_x + 3 + @as(u15, if (item.count < 10) 3 else 0),
                        .y = hotbar_y + 4,
                    },
                    rl.Color.white,
                );
            }
            i += 1;
        }

        // Draw debug menu
        if (menu.enabled) {
            drawRect(.{
                .x = @intFromFloat(
                    (engine.screen_width / 2) - 6,
                ),
                .y = @intFromFloat(
                    (engine.screen_height / 2) + 7,
                ),
                .w = 12,
                .h = 12,
            }, .{ .r = 255, .g = 0, .b = 255, .a = 0x60 });
            try menu.draw(arena);
        }

//        if (settings.enabled) {
//            try settings.draw(arena);
//        }

        try ui.drawText(
            ">This will be a chat...\n>More chat",
            .{
                .x = 2,
                .y = hotbar_y - 4,
            },
            rl.Color.white,
        );

        rl.endDrawing();
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
            .x = @as(f32, @floatFromInt(pos.x)) * engine.scale,
            .y = @as(f32, @floatFromInt(pos.y)) * engine.scale,
        },
        0,
        engine.scale,
        tint,
    );
}

fn drawRect(rect: ui.Rectangle, tint: rl.Color) void {
    rl.drawRectangleRec(
        .{
            .x = @as(f32, @floatFromInt(rect.x)) * engine.scale,
            .y = @as(f32, @floatFromInt(rect.y)) * engine.scale,
            .width = @as(f32, @floatFromInt(rect.w)) * engine.scale,
            .height = @as(f32, @floatFromInt(rect.h)) * engine.scale,
        },
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
            .x = @as(f32, @floatFromInt(pos.x)) * engine.scale,
            .y = @as(f32, @floatFromInt(pos.y)) * engine.scale,
            .width = @as(f32, @floatFromInt(rect.w)) * engine.scale,
            .height = @as(f32, @floatFromInt(rect.h)) * engine.scale,
        },
        .{ .x = 0, .y = 0 },
        0,
        tint,
    );
}

fn int2Dozenal(i: isize, allocator: std.mem.Allocator) ![]const u8 {
    if (i == 0) return "0";

    // Digits to extend the arabic number set
    // If your font has trouble reading the last 2, they are "TURNED DIGIT 2"
    // and "TURNED DIGIT 3" from Unicode 8.
    const digits = [_][]const u8{
        "0", "1", "2",   "3",
        "4", "5", "6",   "7",
        "8", "9", "↊", "↋",
    };

    var buf = try allocator.alloc(u8, 32);

    var n = @abs(i);

    var idx: usize = buf.len;
    while (n > 0) {
        const rem: u16 = @intCast(@mod(n, 12));
        const digit = digits[rem];

        // As UTF8 has variable codepoint length, some digits may be longer
        // than one byte, which is the case in dozenal.
        idx -= digit.len;

        std.mem.copyForwards(u8, buf[idx..], digit);
        n = @divFloor(n, 12);
    }

    // Finally, prepend a minus symbol if the number is negative
    if (i < 0) {
        idx -= 1;
        buf[idx] = '-';
    }

    return buf[idx..];
}
