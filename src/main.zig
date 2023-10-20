const rl = @import("raylib");
const toml = @import("toml");
const std = @import("std");
const os = std.os;
const fmt = std.fmt;
const print = std.debug.print;
const builtin = @import("builtin");
const fs = std.fs;
const path = fs.path;
const ChildProcess = std.ChildProcess;
const basedirs = @import("basedirs");
const BaseDirs = basedirs.BaseDirs;

const Chunk = @import("Chunk.zig");
const Tile = @import("Tile.zig").Tile;
const Player = @import("Player.zig");
const Game = @import("Game.zig");

// Helper function to draw text in the `default` style with a shadow
// Scaling is already accounted for
// `rl.startDrawing` must be called before using this function
fn drawText(
    string: []const u8,
    coords: rl.Vector2,
) !void {
    var it = std.mem.splitSequence(u8, string, "\n");

    var line_offset: f32 = 0;
    const font_size = 6;
    var buf: [4096]u8 = undefined;

    while (it.next()) |line| {
        const lineZ = try std.fmt.bufPrintZ(&buf, "{s}", .{line});

        // Shadow
        rl.DrawTextEx(
            Game.font,
            lineZ,
            rl.Vector2{
                .x = coords.x * Game.scale + Game.scale,
                .y = coords.y * Game.scale + line_offset + Game.scale,
            },
            font_size * Game.scale,
            Game.scale,
            rl.Color{
                .r = 0,
                .g = 0,
                .b = 0,
                .a = 47,
            },
        );

        rl.DrawTextEx(
            Game.font,
            lineZ,
            rl.Vector2{
                .x = coords.x * Game.scale,
                .y = coords.y * Game.scale + line_offset,
            },
            font_size * Game.scale,
            Game.scale,
            rl.Color{
                .r = 255,
                .g = 255,
                .b = 255,
                .a = 127,
            },
        );

        line_offset += font_size * Game.scale + 2 * Game.scale;
    }
}

const Menu = struct {
    enabled: bool = false,

    x: f32 = 0,
    y: f32 = 0,

    player: *Player,
    texture: rl.Texture2D,

    fn draw(menu: *Menu, allocator: std.mem.Allocator) !void {
        _ = allocator;

        const pos = rl.Vector2{
            .x = Game.scale * @divTrunc(Game.screen_width, 2) - 64 * Game.scale + menu.x * Game.scale,
            .y = Game.scale * @divTrunc(Game.screen_height, 2) - 64 * Game.scale + menu.y * Game.scale,
        };

        rl.DrawTextureV(menu.texture, pos, rl.WHITE);
    }
};

const DebugMenu = struct {
    enabled: bool = false,

    x: f32 = 0,
    y: f32 = 0,
    player: *Player,

    fn draw(menu: *DebugMenu, allocator: std.mem.Allocator) !void {
        const neg_x = if (menu.player.x < 0) "-" else " ";
        const neg_y = if (menu.player.y < 0) "-" else " ";

        var px: i32 = @intFromFloat(menu.player.x);
        if (px < 0) {
            px *= -1;
        }

        var py: i32 = @intFromFloat(menu.player.y);
        if (py < 0) {
            py *= -1;
        }

        // Print debug menu
        const string = try fmt.allocPrintZ(
            allocator,
            \\YABG {?s} {d}.{d}.{d}
            \\FPS: {s}; (vsync)
            \\
            \\X:{s}{s};{s} (chunk X: {s})
            \\Y:{s}{s};{s} (chunk Y: {s})
            \\
            \\Built with Zig {?s} {d}.{d}.{d}
        ,
            .{
                Game.version.pre,
                Game.version.major,
                Game.version.minor,
                Game.version.patch,
                try int2Dozenal(rl.GetFPS(), allocator),
                neg_x,
                try int2Dozenal(@divTrunc(px, Tile.size), allocator),
                try int2Dozenal(@mod(px, Tile.size), allocator),
                try int2Dozenal(menu.player.cx, allocator),
                neg_y,
                try int2Dozenal(@divTrunc(py, Tile.size), allocator),
                try int2Dozenal(@mod(py, Tile.size), allocator),
                try int2Dozenal(menu.player.cy, allocator),
                builtin.zig_version.pre,
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

        try drawText(
            string,
            .{
                .x = 2,
                .y = menu.y + 1,
            },
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
        return path.joinZ(self.allocator, &[_][]const u8{ self.base, p }) catch unreachable;
    }
};

fn printChunk(chunk: *const Chunk) void {
    for (chunk.tiles, 0..) |tile, idx| {
        if (idx % Chunk.size == 0) {
            std.debug.print("\n", .{});
        }

        std.debug.print("{s}", .{switch (tile.id) {
            .dirt => "**",
            .sand => "::",
            .air => "  ",
            .grass => "..",
            .water => "~~",
            .stone => "##",
            else => "??",
        }});
    }
}

fn loadTextureFallback(img_path: [:0]const u8) rl.Texture2D {
    const placeholder_data = @embedFile("embedded_files/placeholder.png");
    var placeholder = rl.LoadImageFromMemory(
        ".png",
        placeholder_data,
        placeholder_data.len,
    );

    const scale_i: i32 = @intFromFloat(Game.scale);
    rl.ImageResizeNN(
        &placeholder,
        scale_i * placeholder.width,
        scale_i * placeholder.height,
    );

    var img = rl.LoadImage(img_path.ptr);
    const data_any: ?*anyopaque = @ptrCast(img.data);
    if (data_any == null) {
        return rl.LoadTextureFromImage(placeholder);
    }

    rl.ImageResizeNN(&img, scale_i * img.width, scale_i * img.height);

    return rl.LoadTextureFromImage(img);
}

fn cursorInAttackRange() !bool {}

pub fn main() !void {
    var allocator = std.heap.page_allocator;

    const env_map = try std.process.getEnvMap(allocator);

    // Enable vsync, resizing and init audio devices
    rl.SetConfigFlags(.{
        .FLAG_VSYNC_HINT = true,
        .FLAG_WINDOW_RESIZABLE = true,
    });

    rl.SetTraceLogLevel(7);
    rl.InitAudioDevice();

    // Determine executable directory
    var exe_path_buf: [os.PATH_MAX]u8 = undefined;
    const exe_path = try std.fs.selfExePath(&exe_path_buf);

    const dirname = path.dirname(exe_path) orelse "/";
    const app_dir = try path.joinZ(allocator, &[_][]const u8{ dirname, "../.." });

    // Get enviornment variables and set window size to them if they exist
    const w_env: []const u8 = env_map.get("WINDOW_WIDTH") orelse "";
    const h_env: []const u8 = env_map.get("WINDOW_HEIGHT") orelse "";
    const scale_env: []const u8 = env_map.get("SCALE_FACTOR") orelse "";
    const speed_env: []const u8 = env_map.get("PLAYER_SPEED") orelse "";

    // Scale must be an int because fractionals cause tons of issues
    Game.scale = @floor(fmt.parseFloat(f32, scale_env) catch Game.scale);
    Player.walk_speed = fmt.parseFloat(f32, speed_env) catch Player.walk_speed;

    const scale_i: i32 = @intFromFloat(Game.scale);
    var width_i: u31 = @intFromFloat(Game.screen_width);
    var height_i: u31 = @intFromFloat(Game.screen_height);

    var w = fmt.parseInt(i32, w_env, 10) catch width_i * scale_i;
    var h = fmt.parseInt(i32, h_env, 10) catch height_i * scale_i;

    const base_dirs = try BaseDirs.init(allocator);

    const save_path = try path.joinZ(
        allocator,
        &[_][]const u8{ base_dirs.data, Game.id, "saves", "DEVTEST" },
    );

    const vanilla_dir = try path.joinZ(
        allocator,
        &[_][]const u8{ app_dir, "usr/share/io.github.mgord9518.yabg/vanilla/vanilla" },
    );

    var player = Player.init(save_path);
    var menu = DebugMenu{ .player = &player };

    menu.enabled = env_map.get("DEBUG_MODE") != null;

    var vanilla = PathBuilder.init(allocator, vanilla_dir);

    rl.InitWindow(w, h, Game.title);

    // Disable exit on keypress
    rl.SetExitKey(.KEY_NULL);

    Game.font = rl.LoadFont(vanilla.join("ui/fonts/4x8/full.fnt").ptr);

    var hotbar_item = rl.LoadImage(vanilla.join("ui/hotbar_item.png").ptr);
    const hotbar_item_height = hotbar_item.height * scale_i;
    const hotbar_item_width = hotbar_item.width * scale_i;
    rl.ImageResizeNN(&hotbar_item, hotbar_item_height, hotbar_item_width);
    var hotbar_item_texture = rl.LoadTextureFromImage(hotbar_item);

    var menu_frame = rl.LoadImage(vanilla.join("ui/menu.png").ptr);
    rl.ImageResizeNN(&menu_frame, scale_i * 128, scale_i * 128);
    var menu_frame_texture = rl.LoadTextureFromImage(menu_frame);

    var settings = Menu{ .player = &player, .texture = menu_frame_texture };

    // Create save directory if it doesn't already exist
    const cwd = fs.cwd();
    cwd.makePath(save_path) catch |err| {
        if (err != os.MakeDirError.PathAlreadyExists) {
            print("Error creating save directory: {}", .{err});
        }
    };

    // Init chunk array
    // TODO: lower this number to 4 to so that less iterations have to be done
    var it: usize = 0;
    inline for (.{ -1, 0, 1 }) |row| {
        inline for (.{ -1, 0, 1 }) |col| {
            Game.chunks[it] = try Chunk.load(save_path, "vanilla0", row, col);
            it += 1;
        }
    }

    var player_image = rl.LoadImage(vanilla.join("entities/players/player_down_0.png"));
    rl.ImageResizeNN(&player_image, scale_i * 12, scale_i * 24);

    player.frames[0][0] = rl.LoadTextureFromImage(player_image);
    player.frame = &player.frames[0][0];

    // Load player frames
    // TODO: implement as spritesheets
    inline for (.{
        "down",
        "left",
        "up",
        "right",
    }, 1..) |direction, direction_enum| {
        it = 0;
        while (it <= 7) {
            var img_path = try fmt.allocPrintZ(
                allocator,
                "{s}/usr/share/io.github.mgord9518.yabg/vanilla/vanilla/entities/players/player_{s}_{x}.png",
                .{ app_dir, direction, it },
            );

            var player_image1 = rl.LoadImage(img_path.ptr);
            rl.ImageResizeNN(&player_image1, scale_i * 12, scale_i * 24);
            player.frames[direction_enum][it] = rl.LoadTextureFromImage(player_image1);
            it += 1;
        }
    }

    inline for (.{
        "placeholder",
        "grass",
        "dirt",
        "sand",
        "stone",
        "water",
    }) |tile_name| {
        var buf: [os.PATH_MAX]u8 = undefined;
        const tile_id = std.meta.stringToEnum(
            Tile.Id,
            tile_name,
        ) orelse unreachable;

        const tile_texture = loadTextureFallback(try std.fmt.bufPrintZ(
            &buf,
            "{s}/tiles/{s}.png",
            .{
                vanilla_dir,
                tile_name,
            },
        ));

        const tile_sound = rl.LoadSound(try std.fmt.bufPrintZ(
            &buf,
            "{s}/audio/{s}.wav",
            .{
                vanilla_dir,
                tile_name,
            },
        ));

        Tile.setTexture(tile_id, tile_texture);
        Tile.setSound(tile_id, tile_sound);
    }

    // Main game loop
    while (!rl.WindowShouldClose()) {
        var arena_allocator = std.heap.ArenaAllocator.init(allocator);
        defer arena_allocator.deinit();
        var arena = arena_allocator.allocator();

        Game.delta = rl.GetFrameTime();

        Game.screen_width = @divTrunc(
            @as(f32, @floatFromInt(rl.GetScreenWidth())),
            Game.scale,
        );

        Game.screen_height = @divTrunc(
            @as(f32, @floatFromInt(rl.GetScreenHeight())),
            Game.scale,
        );

        width_i = @intFromFloat(Game.screen_width);
        height_i = @intFromFloat(Game.screen_height);

        player.updatePlayerFrames(player.animation);
        player.reloadChunks();

        // Keyboard/gamepad inputs
        const input_vec = player.inputVector();

        // update player coords based on keys pressed
        if (input_vec.x > 0) {
            player.animation = .walk_right;
        } else if (input_vec.x < 0) {
            player.animation = .walk_left;
        } else if (input_vec.y > 0) {
            player.animation = .walk_down;
        } else if (input_vec.y < 0) {
            player.animation = .walk_up;
        } else {
            // If not moving, reset animation to the start
            player.frame_num = 0;
        }

        // Update player speed based on control input
        player.x_speed = Game.tps * Player.walk_speed * Game.delta * input_vec.x;
        player.y_speed = Game.tps * Player.walk_speed * Game.delta * input_vec.y;

        player.x += player.x_speed;
        player.y += player.y_speed;

        if (rl.IsKeyPressed(.KEY_F3) or rl.IsGamepadButtonPressed(0, @enumFromInt(13))) {
            menu.enabled = !menu.enabled;
        }

        if (rl.IsKeyPressed(.KEY_ESCAPE)) { // or rl.IsGamepadButtonPressed(0, @intToEnum(rl.GamepadButton, 13))) {
            settings.enabled = !settings.enabled;
        }

        //if (rl.IsKeyPressed(.KEY_F11)) {
        //rl.ToggleFullscreen();
        //}

        const player_x_i: i32 = @intFromFloat(player.x * Game.scale);
        const player_y_i: i32 = @intFromFloat(player.y * Game.scale);

        var player_mod_x: i32 = @mod(player_x_i, Tile.size * scale_i);
        var player_mod_y: i32 = @mod(player_y_i, Tile.size * scale_i);

        if (player.y < 0 and player_mod_y == 0) {
            player_mod_y = Tile.size * scale_i;
        }

        if (player.x < 0 and player_mod_x == 0) {
            player_mod_x = Tile.size * scale_i;
        }

        // Screen modulo is to draw tiles offset depending on screen resolution
        // this only matters if the window resolution isn't a factor of 16 eg:
        // active resizing
        var screen_mod_x: i32 = @intFromFloat(
            @mod(@divTrunc(Game.screen_width, 2), Tile.size) * Game.scale,
        );

        var screen_mod_y: i32 = @intFromFloat(
            @mod(@divTrunc(Game.screen_height, 2), Tile.size) * Game.scale,
        );

        const player_rect = rl.Rectangle{
            .x = @divTrunc(Game.screen_width * Game.scale, 2) - 6 * Game.scale,
            .y = @divTrunc(Game.screen_height * Game.scale, 2) + 6 * Game.scale,
            .width = 11 * Game.scale,
            .height = 11 * Game.scale,
        };

        // Player collision rectangle
        var player_collision = rl.Rectangle{
            .x = 0,
            .y = 0,
            .width = 0,
            .height = 0,
        };

        // Collision detection
        const x_num: i32 = @intFromFloat(@divFloor(player.x, 12));
        const y_num: i32 = @intFromFloat(@divFloor(player.y, 12));

        var x: i32 = (width_i / Tile.size / 2) - 2;
        var y: i32 = (height_i / Tile.size / 2) - 2;
        while (y * Tile.size <= height_i) : (y += 1) {
            if (y > @as(i32, @intFromFloat(Game.screen_height / Tile.size / 2)) + 3) {
                break;
            }
            x = (width_i / Tile.size / 2) - 2;
            while (x * Tile.size <= width_i + Tile.size) : (x += 1) {
                for (&Game.chunks) |*chnk| {
                    const x_pos: f32 = @floatFromInt(x * Tile.size * scale_i - player_mod_x + screen_mod_x);
                    const y_pos: f32 = @floatFromInt(y * Tile.size * scale_i - player_mod_y + screen_mod_y + 12 * scale_i);

                    const screen_width_in_tiles: u31 = width_i / (Tile.size * 2);
                    const screen_height_in_tiles: u31 = height_i / (Tile.size * 2);

                    var tile_x = @mod(x_num + x - screen_width_in_tiles, Chunk.size);
                    var tile_y = ((y_num + y) - screen_height_in_tiles - chnk.y) * Chunk.size;

                    if (tile_x + tile_y < 0) {
                        continue;
                    }

                    const tile_idx: u31 = @intCast(tile_x + tile_y);

                    // Check if tile is on screen
                    if (x + x_num - screen_width_in_tiles >= chnk.x and
                        x + x_num - screen_width_in_tiles < chnk.x + Chunk.size and
                        y + y_num - screen_height_in_tiles >= chnk.y and
                        y + y_num - screen_height_in_tiles < chnk.y + Chunk.size)
                    {
                        const floor_tile = chnk.tiles[tile_idx];
                        const wall_tile = chnk.tiles[tile_idx + Chunk.size * Chunk.size];

                        const player_reach_range = 24;

                        // The reaching distance of the player
                        const player_range_rect = rl.Rectangle{
                            .x = @divTrunc(Game.screen_width * Game.scale, 2) - player_reach_range * Game.scale,
                            .y = @divTrunc(Game.screen_height * Game.scale + player_reach_range * Game.scale, 2) - player_reach_range * Game.scale,
                            .width = player_reach_range * 2 * Game.scale,
                            .height = player_reach_range * 2 * Game.scale,
                        };

                        const tile_rect = rl.Rectangle{
                            .x = x_pos,
                            .y = y_pos,
                            .width = 12 * Game.scale,
                            .height = 12 * Game.scale,
                        };

                        const tile_front_rect = switch (chnk.tiles[tile_idx + Chunk.size * Chunk.size].id) {
                            .air => rl.Rectangle{
                                .x = 0,
                                .y = 0,
                                .width = 0,
                                .height = 0,
                            },
                            else => rl.Rectangle{
                                .x = x_pos,
                                .y = y_pos - 8 * Game.scale,
                                .width = 12 * Game.scale,
                                .height = 20 * Game.scale,
                            },
                        };

                        const mouse_pos = rl.GetMousePosition();

                        _ = tile_front_rect;

                        // TODO: refactor
                        if (rl.CheckCollisionPointRec(mouse_pos, player_range_rect)) {
                            if (rl.CheckCollisionPointRec(mouse_pos, tile_rect)) {
                                // Left click breaks tile, right click places
                                if (rl.IsMouseButtonPressed(.MOUSE_BUTTON_LEFT)) {
                                    rl.PlaySound(wall_tile.sound());
                                    chnk.tiles[tile_idx + Chunk.size * Chunk.size].id = .air;
                                    if (floor_tile.id == .grass and wall_tile.id != .air) {
                                        chnk.tiles[tile_idx].id = .dirt;
                                    }
                                } else if (rl.IsMouseButtonPressed(.MOUSE_BUTTON_RIGHT)) {
                                    const stone_dummy = Tile.init(.{ .id = .stone });
                                    rl.PlaySound(stone_dummy.sound());
                                    if (floor_tile.id == .water) {
                                        chnk.tiles[tile_idx].id = .stone;
                                    } else if (wall_tile.id == .air) {
                                        chnk.tiles[tile_idx + Chunk.size * Chunk.size].id = .stone;
                                    }
                                }
                            }
                        }

                        // Change walking sound to whatever tile the player is
                        // standing on
                        // TODO: Different sounds for walking on vs placing
                        // tiles
                        const player_point = rl.Vector2{
                            .x = player_rect.x + player_rect.width / 2,
                            .y = player_rect.y + player_rect.height / 2,
                        };

                        if (rl.CheckCollisionPointRec(player_point, tile_rect)) {
                            player.standing_on = floor_tile;
                        }

                        if (wall_tile.id == .air and floor_tile.id != .water) {
                            continue;
                        }

                        var collision: rl.Rectangle = undefined;
                        if (rl.CheckCollisionRecs(player_rect, tile_rect)) {
                            collision = rl.GetCollisionRec(player_rect, tile_rect);

                            if (player_collision.x == 0) {
                                player_collision.x = collision.x;
                            }

                            if (player_collision.y == 0) {
                                player_collision.y = collision.y;
                            }

                            if (collision.y + collision.height >= player_collision.y + player_collision.height) {
                                player_collision.height = collision.y - player_collision.y + collision.height;
                            }

                            if (collision.x + collision.width >= player_collision.x + player_collision.width) {
                                player_collision.width = collision.x - player_collision.x + collision.width;
                            }

                            if (collision.x < player_collision.x) {
                                player_collision.x = collision.x;
                            }

                            if (collision.y < player_collision.y) {
                                player_collision.y = collision.y;
                            }
                        }
                    }
                }
            }
        }

        if (player_collision.height > player_collision.width) {
            if (player_collision.x == player_rect.x) {
                player.x += player_collision.width / Game.scale;
            } else {
                player.x -= player_collision.width / Game.scale;
            }
        } else if (player_collision.height < player_collision.width) {
            if (player_collision.y == player_rect.y) {
                player.y += player_collision.height / Game.scale;
            } else {
                player.y -= player_collision.height / Game.scale;
            }
        }

        const px: i32 = @intFromFloat(player.x * Game.scale);
        const py: i32 = @intFromFloat(player.y * Game.scale);

        player_mod_x = @mod(px, Tile.size * scale_i);
        player_mod_y = @mod(py, Tile.size * scale_i);

        if (player.y < 0 and player_mod_y == 0) {
            player_mod_y = Tile.size * scale_i;
        }

        if (player.x < 0 and player_mod_x == 0) {
            player_mod_x = Tile.size * scale_i;
        }

        rl.BeginDrawing();

        x = -1;
        y = -3;
        while (y * Tile.size <= height_i) : (y += 1) {
            x = -1;
            while (x * Tile.size <= width_i + Tile.size) : (x += 1) {
                for (Game.chunks) |chnk| {
                    const x_pos: f32 = @floatFromInt(x * Tile.size * scale_i - player_mod_x + screen_mod_x);
                    const y_pos: f32 = @floatFromInt(y * Tile.size * scale_i - player_mod_y + screen_mod_y + 12 * scale_i);

                    const screen_width_in_tiles = width_i / (Tile.size * 2);
                    const screen_height_in_tiles = height_i / (Tile.size * 2);

                    var tile_x: i32 = @mod(x_num + x - screen_width_in_tiles, Chunk.size);
                    var tile_y: i32 = ((y_num + y) - screen_height_in_tiles - chnk.y) * Chunk.size;

                    // Check if tile is on screen
                    if (x + x_num - screen_width_in_tiles >= chnk.x and
                        x + x_num - screen_width_in_tiles < chnk.x + Chunk.size and
                        y + y_num - screen_height_in_tiles >= chnk.y and
                        y + y_num - screen_height_in_tiles < chnk.y + Chunk.size)
                    {
                        // Only loop through the first half of chunk Game.tiles (floor level)
                        if (tile_x + tile_y >= 0 and tile_x + tile_y < Chunk.size * Chunk.size) {
                            // If wall level tile exists, draw it instead
                            if (chnk.tiles[@intCast((tile_x + tile_y) + Chunk.size * Chunk.size)].id == .air) {
                                const tile = chnk.tiles[@intCast(tile_x + tile_y)];
                                rl.DrawTextureEx(tile.texture(), rl.Vector2{
                                    .x = x_pos,
                                    .y = y_pos,
                                }, 0, 1, rl.LIGHTGRAY);
                            } else {
                                if (y_pos < Game.screen_height * Game.scale / 2) {
                                    //rl.DrawTextureEx(Game.tiles[@enumToInt(chnk.tiles[@intCast(usize, tile_x + tile_y)].id)], rl.Vector2{ .x = x_pos, .y = y_pos - 8 * Game.scale }, 0, 1, rl.WHITE);
                                    const tile = chnk.tiles[@intCast((tile_x + tile_y) + Chunk.size * Chunk.size)];
                                    rl.DrawTextureEx(tile.texture(), rl.Vector2{
                                        .x = x_pos,
                                        .y = y_pos - 8 * Game.scale,
                                    }, 0, 1, rl.WHITE);
                                }
                            }
                        }
                    }
                }
            }
        }

        // Draw player in the center of the screen
        //rl.DrawTexture(player.frame.*, @floatToInt(i32, Game.scale * @divTrunc(Game.screen_width, 2) - 5.5 * Game.scale), @floatToInt(i32, Game.scale * @divTrunc(Game.screen_height, 2) - 12 * Game.scale), rl.WHITE);
        rl.DrawTexture(
            player.frame.*,
            //@intFromFloat(Game.scale * (Game.screen_width / 2) - 5.5 * Game.scale),
            @intFromFloat(
                Game.scale * (Game.screen_width / 2) - 6 * Game.scale,
            ),
            @intFromFloat(
                Game.scale * (Game.screen_height / 2) - 10 * Game.scale,
            ),
            rl.WHITE,
        );

        // Now draw all raised Game.tiles that sit above the player in front to give
        // an illusion of depth
        x = -1;
        y = -3;
        while (y * Tile.size <= height_i) : (y += 1) {
            x = -1;
            while (x * Tile.size <= width_i + Tile.size) : (x += 1) {
                for (Game.chunks) |chnk| {
                    const x_pos: f32 = @floatFromInt(x * Tile.size * scale_i - player_mod_x + screen_mod_x);
                    const y_pos: f32 = @floatFromInt(y * Tile.size * scale_i - player_mod_y + screen_mod_y + 12 * scale_i);

                    const screen_width_in_tiles = width_i / (Tile.size * 2);
                    const screen_height_in_tiles = height_i / (Tile.size * 2);

                    var tile_x = @mod(x_num + x - screen_width_in_tiles, Chunk.size);
                    var tile_y = ((y_num + y) - screen_height_in_tiles - chnk.y) * Chunk.size;

                    // Check if tile is on screen
                    if (x + x_num - screen_width_in_tiles >= chnk.x and
                        x + x_num - screen_width_in_tiles < chnk.x + Chunk.size and
                        y + y_num - screen_height_in_tiles >= chnk.y and
                        y + y_num - screen_height_in_tiles < chnk.y + Chunk.size)
                    {
                        // Only draw raised Game.tiles
                        if (chnk.tiles[@intCast((tile_x + tile_y) + Chunk.size * Chunk.size)].id != .air) {
                            if (y_pos >= Game.screen_height * Game.scale / 2) {
                                const tile = chnk.tiles[@intCast((tile_x + tile_y) + Chunk.size * Chunk.size)];
                                rl.DrawTextureEx(tile.texture(), rl.Vector2{ .x = x_pos, .y = y_pos - 8 * Game.scale }, 0, 1, rl.WHITE);
                            }
                        }
                    }
                }
            }
        }

        // Draw hotbar
        var i: u31 = 0;
        const mid = (width_i * @divTrunc(scale_i, 2) - 35 * scale_i);
        const hotbar_y = scale_i * height_i - 13 * scale_i;
        while (i < 6) {
            const hotbar_x = mid + i * scale_i * 12;
            rl.DrawTexture(hotbar_item_texture, hotbar_x, hotbar_y, rl.WHITE);
            i += 1;
        }

        // Draw debug menu
        if (menu.enabled) {
            // Draws a red rectangle at the player's collision rect
            rl.DrawRectangleRec(player_collision, rl.Color{ .r = 255, .g = 0, .b = 0, .a = 0x60 });
            rl.DrawRectangleRec(player_rect, rl.Color{ .r = 255, .g = 0, .b = 255, .a = 0x60 });
            try menu.draw(arena);
        }

        if (settings.enabled) {
            try settings.draw(arena);
        }

        rl.EndDrawing();
    }

    for (Game.chunks) |chunk| {
        try chunk.save(player.save_path, "vanilla0");
    }

    try player.save();

    rl.CloseWindow();
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
        var rem: u16 = @intCast(@mod(n, 12));
        const digit = digits[rem];

        // As UTF8 has variable codepoint length, some digits may be longer
        // than one byte, which is the case in dozenal.
        idx -= digit.len;

        std.mem.copy(u8, buf[idx..], digit);
        n = @divFloor(n, 12);
    }

    // Finally, prepend a minus symbol if the number is negative
    if (i < 0) {
        idx -= 1;
        buf[idx] = '-';
    }

    return buf[idx..];
}
