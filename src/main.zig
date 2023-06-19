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
const BaseDirs = @import("basedirs").BaseDirs;

const Chunk = @import("Chunk.zig").Chunk;
const Tile = @import("Tile.zig").Tile;
const Player = @import("Player.zig");
const Game = @import("Game.zig");

const Menu = struct {
    enabled: bool = false,
    min_y: f32 = -160,

    x: f32 = 0,
    y: f32 = -160,
    player: *Player,
    texture: rl.Texture2D,

    fn draw(menu: *Menu, allocator: std.mem.Allocator) !void {
        _ = allocator;
        // Draw debug menu
        if (menu.enabled or menu.y > menu.min_y) {
            if (menu.enabled and menu.y < 0) {
                menu.y += 8 * Game.tps * Game.delta;
            }
            if (menu.y > 0) {
                menu.y = 0;
            }
        }

        if (!menu.enabled and menu.y > menu.min_y) {
            menu.y -= 8 * Game.tps * Game.delta;
        }

        //        rl.DrawTexture(menu.texture, @floatToInt(i32, Game.scale * @divTrunc(Game.screen_width, 2) - 5.5 * Game.scale), @floatToInt(i32, Game.scale * @divTrunc(Game.screen_height, 2) - 12 * Game.scale), rl.WHITE);

        //var alpha: u8 = undefined;
        //if (menu.y < 0) alpha = @floatToInt(u8, 192 + menu.y);

        // Draw debug menu and its shadow
        //        rl.DrawTextEx(Game.font, string.ptr, rl.Vector2{ .x = Game.scale * 2, .y = Game.scale + menu.y * Game.scale * 0.75 }, 6 * Game.scale, Game.scale, rl.Color{ .r = 0, .g = 0, .b = 0, .a = @divTrunc(alpha, 3) });
        //        rl.DrawTextEx(Game.font, string.ptr, rl.Vector2{ .x = Game.scale, .y = menu.y * Game.scale }, 6 * Game.scale, Game.scale, rl.Color{ .r = 192, .g = 192, .b = 192, .a = alpha });
        const pos = rl.Vector2{
            .x = Game.scale * @divTrunc(Game.screen_width, 2) - 64 * Game.scale,
            .y = Game.scale * @divTrunc(Game.screen_height, 2) - 64 * Game.scale + menu.y * Game.scale,
        };

        rl.DrawTextureV(menu.texture, pos, rl.WHITE);
    }
};

const DebugMenu = struct {
    enabled: bool = false,
    min_y: f32 = -96,

    x: f32 = 0,
    y: f32 = -96,
    player: *Player,
    //  text:    []u8,

    fn draw(menu: *DebugMenu, allocator: std.mem.Allocator) !void {

        // Draw debug menu
        if (menu.enabled or menu.y > menu.min_y) {
            if (menu.enabled and menu.y < 0) {
                menu.y += 4 * Game.tps * Game.delta;
            }
            if (menu.y > 0) {
                menu.y = 0;
            }
        }
        if (!menu.enabled and menu.y > menu.min_y) {
            menu.y -= 4 * Game.tps * Game.delta;
        }

        const neg_x = if (menu.player.x < 0) "-" else " ";
        const neg_y = if (menu.player.y < 0) "-" else " ";

        var px = @floatToInt(i32, menu.player.x);
        if (px < 0) {
            px *= -1;
        }

        var py = @floatToInt(i32, menu.player.y);
        if (py < 0) {
            py *= -1;
        }

        // Print debug menu
        const string = try fmt.allocPrintZ(
            allocator,
            "YABG {s} {d}.{d}.{d}\n\nFPS: {s}; (vsync)\nX:{s}{s};{s}\nY:{s}{s};{s}\nchunk:{s}:{s};",
            .{
                Game.version.prefix,
                Game.version.major,
                Game.version.minor,
                Game.version.patch,
                try int2Dozenal(rl.GetFPS(), allocator),
                neg_x,
                try int2Dozenal(@divTrunc(px, Tile.size), allocator),
                try int2Dozenal(@mod(px, Tile.size), allocator),
                neg_y,
                try int2Dozenal(@divTrunc(py, Tile.size), allocator),
                try int2Dozenal(@mod(py, Tile.size), allocator),
                try int2Dozenal(menu.player.cx, allocator),
                try int2Dozenal(menu.player.cy, allocator),
            },
        );

        var alpha: u8 = undefined;
        if (menu.y < 0) {
            alpha = @floatToInt(u8, 192 + menu.y);
        }

        // Draw debug menu and its shadow
        rl.DrawTextEx(Game.font, string.ptr, rl.Vector2{ .x = Game.scale * 2, .y = Game.scale + menu.y * Game.scale * 0.75 }, 6 * Game.scale, Game.scale, rl.Color{ .r = 0, .g = 0, .b = 0, .a = @divTrunc(alpha, 3) });
        rl.DrawTextEx(Game.font, string.ptr, rl.Vector2{ .x = Game.scale, .y = menu.y * Game.scale }, 6 * Game.scale, Game.scale, rl.Color{ .r = 192, .g = 192, .b = 192, .a = alpha });
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
    var placeholder = rl.LoadImageFromMemory(".png", placeholder_data, placeholder_data.len);

    rl.ImageResizeNN(&placeholder, @floatToInt(i32, Game.scale) * placeholder.width, @floatToInt(i32, Game.scale) * placeholder.height);

    var img = rl.LoadImage(img_path.ptr);
    if (@ptrCast(?*anyopaque, img.data) == null) {
        return rl.LoadTextureFromImage(placeholder);
    }

    rl.ImageResizeNN(&img, @floatToInt(i32, Game.scale) * img.width, @floatToInt(i32, Game.scale) * img.height);

    return rl.LoadTextureFromImage(img);
}

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
    // TODO: either implement for other OSes or use a library like <https://github.com/gpakosz/whereami/>
    var app_dir: [:0]const u8 = undefined;
    switch (builtin.os.tag) {
        .linux => {
            var buf: [fs.MAX_PATH_BYTES]u8 = undefined;

            const exepath = try os.readlink("/proc/self/exe", &buf);
            const dirname = path.dirname(exepath) orelse "/";

            app_dir = try path.joinZ(allocator, &[_][]const u8{ dirname, "../.." });
        },
        .netbsd => {
            var buf: [fs.MAX_PATH_BYTES]u8 = undefined;

            const exepath = try os.readlink("/proc/curproc/exe", &buf);
            const dirname = path.dirname(exepath) orelse "/";

            app_dir = try path.joinZ(allocator, &[_][]const u8{ dirname, "../.." });
        },
        .windows => {
            var buf: [fs.MAX_PATH_BYTES]u8 = undefined;
            var buf_w: [fs.MAX_PATH_BYTES / 2]u16 = undefined;

            const exepath_w = try os.windows.GetModuleFileNameW(
                null,
                &buf_w,
                buf.len,
            );

            // Windows system calls are formatted UTF-16, so convert to UTF-8
            var it = std.unicode.Utf16LeIterator.init(exepath_w);
            var idx: usize = 0;
            while (try it.nextCodepoint()) |codepoint| {
                const len = try std.unicode.utf8Encode(codepoint, buf[idx..]);
                idx += len;
            }

            const exepath = buf[0..idx];
            const dirname = path.dirname(exepath) orelse "/";

            app_dir = try path.joinZ(allocator, &[_][]const u8{ dirname, "../.." });
        },
        else => {},
    }

    // Get enviornment variables and set window size to them if they exist
    const w_env: []const u8 = env_map.get("WINDOW_WIDTH") orelse "";
    const h_env: []const u8 = env_map.get("WINDOW_HEIGHT") orelse "";
    const scale_env: []const u8 = env_map.get("SCALE_FACTOR") orelse "";
    const speed_env: []const u8 = env_map.get("PLAYER_SPEED") orelse "";
    var w = fmt.parseInt(i32, w_env, 10) catch @floatToInt(i32, Game.screen_width * Game.scale);
    var h = fmt.parseInt(i32, h_env, 10) catch @floatToInt(i32, Game.screen_height * Game.scale);

    const base_dirs = try BaseDirs.init(allocator, .user);

    const save_dir = try path.joinZ(allocator, &[_][]const u8{ base_dirs.data, Game.id, "saves", "DEVTEST" });
    const vanilla_dir = try path.joinZ(allocator, &[_][]const u8{ app_dir, "usr/share/io.github.mgord9518.yabg/vanilla/vanilla" });

    var player = Player.init(save_dir);
    var menu = DebugMenu{ .player = &player };

    menu.enabled = env_map.get("DEBUG_MODE") != null;

    var vanilla = PathBuilder.init(allocator, vanilla_dir);

    // Scale must be an int because fractionals cause tons of issues
    Game.scale = @floor(fmt.parseFloat(f32, scale_env) catch Game.scale);
    Player.walk_speed = fmt.parseFloat(f32, speed_env) catch Player.walk_speed;

    rl.InitWindow(w, h, Game.title);

    // Disable exit on keypress
    rl.SetExitKey(.KEY_NULL);

    // Load sounds
    Tile.setSound(.grass, rl.LoadSound(vanilla.join("audio/grass.wav").ptr));
    Tile.setSound(.stone, rl.LoadSound(vanilla.join("audio/stone.wav").ptr));
    Tile.setSound(.sand, rl.LoadSound(vanilla.join("audio/sand.wav").ptr));

    Game.font = rl.LoadFont(vanilla.join("ui/fonts/4x8/full.fnt").ptr);

    var hotbar_item = rl.LoadImage(vanilla.join("ui/hotbar_item.png").ptr);
    const hotbar_item_height = hotbar_item.height * @floatToInt(i32, Game.scale);
    const hotbar_item_width = hotbar_item.width * @floatToInt(i32, Game.scale);
    rl.ImageResizeNN(&hotbar_item, hotbar_item_height, hotbar_item_width);
    var hotbar_item_texture = rl.LoadTextureFromImage(hotbar_item);

    var menu_frame = rl.LoadImage(vanilla.join("ui/menu.png").ptr);
    rl.ImageResizeNN(&menu_frame, @floatToInt(i32, 128 * Game.scale), @floatToInt(i32, 128 * Game.scale));
    var menu_frame_texture = rl.LoadTextureFromImage(menu_frame);

    var settings = Menu{ .player = &player, .texture = menu_frame_texture };

    // Create save directory if it doesn't already exist
    const cwd = fs.cwd();
    cwd.makePath(save_dir) catch |err| {
        if (err != os.MakeDirError.PathAlreadyExists) {
            print("Error creating save directory: {}", .{err});
        }
    };

    // Init chunk array
    // TODO: lower this number to 4 to so that less iterations have to be done
    var it: usize = 0;
    inline for (.{ -1, 0, 1 }) |row| {
        inline for (.{ -1, 0, 1 }) |col| {
            Game.chunks[it] = try Chunk.load(save_dir, "vanilla0", row, col);
            it += 1;
        }
    }

    var player_image = rl.LoadImage(vanilla.join("entities/players/player_down_0.png").ptr);
    rl.ImageResizeNN(&player_image, @floatToInt(i32, 12 * Game.scale), @floatToInt(i32, 24 * Game.scale));

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
            var img_path = try fmt.allocPrintZ(allocator, "{s}/usr/share/io.github.mgord9518.yabg/vanilla/vanilla/entities/players/player_{s}_{x}.png", .{ app_dir, direction, it });
            var player_image1 = rl.LoadImage(img_path.ptr);
            rl.ImageResizeNN(&player_image1, @floatToInt(i32, 12 * Game.scale), @floatToInt(i32, 24 * Game.scale));
            player.frames[direction_enum][it] = rl.LoadTextureFromImage(player_image1);
            it += 1;
        }
    }

    // TODO: automatically iterate and load textures
    var grass = loadTextureFallback(vanilla.join("tiles/grass.png"));
    var dirt = loadTextureFallback(vanilla.join("tiles/dirt.png"));
    var sand = loadTextureFallback(vanilla.join("tiles/sand.png"));
    var stone = loadTextureFallback(vanilla.join("tiles/stone.png"));
    var water = loadTextureFallback(vanilla.join("tiles/water.png"));
    var placeholder = loadTextureFallback("");

    Tile.setTexture(.grass, grass);
    Tile.setTexture(.stone, stone);
    Tile.setTexture(.dirt, dirt);
    Tile.setTexture(.sand, sand);
    Tile.setTexture(.water, water);
    Tile.setTexture(.placeholder, placeholder);

    // Main game loop
    while (!rl.WindowShouldClose()) {
        Game.delta = rl.GetFrameTime();

        Game.screen_width = @divTrunc(@intToFloat(f32, rl.GetScreenWidth()), Game.scale);
        Game.screen_height = @divTrunc(@intToFloat(f32, rl.GetScreenHeight()), Game.scale);

        // Define our allocator,
        var arena_allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena_allocator.deinit();
        var arena = arena_allocator.allocator();

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
            player.frame_num = 0;
        }

        // Update player speed based on control input
        player.x_speed = Game.tps * Player.walk_speed * Game.delta * input_vec.x;
        player.y_speed = Game.tps * Player.walk_speed * Game.delta * input_vec.y;

        player.x += player.x_speed;
        player.y += player.y_speed;

        if (rl.IsKeyPressed(.KEY_F3) or rl.IsGamepadButtonPressed(0, @intToEnum(rl.GamepadButton, 13))) {
            menu.enabled = !menu.enabled;
        }

        if (rl.IsKeyPressed(.KEY_ESCAPE)) { // or rl.IsGamepadButtonPressed(0, @intToEnum(rl.GamepadButton, 13))) {
            settings.enabled = !settings.enabled;
        }

        //if (rl.IsKeyPressed(.KEY_F11)) {
        //rl.ToggleFullscreen();
        //}

        var player_mod_x: i32 = undefined;
        var player_mod_y: i32 = undefined;

        player_mod_y = @mod(@floatToInt(i32, player.y * Game.scale), Tile.size * @floatToInt(i32, Game.scale));
        player_mod_x = @mod(@floatToInt(i32, player.x * Game.scale), Tile.size * @floatToInt(i32, Game.scale));

        if (player.y < 0 and player_mod_y == 0) {
            player_mod_y = 12 * @floatToInt(i32, Game.scale);
        }

        if (player.x < 0 and player_mod_x == 0) {
            player_mod_x = 12 * @floatToInt(i32, Game.scale);
        }

        // Screen modulo is to draw tiles offset depending on screen resolution
        // this only matters if the window resolution isn't a factor of 16 eg:
        // active resizing
        var screen_mod_x: i32 = @floatToInt(i32, @mod(@divTrunc(Game.screen_width, 2), Tile.size) * Game.scale);
        var screen_mod_y: i32 = @floatToInt(i32, @mod(@divTrunc(Game.screen_height, 2), Tile.size) * Game.scale);

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
        const x_num = @floatToInt(i32, @divFloor(player.x, 12));
        const y_num = @floatToInt(i32, @divFloor(player.y, 12));

        var x = @floatToInt(i32, Game.screen_width / Tile.size / 2) - 2;
        var y = @floatToInt(i32, Game.screen_height / Tile.size / 2) - 2;
        while (y * Tile.size <= @floatToInt(i32, Game.screen_height)) : (y += 1) {
            //if (y > @floatToInt(i32, Game.screen_height / Tile.size / 2) + 3) {
            //     break;
            //}
            x = @floatToInt(i32, Game.screen_width / Tile.size / 2) - 2;
            while (x * Tile.size <= @floatToInt(i32, Game.screen_width) + Tile.size) : (x += 1) {
                for (&Game.chunks) |*chnk| {
                    const scale_i: i32 = @floatToInt(i32, Game.scale);
                    const x_pos = @intToFloat(f32, x * Tile.size * scale_i - player_mod_x + screen_mod_x);
                    const y_pos = @intToFloat(f32, y * Tile.size * scale_i - player_mod_y + screen_mod_y + 12 * scale_i);

                    const screen_width_in_tiles = @floatToInt(i32, @divFloor(Game.screen_width, Tile.size * 2));
                    const screen_height_in_tiles = @floatToInt(i32, @divFloor(Game.screen_height, Tile.size * 2));

                    // 24 because its Tile.size * 2
                    var tile_x = @mod(x_num + x - screen_width_in_tiles, Chunk.size);
                    var tile_y = ((y_num + y) - screen_height_in_tiles - chnk.y) * Chunk.size;

                    if (tile_x + tile_y < 0) {
                        continue;
                    }

                    const tile_idx = @intCast(usize, tile_x + tile_y);

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
                                    if (wall_tile.id == .air) {
                                        chnk.tiles[tile_idx + Chunk.size * Chunk.size].id = .stone;
                                    }
                                }
                            }
                        }

                        if (tile_idx >= Chunk.size * Chunk.size or
                            wall_tile.id == .air and floor_tile.id != .water)
                        {
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

        // TODO: fix phasing through top-left and bottom-right corners
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
        } else if (player_collision.height == player_collision.width and player_collision.width > Game.scale) {
            player.x -= player.x_speed;
            player.y -= player.y_speed;
        }

        player_mod_y = @mod(@floatToInt(i32, player.y * Game.scale), Tile.size * @floatToInt(i32, Game.scale));
        player_mod_x = @mod(@floatToInt(i32, player.x * Game.scale), Tile.size * @floatToInt(i32, Game.scale));

        if (player.y < 0 and player_mod_y == 0) {
            player_mod_y = 12 * @floatToInt(i32, Game.scale);
        }

        if (player.x < 0 and player_mod_x == 0) {
            player_mod_x = 12 * @floatToInt(i32, Game.scale);
        }

        rl.BeginDrawing();

        x = -1;
        y = -3;
        while (y * Tile.size <= @floatToInt(i32, Game.screen_height)) : (y += 1) {
            x = -1;
            while (x * Tile.size <= @floatToInt(i32, Game.screen_width) + Tile.size) : (x += 1) {
                for (Game.chunks) |chnk| {
                    const scale_i: i32 = @floatToInt(i32, Game.scale);
                    const x_pos = @intToFloat(f32, x * Tile.size * scale_i - player_mod_x + screen_mod_x);
                    const y_pos = @intToFloat(f32, y * Tile.size * scale_i - player_mod_y + screen_mod_y + 12 * scale_i);

                    const screen_width_in_tiles = @floatToInt(i32, @divFloor(Game.screen_width, Tile.size * 2));
                    const screen_height_in_tiles = @floatToInt(i32, @divFloor(Game.screen_height, Tile.size * 2));

                    var tile_x = @mod(x_num + x - screen_width_in_tiles, Chunk.size);
                    var tile_y = ((y_num + y) - screen_height_in_tiles - chnk.y) * Chunk.size;

                    // Check if tile is on screen
                    if (x + x_num - screen_width_in_tiles >= chnk.x and
                        x + x_num - screen_width_in_tiles < chnk.x + Chunk.size and
                        y + y_num - screen_height_in_tiles >= chnk.y and
                        y + y_num - screen_height_in_tiles < chnk.y + Chunk.size)
                    {
                        // Only loop through the first half of chunk Game.tiles (floor level)
                        if (tile_x + tile_y >= 0 and tile_x + tile_y < Chunk.size * Chunk.size) {
                            // If wall level tile exists, draw it instead
                            if (chnk.tiles[@intCast(usize, tile_x + tile_y) + Chunk.size * Chunk.size].id == .air) {
                                const tile = chnk.tiles[@intCast(usize, tile_x + tile_y)];
                                rl.DrawTextureEx(tile.texture(), rl.Vector2{ .x = x_pos, .y = y_pos }, 0, 1, rl.LIGHTGRAY);
                            } else {
                                if (y_pos < Game.screen_height * Game.scale / 2) {
                                    //rl.DrawTextureEx(Game.tiles[@enumToInt(chnk.tiles[@intCast(usize, tile_x + tile_y)].id)], rl.Vector2{ .x = x_pos, .y = y_pos - 8 * Game.scale }, 0, 1, rl.WHITE);
                                    const tile = chnk.tiles[@intCast(usize, tile_x + tile_y) + Chunk.size * Chunk.size];
                                    rl.DrawTextureEx(tile.texture(), rl.Vector2{ .x = x_pos, .y = y_pos - 8 * Game.scale }, 0, 1, rl.WHITE);
                                }
                            }
                        }
                    }
                }
            }
        }

        // Draws a red rectangle at the player's collision rect
        if (menu.enabled) {
            rl.DrawRectangleRec(player_collision, rl.Color{ .r = 255, .g = 0, .b = 0, .a = 0x60 });
        }

        // Draw player in the center of the screen
        rl.DrawTexture(player.frame.*, @floatToInt(i32, Game.scale * @divTrunc(Game.screen_width, 2) - 5.5 * Game.scale), @floatToInt(i32, Game.scale * @divTrunc(Game.screen_height, 2) - 12 * Game.scale), rl.WHITE);

        // Now draw all raised Game.tiles that sit above the player in front to give
        // an illusion of depth
        x = -1;
        y = -3;
        while (y * Tile.size <= @floatToInt(i32, Game.screen_height)) : (y += 1) {
            x = -1;
            while (x * Tile.size <= @floatToInt(i32, Game.screen_width) + Tile.size) : (x += 1) {
                for (Game.chunks) |chnk| {
                    const scale_i: i32 = @floatToInt(i32, Game.scale);
                    const x_pos = @intToFloat(f32, x * Tile.size * scale_i - player_mod_x + screen_mod_x);
                    const y_pos = @intToFloat(f32, y * Tile.size * scale_i - player_mod_y + screen_mod_y + 12 * scale_i);

                    const screen_width_in_tiles = @floatToInt(i32, @divFloor(Game.screen_width, Tile.size * 2));
                    const screen_height_in_tiles = @floatToInt(i32, @divFloor(Game.screen_height, Tile.size * 2));

                    var tile_x = @mod(x_num + x - screen_width_in_tiles, Chunk.size);
                    var tile_y = ((y_num + y) - screen_height_in_tiles - chnk.y) * Chunk.size;

                    // Check if tile is on screen
                    if (x + x_num - screen_width_in_tiles >= chnk.x and
                        x + x_num - screen_width_in_tiles < chnk.x + Chunk.size and
                        y + y_num - screen_height_in_tiles >= chnk.y and
                        y + y_num - screen_height_in_tiles < chnk.y + Chunk.size)
                    {
                        // Only draw raised Game.tiles
                        if (chnk.tiles[@intCast(usize, tile_x + tile_y) + Chunk.size * Chunk.size].id != .air) {
                            if (y_pos >= Game.screen_height * Game.scale / 2) {
                                const tile = chnk.tiles[@intCast(usize, tile_x + tile_y) + Chunk.size * Chunk.size];
                                rl.DrawTextureEx(tile.texture(), rl.Vector2{ .x = x_pos, .y = y_pos - 8 * Game.scale }, 0, 1, rl.WHITE);
                            }
                        }
                    }
                }
            }
        }

        // Draw hotbar
        var i: f32 = 0;
        const mid = (Game.scale * @divTrunc(Game.screen_width, 2) - 35 * Game.scale);
        const hotbar_y = @floatToInt(i32, Game.scale * Game.screen_height - 13 * Game.scale);
        while (i < 6) {
            const hotbar_x = @floatToInt(i32, mid + i * Game.scale * 12);
            rl.DrawTexture(hotbar_item_texture, hotbar_x, hotbar_y, rl.WHITE);
            i += 1;
        }

        // Draw debug menu
        try menu.draw(arena);

        if (settings.enabled or settings.y > settings.min_y) {
            try settings.draw(arena);
        }

        rl.EndDrawing();
    }

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

    var n = try std.math.absInt(i);

    var idx: usize = buf.len;
    while (n > 0) {
        var rem = @intCast(usize, @mod(n, 12));
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
