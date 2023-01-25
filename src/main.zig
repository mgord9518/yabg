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
const Player = @import("Player.zig").Player;
const Game = @import("Game.zig").Game;

const DebugMenu = struct {
    enabled: bool = false,
    min_y: f32 = -96,

    x: f32 = 0,
    y: f32 = -96,
    player: *Player,
    //  text:    []u8,

    fn draw(menu: *DebugMenu, allocator: *std.mem.Allocator) !void {

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

        var negX = " ";
        if (menu.player.x < 0) {
            negX = "-";
        }
        var negY = " ";
        if (menu.player.y < 0) {
            negY = "-";
        }

        var px = @floatToInt(i32, menu.player.x);
        if (px < 0) {
            px *= -1;
        }
        var py = @floatToInt(i32, menu.player.y);
        if (py < 0) {
            py *= -1;
        }

        // Print debug menu
        const string = try fmt.allocPrint(
            allocator.*,
            "FPS: {s}; (vsync)\nX:{s}{s};{s}\nY:{s}{s};{s}\n\nUTF8: ᚠᚢᚦᚫᚱᚲ®ÝƒÄ{{}}~",
            .{
                try int2Dozenal(rl.GetFPS(), allocator),
                negX,
                try int2Dozenal(@divTrunc(px, Tile.size), allocator),
                try int2Dozenal(@mod(px, Tile.size), allocator),
                negY,
                try int2Dozenal(@divTrunc(py, Tile.size), allocator),
                try int2Dozenal(@mod(py, Tile.size), allocator),
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

pub fn main() !void {
    var allocator = std.heap.page_allocator;

    const env_map = try std.process.getEnvMap(allocator);

    // Enable vsync, resizing and init audio devices
    rl.SetConfigFlags(.FLAG_VSYNC_HINT);
    rl.SetConfigFlags(.FLAG_WINDOW_RESIZABLE);
    rl.SetTraceLogLevel(7);
    rl.InitAudioDevice();

    // Disable exit on keypress
    rl.SetExitKey(.KEY_NULL);

    // Determine executable directory
    // TODO: either implement for other OSes or use a library like <https://github.com/gpakosz/whereami/>
    var app_dir: []const u8 = undefined;
    switch (builtin.os.tag) {
        .linux => {
            var buf: [fs.MAX_PATH_BYTES]u8 = undefined;

            const exepath = try os.readlink("/proc/self/exe", &buf);
            const dirname = path.dirname(exepath) orelse "/";

            app_dir = try path.join(allocator, &[_][]const u8{ dirname, "../.." });
        },
        .netbsd => {
            var buf: [fs.MAX_PATH_BYTES]u8 = undefined;

            const exepath = try os.readlink("/proc/curproc/exe", &buf);
            const dirname = path.dirname(exepath) orelse "/";

            app_dir = try path.join(allocator, &[_][]const u8{ dirname, "../.." });
        },
        else => {},
    }

    // Load sounds
    Game.sounds[0] = rl.LoadSound(try path.joinZ(allocator, &[_][]const u8{ app_dir, "usr/share/io.github.mgord9518.yabg/vanilla/vanilla/audio/grass.ogg" }));

    // Get enviornment variables and set window size to them if they exist
    const w_env: []const u8 = env_map.get("WINDOW_WIDTH") orelse "";
    const h_env: []const u8 = env_map.get("WINDOW_HEIGHT") orelse "";
    const scale_env: []const u8 = env_map.get("SCALE_FACTOR") orelse "";
    const speed_env: []const u8 = env_map.get("PLAYER_SPEED") orelse "";
    var w = fmt.parseInt(i32, w_env, 10) catch @floatToInt(i32, Game.screen_width * Game.scale);
    var h = fmt.parseInt(i32, h_env, 10) catch @floatToInt(i32, Game.screen_height * Game.scale);

    const base_dirs = try BaseDirs.init(allocator, .user);

    const save_dir = try path.join(allocator, &[_][]const u8{ base_dirs.data, Game.id, "saves", "DEVTEST" });

    // Scale must be an int because fractionals cause tons of issues
    Game.scale = @floor(fmt.parseFloat(f32, scale_env) catch Game.scale);
    Player.walk_speed = fmt.parseFloat(f32, speed_env) catch Player.walk_speed;

    // This isn't currently working correctly
    //    if (env_map.get("WINDOW_FULLSCREEN") != null) {
    //        w = 0;
    //        h = 0;
    //        if (!rl.IsWindowFullscreen()) rl.ToggleFullscreen();
    //    }

    rl.InitWindow(w, h, Game.title);
    Game.font = rl.LoadFont(try path.joinZ(allocator, &[_][]const u8{ app_dir, "usr/share/io.github.mgord9518.yabg/vanilla/vanilla/ui/fonts/4x8/full.fn" }));

    var player = Player.init(save_dir);
    var menu = DebugMenu{ .player = &player };

    var hotbar_item = rl.LoadImage(try path.joinZ(allocator, &[_][]const u8{ app_dir, "usr/share/io.github.mgord9518.yabg/vanilla/vanilla/ui/hotbar_item.png" }));
    rl.ImageResizeNN(&hotbar_item, @floatToInt(i32, Tile.size * Game.scale), @floatToInt(i32, Tile.size * Game.scale));
    var hotbar_item_texture = rl.LoadTextureFromImage(hotbar_item);

    //var menu_frame = rl.LoadImage("share/io.github.mgord9518.yabg/vanilla/vanilla/ui/menu.png");
    //rl.ImageResizeNN(&menu_frame, 128 * Game.scale, 128 * Game.scale);
    //var menu_frame_texture = rl.LoadTextureFromImage(menu_frame);

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
            Game.chunks[it] = try Chunk.init(save_dir, "vanilla0", row, col);
            it += 1;
        }
    }

    var player_image = rl.LoadImage(try path.joinZ(allocator, &[_][]const u8{ app_dir, "usr/share/io.github.mgord9518.yabg/vanilla/vanilla/entities/players/player_down_0.png" }));
    rl.ImageResizeNN(&player_image, @floatToInt(i32, 12 * Game.scale), @floatToInt(i32, 24 * Game.scale));

    player.frames[0][0] = rl.LoadTextureFromImage(player_image);
    player.frame = &player.frames[0][0];

    // Load player frames
    // TODO: implement as spritesheets
    inline for (.{
        "left",
        "right",
        "down",
        "up",
    }) |direction, direction_enum| {
        it = 0;
        while (it <= 7) {
            var img_path = try fmt.allocPrint(allocator, "{s}/usr/share/io.github.mgord9518.yabg/vanilla/vanilla/entities/players/player_{s}_{x}.png", .{ app_dir, direction, it });
            var player_image1 = rl.LoadImage(img_path.ptr);
            rl.ImageResizeNN(&player_image1, @floatToInt(i32, 12 * Game.scale), @floatToInt(i32, 24 * Game.scale));
            player.frames[direction_enum + 1][it] = rl.LoadTextureFromImage(player_image1);
            it += 1;
        }
    }

    // TODO: automatically iterate and load textures
    var grass = rl.LoadImage(try path.joinZ(allocator, &[_][]const u8{ app_dir, "usr/share/io.github.mgord9518.yabg/vanilla/vanilla/tiles/grass.png" }));
    rl.ImageResizeNN(&grass, @floatToInt(i32, Tile.size * Game.scale), @floatToInt(i32, 20 * Game.scale));
    var sand = rl.LoadImage("usr/share/io.github.mgord9518.yabg/vanilla/vanilla/tiles/sand.png");
    rl.ImageResizeNN(&sand, @floatToInt(i32, Tile.size * Game.scale), @floatToInt(i32, 20 * Game.scale));
    var stone = rl.LoadImage("usr/share/io.github.mgord9518.yabg/vanilla/vanilla/tiles/stone.png");
    rl.ImageResizeNN(&stone, @floatToInt(i32, Tile.size * Game.scale), @floatToInt(i32, 20 * Game.scale));
    // TODO: animate water (maybe using Perlin noise?)
    var water = rl.LoadImage("usr/share/io.github.mgord9518.yabg/vanilla/vanilla/tiles/water.png");
    rl.ImageResizeNN(&water, @floatToInt(i32, Tile.size * Game.scale), @floatToInt(i32, 13 * Game.scale));

    Game.tiles[1] = rl.LoadTextureFromImage(grass);
    Game.tiles[2] = rl.LoadTextureFromImage(stone);
    Game.tiles[3] = rl.LoadTextureFromImage(sand);
    Game.tiles[4] = rl.LoadTextureFromImage(water);

    // Main game loop
    while (!rl.WindowShouldClose()) { // Detect window close button or ESC key
        Game.delta = rl.GetFrameTime();

        Game.screen_width = @divTrunc(@intToFloat(f32, rl.GetScreenWidth()), Game.scale);
        Game.screen_height = @divTrunc(@intToFloat(f32, rl.GetScreenHeight()), Game.scale);

        // Define our allocator,
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        var alloc = arena.allocator();

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
            //            player.animation = .idle;
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
            .y = @divTrunc(Game.screen_height * Game.scale + 40 * Game.scale, 2) - 12 * Game.scale,
            .width = 11 * Game.scale,
            .height = 5.5 * Game.scale,
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

        var x = @floatToInt(i32, Game.screen_width / Tile.size / 2) - 1;
        var y = @floatToInt(i32, Game.screen_height / Tile.size / 2) - 1;
        while (y * Tile.size <= @floatToInt(i32, Game.screen_height)) : (y += 1) {
            x = @floatToInt(i32, Game.screen_width / Tile.size / 2) - 1;
            while (x * Tile.size <= @floatToInt(i32, Game.screen_width) + Tile.size) : (x += 1) {
                for (Game.chunks) |chnk| {
                    const scale_i: i32 = @floatToInt(i32, Game.scale);
                    const x_pos = @intToFloat(f32, x * Tile.size * scale_i - player_mod_x + screen_mod_x);
                    const y_pos = @intToFloat(f32, y * Tile.size * scale_i - player_mod_y + screen_mod_y + 12 * scale_i);

                    // 24 because its Tile.size * 2
                    const tile_x = @mod(x_num + x - @floatToInt(i32, @divFloor(Game.screen_width, 24)), Chunk.size);
                    const tile_y = ((y_num + y) - @floatToInt(i32, @divFloor(Game.screen_height, 24)) - chnk.y) * Chunk.size;

                    if (tile_x + tile_y < 0) {
                        continue;
                    }

                    const tile_idx = @intCast(usize, tile_x + tile_y);

                    // Check if tile is on screen
                    if (x + x_num - @floatToInt(i32, @divFloor(Game.screen_width, 24)) >= chnk.x and
                        x + x_num - @floatToInt(i32, @divFloor(Game.screen_width, 24)) < chnk.x + Chunk.size and
                        y + y_num - @floatToInt(i32, @divFloor(Game.screen_height, 24)) >= chnk.y and
                        y + y_num - @floatToInt(i32, @divFloor(Game.screen_height, 24)) < chnk.y + Chunk.size)
                    {
                        if (tile_idx >= Chunk.size * Chunk.size or
                            chnk.tiles[tile_idx + Chunk.size * Chunk.size] == 0 and chnk.tiles[tile_idx] != 4)
                        {
                            continue;
                        }

                        const tile_rect = rl.Rectangle{
                            .x = x_pos,
                            .y = y_pos,
                            .width = 12 * Game.scale,
                            .height = 12 * Game.scale,
                        };

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
        if (player_collision.height > player_collision.width / 2) {
            if (player_collision.x == player_rect.x) {
                player.x += player_collision.width / Game.scale;
            } else {
                player.x -= player_collision.width / Game.scale;
            }
        } else if (player_collision.height < player_collision.width / 2) {
            if (player_collision.y == player_rect.y) {
                player.y += player_collision.height / Game.scale;
            } else {
                player.y -= player_collision.height / Game.scale;
            }
        } else if (player_collision.height <= player_collision.width / 2 and player_collision.height > 1 * Game.scale) {
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

                    var tile_x = @mod(x_num + x - @floatToInt(i32, @divFloor(Game.screen_width, 24)), Chunk.size);
                    var tile_y = ((y_num + y) - @floatToInt(i32, @divFloor(Game.screen_height, 24)) - chnk.y) * Chunk.size;

                    // Check if tile is on screen
                    if (x + x_num - @floatToInt(i32, @divFloor(Game.screen_width, 24)) >= chnk.x and
                        x + x_num - @floatToInt(i32, @divFloor(Game.screen_width, 24)) < chnk.x + Chunk.size and
                        y + y_num - @floatToInt(i32, @divFloor(Game.screen_height, 24)) >= chnk.y and
                        y + y_num - @floatToInt(i32, @divFloor(Game.screen_height, 24)) < chnk.y + Chunk.size)
                    {

                        // Only loop through the first half of chunk Game.tiles (floor level)
                        if (tile_x + tile_y >= 0 and tile_x + tile_y < Chunk.size * Chunk.size) {
                            // If wall level tile exists, draw it instead
                            if (chnk.tiles[@intCast(usize, tile_x + tile_y) + Chunk.size * Chunk.size] == 0) {
                                rl.DrawTextureEx(Game.tiles[chnk.tiles[@intCast(usize, tile_x + tile_y)]], rl.Vector2{ .x = x_pos, .y = y_pos }, 0, 1, rl.LIGHTGRAY);
                            } else {
                                if (y_pos < Game.screen_height * Game.scale / 2) {
                                    rl.DrawTextureEx(Game.tiles[chnk.tiles[@intCast(usize, tile_x + tile_y)]], rl.Vector2{ .x = x_pos, .y = y_pos - 8 * Game.scale }, 0, 1, rl.WHITE);
                                }
                            }
                        }
                    }
                }
            }
        }

        // Shows what Game.tiles the player is currently colliding with
        if (menu.enabled) {
            rl.DrawRectangleRec(player_collision, rl.RED);
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

                    var tile_x = @mod(x_num + x - @floatToInt(i32, @divFloor(Game.screen_width, 24)), Chunk.size);
                    var tile_y = ((y_num + y) - @floatToInt(i32, @divFloor(Game.screen_height, 24)) - chnk.y) * Chunk.size;

                    // Check if tile is on screen
                    if (x + x_num - @floatToInt(i32, @divFloor(Game.screen_width, 24)) >= chnk.x and
                        x + x_num - @floatToInt(i32, @divFloor(Game.screen_width, 24)) < chnk.x + Chunk.size and
                        y + y_num - @floatToInt(i32, @divFloor(Game.screen_height, 24)) >= chnk.y and
                        y + y_num - @floatToInt(i32, @divFloor(Game.screen_height, 24)) < chnk.y + Chunk.size)
                    {
                        // Only draw raised Game.tiles
                        if (chnk.tiles[@intCast(usize, tile_x + tile_y) + Chunk.size * Chunk.size] != 0) {
                            if (y_pos >= Game.screen_height * Game.scale / 2) {
                                rl.DrawTextureEx(Game.tiles[chnk.tiles[@intCast(usize, tile_x + tile_y)]], rl.Vector2{ .x = x_pos, .y = y_pos - 8 * Game.scale }, 0, 1, rl.WHITE);
                            }
                        }
                    }
                }
            }
        }

        // Draw hotbar
        var i: f32 = 0;
        const mid = (Game.scale * @divTrunc(Game.screen_width, 2) - 38 * Game.scale);
        while (i < 6) {
            rl.DrawTexture(hotbar_item_texture, @floatToInt(i32, mid + i * Game.scale * 13), @floatToInt(i32, Game.scale * Game.screen_height - 13 * Game.scale), rl.WHITE);
            //                                    ^average w       ^ bottom, one px space
            i += 1;
        }

        // Draw debug menu
        try menu.draw(&alloc);

        rl.EndDrawing();
    }

    rl.CloseWindow();
}

fn int2Dozenal(i: i32, alloc: *std.mem.Allocator) ![]const u8 {
    if (i == 0) return "0";

    // Symbols to extend the arabic number set
    // If your font has trouble reading the last 2, they are "TURNED DIGIT 2" and
    // "TURNED DIGIT 3" from Unicode 8.
    const symbols = [_][]const u8{
        "0", "1", "2",   "3",
        "4", "5", "6",   "7",
        "8", "9", "↊", "↋",
    };

    var num: []u8 = "";

    var n = i;
    while (n > 0) {
        var rem = @intCast(usize, @mod(n, 12));

        // Prepend to the existing string
        num = try fmt.allocPrint(alloc.*, "{s}{s}", .{ symbols[rem], num });
        n = @divFloor(n, 12);
    }

    return num;
}
