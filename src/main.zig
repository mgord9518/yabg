const rl = @import("raylib");
const std = @import("std");
const fmt = std.fmt;
const print = std.debug.print;
const fs = std.fs;

const chunk = @import("Chunk.zig");
const Chunk = chunk.Chunk;

var scale: f32 = 6;
// Set game ticks per second
const tps = 30;
//const Chunk.size = 24;

//var screenWidth:  i32  = 240;
//var screenHeight: i32 = 160;
var screenWidth: f32 = 160;
var screenHeight: f32 = 144;
const title = "Yet Another Block Game (YABG)";
const id = "io.github.mgord9518.yabg";
var delta: f32 = 0;
//var chunks_generated: i32 = 0;
var tiles: [256]rl.Texture = undefined;
var pixel_snap: bool = false;
var font: rl.Font = undefined;

var chunks: [9]Chunk = undefined;

const Direction = enum {
    Left,
    Right,
    Up,
    Down,
};

fn inputDirection(direction: Direction) bool {
    // const axis_threashold = 0.1;

    // TODO: get gamepad working
    return switch (direction) {
        .Left => rl.IsKeyDown(.KEY_A) or rl.IsGamepadButtonDown(0, .GAMEPAD_BUTTON_UNKNOWN),
        .Right => rl.IsKeyDown(.KEY_D) or rl.IsGamepadButtonDown(0, .GAMEPAD_BUTTON_MIDDLE_RIGHT),
        .Up => rl.IsKeyDown(.KEY_W),
        .Down => rl.IsKeyDown(.KEY_S),
    };
}

const Tile = struct {
    const size = 12;

    hardness: i32 = 0,
    texture: *rl.Texture = undefined,
};

const Animation = enum {
    Idle,
    WalkRight,
    WalkLeft,
    WalkDown,
    WalkUp,
};

const Player = struct {
    x: f32 = 0,
    y: f32 = 0,
    x_speed: f32 = 0,
    y_speed: f32 = 0,

    // Chunk coords, this is used to check when the player has moved over a chunk boundry
    cx: i32 = 0,
    cy: i32 = 0,

    frame: *rl.Texture = undefined,
    frames_idle: [1]rl.Texture = undefined,

    // Top-level array is the animation, 2nd is the current frame
    frames: [4][8]rl.Texture = undefined,

    frame_num: usize = 0,
    frame_sub: f32 = 0,

    animation: Animation = .Idle,

    fn updatePlayerFrames(
        player: *Player,
        frame: Animation,
    ) void {
        player.frame_sub += tps * 0.3 * delta;

        if (player.frame_sub >= 1) {
            player.frame_sub -= 1;
            player.frame_num += 1;
        }

        if (player.frame_num >= 7) {
            player.frame_num = 0;
        }

        switch (frame) {
            .Idle => player.frame = &player.frames[0][0],
            .WalkRight, .WalkLeft => {
                // Given an FPS of 60, this means that the animation will
                // update at 14 FPS

                var f: usize = 1;
                if (inputDirection(.Right)) f = 2;

                player.frame = &player.frames[f][player.frame_num];
            },
            .WalkUp => {},
            .WalkDown => player.frame = &player.frames[3][player.frame_num],
        }
    }

    // Checks and unloads any chunks not surrounding the player in a 9x9 area
    // then loads new chunks into their pointers
    // Not yet sure how robust this is
    fn reloadChunks(player: *Player) void {
        var cx_origin = @floatToInt(i32, @divTrunc(@divTrunc(player.x, Tile.size), Chunk.size));
        var cy_origin = @floatToInt(i32, @divTrunc(@divTrunc(player.y, Tile.size), Chunk.size));

        // Return if player chunk is unchanged to save from executing the for loop every frame
        if (cx_origin == player.cx and cy_origin == player.cy) {
            //     return;
        }

        if (player.x < 0) {
            cx_origin = cx_origin - 1;
        }

        if (player.y < 0) {
            cy_origin = cy_origin - 1;
        }

        player.cx = cx_origin;
        player.cy = cy_origin;

        for (chunks) |*chnk| {
            const cx = @divTrunc(chnk.x, Chunk.size);
            const cy = @divTrunc(chnk.y, Chunk.size);

            if (@divTrunc(chnk.x, Chunk.size) > cx_origin + 1) {
                chnk.* = Chunk.init("DEVTEST", "vanilla0", cx_origin - 1, cy) catch unreachable;
            } else if (@divTrunc(chnk.x, Chunk.size) < cx_origin - 1) {
                chnk.* = Chunk.init("DEVTEST", "vanilla0", cx_origin + 1, cy) catch unreachable;
            } else if (@divTrunc(chnk.y, Chunk.size) > cy_origin + 1) {
                chnk.* = Chunk.init("DEVTEST", "vanilla0", cx, cy_origin - 1) catch unreachable;
            } else if (@divTrunc(chnk.y, Chunk.size) < cy_origin - 1) {
                chnk.* = Chunk.init("DEVTEST", "vanilla0", cx, cy_origin + 1) catch unreachable;
            }
        }
    }
};

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
                menu.y += 4 * tps * delta;
            }
            if (menu.y > 0) {
                menu.y = 0;
            }
        }
        if (!menu.enabled and menu.y > menu.min_y) {
            menu.y -= 4 * tps * delta;
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
            // print("{d}\n", .{alpha});
        }

        // Draw debug menu and its shadow
        //            const menu_vec =
        rl.DrawTextEx(font, string.ptr, rl.Vector2{ .x = scale * 2, .y = scale + menu.y * scale * 0.75 }, 6 * scale, scale, rl.Color{ .r = 0, .g = 0, .b = 0, .a = @divTrunc(alpha, 3) });
        rl.DrawTextEx(font, string.ptr, rl.Vector2{ .x = scale, .y = menu.y * scale }, 6 * scale, scale, rl.Color{ .r = 192, .g = 192, .b = 192, .a = alpha });
    }
};

pub fn main() !void {
    var allocator = std.heap.page_allocator;

    const env_map = try allocator.create(std.process.EnvMap);
    env_map.* = try std.process.getEnvMap(allocator);

    // Enable vsync and resizing
    rl.SetConfigFlags(.FLAG_VSYNC_HINT);
    rl.SetConfigFlags(.FLAG_WINDOW_RESIZABLE);
    rl.SetTraceLogLevel(7);

    // Disable exit on keypress
    rl.SetExitKey(.KEY_NULL);

    // Get enviornment variables and set window size to them if they exist
    const w_env: []const u8 = env_map.get("WINDOW_WIDTH") orelse "";
    const h_env: []const u8 = env_map.get("WINDOW_HEIGHT") orelse "";
    var w = fmt.parseInt(i32, w_env, 10) catch @floatToInt(i32, screenWidth * scale);
    var h = fmt.parseInt(i32, h_env, 10) catch @floatToInt(i32, screenHeight * scale);

    // This isn't currently working correctly
    //    if (env_map.get("WINDOW_FULLSCREEN") != null) {
    //        w = 0;
    //        h = 0;
    //        if (!rl.IsWindowFullscreen()) rl.ToggleFullscreen();
    //    }

    rl.InitWindow(w, h, title);
    font = rl.LoadFont("resources/vanilla/vanilla/ui/fonts/4x8/full.fnt");

    var player = Player{};
    var menu = DebugMenu{ .player = &player };

    var hotbar_item = rl.LoadImage("resources/vanilla/vanilla/ui/hotbar_item.png");
    rl.ImageResizeNN(&hotbar_item, @floatToInt(i32, Tile.size * scale), @floatToInt(i32, Tile.size * scale));
    var hotbar_item_texture = rl.LoadTextureFromImage(hotbar_item);

    //var menu_frame = rl.LoadImage("resources/vanilla/vanilla/ui/menu.png");
    //rl.ImageResizeNN(&menu_frame, 128 * scale, 128 * scale);
    //var menu_frame_texture = rl.LoadTextureFromImage(menu_frame);

    // Init chunk array
    var it: usize = 0;
    inline for (.{ -1, 0, 1 }) |row| {
        inline for (.{ -1, 0, 1 }) |col| {
            chunks[it] = try Chunk.init("DEVTEST", "vanilla0", row, col);
            it += 1;
        }
    }

    var player_image = rl.LoadImage("resources/vanilla/vanilla/entities/players/player_down_0.png");
    rl.ImageResizeNN(&player_image, @floatToInt(i32, 12 * scale), @floatToInt(i32, 24 * scale));
    player.frames[0][0] = rl.LoadTextureFromImage(player_image);

    // Load player frames
    // TODO: get this working with bufPrint or something more efficient
    inline for (.{
        "left",
        "right",
        "down",
        //        "up",
    }) |direction, direction_enum| {
        it = 0;
        while (it < 7) {
            it += 1;
            var path = fmt.allocPrint(allocator, "resources/vanilla/vanilla/entities/players/player_{s}_{x}.png", .{ direction, it }) catch unreachable;
            var player_image1 = rl.LoadImage(path.ptr);
            rl.ImageResizeNN(&player_image1, @floatToInt(i32, 12 * scale), @floatToInt(i32, 24 * scale));
            player.frames[direction_enum + 1][it - 1] = rl.LoadTextureFromImage(player_image1);
        }
    }

    player.frame = &player.frames[1][0];

    //    rl.ImageResizeNN(&player_image1, 12*scale, 24*scale);
    //    rl.ImageResizeNN(&player_image2, 12*scale, 24*scale);

    // var fontImg = rl.LoadImage("resources/vanilla/vanilla/ui/fonts/6x12/0-7f.png");

    var grass = rl.LoadImage("resources/vanilla/vanilla/tiles/grass.png");
    rl.ImageResizeNN(&grass, @floatToInt(i32, Tile.size * scale), @floatToInt(i32, 20 * scale));
    var sand = rl.LoadImage("resources/vanilla/vanilla/tiles/sand.png");
    rl.ImageResizeNN(&sand, @floatToInt(i32, Tile.size * scale), @floatToInt(i32, 20 * scale));

    tiles[1] = rl.LoadTextureFromImage(grass);

    tiles[3] = rl.LoadTextureFromImage(sand);

    // Main game loop
    while (!rl.WindowShouldClose()) { // Detect window close button or ESC key
        //         var fps_avg: f32 = undefined;
        delta = rl.GetFrameTime();

        screenWidth = @divTrunc(@intToFloat(f32, rl.GetScreenWidth()), scale);
        screenHeight = @divTrunc(@intToFloat(f32, rl.GetScreenHeight()), scale);

        // Define our allocator,
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        var alloc = arena.allocator();

        player.updatePlayerFrames(player.animation);
        player.reloadChunks();

        // Update player coords based on keys pressed
        if (inputDirection(.Right) and inputDirection(.Down)) {
            player.animation = .WalkRight;
            player.x_speed = tps * 1.4 * delta;
            player.y_speed = tps * 1.4 * delta;
        } else if (inputDirection(.Left) and inputDirection(.Down)) {
            player.animation = .WalkLeft;
            player.x_speed = tps * -1.4 * delta;
            player.y_speed = tps * 1.4 * delta;
        } else if (inputDirection(.Right) and inputDirection(.Up)) {
            player.animation = .WalkRight;
            player.x_speed = tps * 1.4 * delta;
            player.y_speed = tps * -1.4 * delta;
        } else if (inputDirection(.Left) and inputDirection(.Up)) {
            player.animation = .WalkLeft;
            player.x_speed = tps * -1.4 * delta;
            player.y_speed = tps * -1.4 * delta;
        } else if (inputDirection(.Right)) {
            player.animation = .WalkRight;
            player.y_speed = 0;
            player.x_speed = tps * 2 * delta;
        } else if (inputDirection(.Left)) {
            player.animation = .WalkLeft;
            player.y_speed = 0;
            player.x_speed = tps * -2 * delta;
        } else if (inputDirection(.Down)) {
            player.animation = .WalkDown;
            player.y_speed = tps * 2 * delta;
            player.x_speed = 0;
        } else if (inputDirection(.Up)) {
            player.x_speed = 0;
            player.y_speed = tps * -2 * delta;
        } else {
            player.animation = .Idle;
            player.x_speed = 0;
            player.y_speed = 0;
        }

        player.x += player.x_speed;
        player.y += player.y_speed;

        if (rl.IsKeyPressed(.KEY_F3)) {
            menu.enabled = !menu.enabled;
        }

        if (rl.IsKeyPressed(.KEY_F11)) {
            //            rl.ToggleFullscreen();
        }

        var player_mod_x: i32 = undefined;
        var player_mod_y: i32 = undefined;

        // Player modulo is to draw tiles at their correct locations relative
        // to player coords.
        // Disabling pixel snap makes the motion look more fluid on >1x scaling
        // but isn't true to pixel
        if (pixel_snap) {
            player_mod_y = @mod(@floatToInt(i32, player.y), Tile.size) * @floatToInt(i32, scale);
            player_mod_x = @mod(@floatToInt(i32, player.x), Tile.size) * @floatToInt(i32, scale);
        } else {
            player_mod_y = @mod(@floatToInt(i32, player.y * scale), Tile.size * @floatToInt(i32, scale));
            player_mod_x = @mod(@floatToInt(i32, player.x * scale), Tile.size * @floatToInt(i32, scale));
        }

        if (player.y < 0 and player_mod_y == 0) {
            player_mod_y = 12 * @floatToInt(i32, scale);
        }

        if (player.x < 0 and player_mod_x == 0) {
            player_mod_x = 12 * @floatToInt(i32, scale);
        }

        // Screen modulo is to draw tiles offset depending on screen resolution
        // this only matters if the window resolution isn't a factor of 16 eg:
        // active resizing
        var screen_mod_x: i32 = @floatToInt(i32, @mod(@divTrunc(screenWidth, 2), Tile.size) * scale);
        var screen_mod_y: i32 = @floatToInt(i32, @mod(@divTrunc(screenHeight, 2), Tile.size) * scale);

        // Draw
        // rl.ClearBackground(rl.BLACK);

        //   var w: i32 = rl.GetScreenWidth();

        // Draw grass tiles
        // Start at -16

        var x_num = @floatToInt(i32, @divFloor(player.x, 12));
        const y_num = @floatToInt(i32, @divFloor(player.y, 12));

        var x: i32 = 12;
        var y: i32 = 1;

        const player_rect = rl.Rectangle{
            .x = @divTrunc(screenWidth * scale, 2) - 6 * scale,
            .y = @divTrunc(screenHeight * scale + 40 * scale, 2) - 12 * scale,
            .width = 12 * scale,
            .height = 6 * scale,
        };

        // Player collision rectangle
        var player_collision = rl.Rectangle{
            .x = 0,
            .y = 0,
            .width = 0,
            .height = 0,
        };

        //   var x_off: f32 = 0;

        // Collision detection
        while (y * Tile.size <= @floatToInt(i32, screenHeight)) : (y += 1) {
            x = 5;
            while (x * Tile.size <= @floatToInt(i32, screenWidth) + Tile.size) : (x += 1) {
                for (chunks) |chnk| {
                    const scale_i: i32 = @floatToInt(i32, scale);
                    const x_pos = @intToFloat(f32, x * Tile.size * scale_i - player_mod_x + screen_mod_x);
                    const y_pos = @intToFloat(f32, y * Tile.size * scale_i - player_mod_y + screen_mod_y + 12 * scale_i);

                    //            print("collision {d}\n", .{y_pos});

                    // 24 because its Tile.size*2
                    var tile_x = @mod(x_num + x - @floatToInt(i32, @divFloor(screenWidth, 24)), Chunk.size);
                    var tile_y = ((y_num + y) - @floatToInt(i32, @divFloor(screenHeight, 24)) - chnk.y) * Chunk.size;

                    // Check if tile is on screen
                    if (x + x_num - @floatToInt(i32, @divFloor(screenWidth, 24)) >= chnk.x and x + x_num - @floatToInt(i32, @divFloor(screenWidth, 24)) < chnk.x + Chunk.size and
                        y + y_num - @floatToInt(i32, @divFloor(screenHeight, 24)) >= chnk.y and y + y_num - @floatToInt(i32, @divFloor(screenHeight, 24)) < chnk.y + Chunk.size * 2)
                    {
                        var raised: bool = false;
                        if (tile_x + tile_y >= 0 and tile_x + tile_y < Chunk.size * Chunk.size and
                            chnk.tiles[@intCast(usize, tile_x + tile_y) + Chunk.size * Chunk.size] != 0)
                        {
                            raised = true;
                        }
                        if (!raised) {
                            continue;
                        }

                        const tile_rect = rl.Rectangle{
                            .x = x_pos,
                            .y = y_pos,
                            .width = 12 * scale,
                            .height = 12 * scale,
                        };

                        var collision: rl.Rectangle = undefined;
                        if (rl.CheckCollisionRecs(player_rect, tile_rect) and raised) {
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

        //  if (x_off > 0) {
        //        player_collision.x = x_off;
        //}
        //      rec = player_collision;

        // TODO: fix phasing through top-left and bottom-right corners
        if (player_collision.height > player_collision.width / 2) {
            if (player_collision.x == player_rect.x) {
                player.x += @fabs(player.x_speed);
            } else {
                player.x -= @fabs(player.x_speed);
            }
        } else if (player_collision.height < player_collision.width / 2) {
            if (player_collision.y == player_rect.y) {
                player.y += @fabs(player.y_speed);
            } else {
                player.y -= @fabs(player.y_speed);
            }
        } else if (player_collision.height <= player_collision.width / 2 and player_collision.height > 1 * scale) {

            //  print("HIT\n", .{});
            player.x -= player.x_speed;
            player.y -= player.y_speed;
        }

        if (pixel_snap) {
            player_mod_y = @mod(@floatToInt(i32, player.y), Tile.size) * @floatToInt(i32, scale);
            player_mod_x = @mod(@floatToInt(i32, player.x), Tile.size) * @floatToInt(i32, scale);
        } else {
            player_mod_y = @mod(@floatToInt(i32, player.y * scale), Tile.size * @floatToInt(i32, scale));
            player_mod_x = @mod(@floatToInt(i32, player.x * scale), Tile.size * @floatToInt(i32, scale));
        }

        if (player.y < 0 and player_mod_y == 0) {
            player_mod_y = 12 * @floatToInt(i32, scale);
        }

        if (player.x < 0 and player_mod_x == 0) {
            player_mod_x = 12 * @floatToInt(i32, scale);
        }

        rl.BeginDrawing();

        x = -1;
        y = -3;
        while (y * Tile.size <= @floatToInt(i32, screenHeight)) : (y += 1) {
            x = -1;
            while (x * Tile.size <= @floatToInt(i32, screenWidth) + Tile.size) : (x += 1) {
                for (chunks) |chnk| {
                    const scale_i: i32 = @floatToInt(i32, scale);
                    const x_pos = @intToFloat(f32, x * Tile.size * scale_i - player_mod_x + screen_mod_x);
                    const y_pos = @intToFloat(f32, y * Tile.size * scale_i - player_mod_y + screen_mod_y + 12 * scale_i);

                    //            print("collision {d}\n", .{y_pos});

                    var tile_x = @mod(x_num + x - @floatToInt(i32, @divFloor(screenWidth, 24)), Chunk.size);
                    var tile_y = ((y_num + y) - @floatToInt(i32, @divFloor(screenHeight, 24)) - chnk.y) * Chunk.size;

                    // Check if tile is on screen
                    if (x + x_num - @floatToInt(i32, @divFloor(screenWidth, 24)) >= chnk.x and x + x_num - @floatToInt(i32, @divFloor(screenWidth, 24)) < chnk.x + Chunk.size and
                        y + y_num - @floatToInt(i32, @divFloor(screenHeight, 24)) >= chnk.y and y + y_num - @floatToInt(i32, @divFloor(screenHeight, 24)) < chnk.y + Chunk.size * 2)
                    {

                        // Only loop through the first half of chunk tiles (floor level)
                        if (tile_x + tile_y >= 0 and tile_x + tile_y < Chunk.size * Chunk.size) {
                            // If wall level tile exists, draw it instead
                            if (chnk.tiles[@intCast(usize, tile_x + tile_y) + Chunk.size * Chunk.size] == 0) {
                                rl.DrawTextureEx(tiles[chnk.tiles[@intCast(usize, tile_x + tile_y)]], rl.Vector2{ .x = x_pos, .y = y_pos }, 0, 1, rl.LIGHTGRAY);
                            } else {
                                // Shadow
                                //                                rl.DrawTextureEx(tiles[chnk.tiles[@intCast(usize, tile_x + tile_y)]], rl.Vector2{ .x = x_pos -8, .y = y_pos - 8*@intToFloat(f32, scale) }, 0, 1, rl.GRAY);
                                rl.DrawTextureEx(tiles[chnk.tiles[@intCast(usize, tile_x + tile_y)]], rl.Vector2{ .x = x_pos, .y = y_pos - 8 * scale }, 0, 1, rl.WHITE);
                            }
                        }
                    }
                }
            }
        }

        // For debugging collision
        if (menu.enabled) {
            rl.DrawRectangleRec(player_collision, rl.RED);
        }

        // Draw player in the center of the screen
        rl.DrawTexture(player.frame.*, @floatToInt(i32, scale * @divTrunc(screenWidth, 2) - 6 * scale), @floatToInt(i32, scale * @divTrunc(screenHeight, 2) - 12 * scale), rl.WHITE);

        // Draw hotbar
        var i: f32 = 0;
        const mid = (scale * @divTrunc(screenWidth, 2) - 38 * scale);
        while (i < 6) {
            rl.DrawTexture(hotbar_item_texture, @floatToInt(i32, mid + i * scale * 13), @floatToInt(i32, scale * screenHeight - 13 * scale), rl.WHITE);
            //                                    ^average w       ^ bottom, one px space
            i += 1;
        }

        // Settings menu
        //rl.DrawTexture(menu_frame_texture, @divTrunc(screenWidth, 2) * scale - 64 * scale, @divTrunc(screenHeight, 2) * scale - 64 * scale, rl.WHITE);

        try menu.draw(&alloc);

        rl.EndDrawing();
    }

    rl.CloseWindow();
}

fn int2Dozenal(i: i32, alloc: *std.mem.Allocator) ![]u8 {
    var n = i;

    // Symbols to extend the arabic number set
    // If your font has trouble reading the last 2, they are "TURNED DIGIT 2" and
    // "TURNED DIGIT 3" from Unicode 8.
    const symbols = [_][]const u8{
        "0", "1", "2",   "3",
        "4", "5", "6",   "7",
        "8", "9", "↊", "↋",
    };

    if (n == 0) return try fmt.allocPrint(alloc.*, "0", .{});
    var num: []u8 = "";

    while (n > 0) {
        var rem = @intCast(usize, @mod(n, 12));
        num = try fmt.allocPrint(alloc.*, "{s}{s}", .{ symbols[rem], num });
        n = @divFloor(n, 12);
    }

    return num;
}
