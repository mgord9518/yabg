const rl = @import("raylib");
const std = @import("std");
const perlin = @import("perlin");
const fmt = std.fmt;
const print = std.debug.print;
const fs = std.fs;

//const Player
//var debugEnabled = false;
//var debugMenuHeight: i32 = -96;

const tileSize = 12;
const scale: i32 = 6;
// Set game ticks per second
const tps = 30;
const chunk_size = 24;

//var screenWidth:  i32  = 240;
//var screenHeight: i32 = 160;
var screenWidth: i32 = 160;
var screenHeight: i32 = 144;
const title = "Yet Another Block Game (YABG)";
const id = "io.github.mgord9518.yabg";
var delta: f32 = 0;
var chunks_generated: i32 = 0;
var tiles: [chunk_size*chunk_size]rl.Texture = undefined;
var pixel_snap: bool = false;
var font: rl.Font = undefined;


const Chunk = struct {
    x: i32,
    y: i32,
    level: i32 = 0x80,
    tiles: [chunk_size*chunk_size*2]u8 = undefined,

    fn init(save_name: []const u8, mod_pack: []const u8, x: i32, y: i32) !Chunk {
        var buf: [144]u8 = undefined;
        const string = try fmt.bufPrint(
            &buf,
            "saves/{s}/{d}_{d}.{s}",
            .{
                save_name,
                x,
                y,
                mod_pack,
            },
        );

        var chunk = Chunk{
            .x = x * chunk_size,
            .y = y * chunk_size,
        };

        // Generate chunk if unable to find file
        var f = fs.cwd().openFile(string, .{}) catch return genChunk(save_name, mod_pack, x, y);
        defer f.close();

        _ = try f.read(chunk.tiles[0..]);
        return chunk;
    }

    fn genChunk(save_name: []const u8, mod_pack: []const u8, x: i32, y: i32) !Chunk {
        var buf: [144]u8 = undefined;
        const path = try fmt.bufPrint(
            &buf,
            "saves/{s}/{d}_{d}.{s}",
            .{
                save_name,
                x,
                y,
                mod_pack,
            },
        );

//        print("GENERATING CHUNK AT {x}, {x}\n", .{x, y});
        chunks_generated += 1;

        // TODO: Save bytes to disk
        var chunk = Chunk{ .x = x * chunk_size, .y = y * chunk_size };
        var f = fs.cwd().createFile(path, .{ .read = true }) catch unreachable;

        var t_x: i32 = undefined;
        var t_y: i32 = undefined;
        // Use Perlin noise to generate the world
        for (chunk.tiles) |*tile, idx| {
            if (idx >= chunk_size*chunk_size) {
                break;
            }

            t_x = chunk.x + @intCast(i32,      @mod(idx, chunk_size));
            t_y = chunk.y + @intCast(i32, @divTrunc(idx, chunk_size));

            // TODO: Fix formatting on this
            var val = @floatToInt(u8, (1+perlin.noise3D(f64, @intToFloat(f32, t_x-100)*0.05, @intToFloat(f32, t_y)*0.05, 0))*127.5/4);
            val += @floatToInt(u8, (1+perlin.noise3D(f64, @intToFloat(f32, t_x-100)*0.05, @intToFloat(f32, t_y)*0.05, 0))*127.5/4);
            val += @floatToInt(u8, (1+perlin.noise3D(f64, @intToFloat(f32, t_x-100)*0.05, @intToFloat(f32, t_y)*0.05, 0))*127.5/4);
            val += @floatToInt(u8, (1+perlin.noise3D(f64, @intToFloat(f32, t_x-100)*0.2, @intToFloat(f32, t_y)*0.2, 0))*127.5/4);

            if (val > 170) {
                tile.* = 0x01;
                chunk.tiles[idx + chunk_size*chunk_size] = 0x01;
            } else if (val > 72) {
                tile.* = 0x01;
                chunk.tiles[idx + chunk_size*chunk_size] = 0x00;
            } else if (val > 48) {
                tile.* = 0x03;
                chunk.tiles[idx + chunk_size*chunk_size] = 0x00;
            } else {
                tile.* = 0x00;
                chunk.tiles[idx + chunk_size*chunk_size] = 0x00;
            }
        }

        _ = try f.write(&chunk.tiles);

        return chunk;
    }

};

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
    switch (direction) {
        .Left => {
            if (rl.IsKeyDown(.KEY_A) or rl.IsGamepadButtonDown(0, .GAMEPAD_BUTTON_UNKNOWN)) {
                return true;
            }
        },
        .Right => {
            if (rl.IsKeyDown(.KEY_D) or rl.IsGamepadButtonDown(0, .GAMEPAD_BUTTON_MIDDLE_RIGHT)) {
                return true;
            }
        },
        .Up => {
            if (rl.IsKeyDown(.KEY_W)) {
                return true;
            }
        },
        .Down => {
            if (rl.IsKeyDown(.KEY_S)) {
                return true;
            }
        },
    }

    //print("{d}\n", .{rl.GetGamepadAxisMovement(0, 1)});

    return false;
}

const Tile = struct {
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
    frames_right: [8]rl.Texture = undefined,
    frames_left: [8]rl.Texture = undefined,
//    frames: [Direction]rl.Texture = undefined,

    frame_num_idle: usize = 0,
    frame_num_right: usize = 0,
    frame_sub: f32 = 0,

    animation: Animation = .Idle,

    fn updatePlayerFrames(
        player: *Player,
        frame: Animation,
    ) void {
        switch (frame) {
            .Idle => {
                player.frame = &player.frames_idle[player.frame_num_idle];
            },
            .WalkRight => {
                // Given an FPS of 60, this means that the animation will
                // update at 14 FPS
                player.frame_sub += tps * 0.3 * delta;

                if (player.frame_sub >= 1) {
                    player.frame_sub -= 1;
                    player.frame_num_right += 1;
                }

                if (player.frame_num_right >= 7) {
                    player.frame_num_right = 0;
                }
                player.frame = &player.frames_right[player.frame_num_right];
            },
            .WalkLeft => {
                // Given an FPS of 60, this means that the animation will
                // update at 14 FPS
                player.frame_sub += tps * 0.3 * delta;

                if (player.frame_sub >= 1) {
                    player.frame_sub -= 1;
                    player.frame_num_right += 1;
                }

                if (player.frame_num_right >= 7) {
                    player.frame_num_right = 0;
                }
                player.frame = &player.frames_left[player.frame_num_right];
            },
            .WalkUp => {},
            .WalkDown => {},
        }
    }

    // Checks and unloads any chunks not surrounding the player in a 9x9 area
    // then loads new chunks into their pointers
    // Not yet sure how robust this is
    fn reloadChunks(player: *Player) void {
        var cx_origin = @floatToInt(i32, @divTrunc(@divTrunc(player.x, tileSize), chunk_size));
        var cy_origin = @floatToInt(i32, @divTrunc(@divTrunc(player.y, tileSize), chunk_size));

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

        for (chunks) |*chunk| {
            const cx = @divTrunc(chunk.x, chunk_size);
            const cy = @divTrunc(chunk.y, chunk_size);

            if (@divTrunc(chunk.x, chunk_size) > cx_origin + 1) {
                chunk.* = Chunk.init("DEVTEST", "vanilla0", cx_origin - 1, cy) catch unreachable;
            } else if (@divTrunc(chunk.x, chunk_size) < cx_origin - 1) {
                chunk.* = Chunk.init("DEVTEST", "vanilla0", cx_origin + 1, cy) catch unreachable;
            } else if (@divTrunc(chunk.y, chunk_size) > cy_origin + 1) {
                chunk.* = Chunk.init("DEVTEST", "vanilla0", cx, cy_origin - 1) catch unreachable;
            } else if (@divTrunc(chunk.y, chunk_size) < cy_origin - 1) {
                chunk.* = Chunk.init("DEVTEST", "vanilla0", cx, cy_origin + 1) catch unreachable;
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
                "FPS: {s}; (vsync)\nX:{s}{s};{s}\nY:{s}{s};{s}\n\nUTF8: ᚠᚢᚦᚫᚱᚲ®ÝƒÄ{{}}~\nChunks generated: {s};",
                .{
                    try int2Dozenal(rl.GetFPS(), allocator),
                    negX,
                    try int2Dozenal(@divTrunc(px, tileSize), allocator),
                    try int2Dozenal(@mod(px, tileSize), allocator),
                    negY,
                    try int2Dozenal(@divTrunc(py, tileSize), allocator),
                    try int2Dozenal(@mod(py, tileSize), allocator),
                    try int2Dozenal(chunks_generated, allocator),
                },
            );

            var alpha: u8 = undefined;
            if (menu.y < 0) {
                alpha = @floatToInt(u8, 192 + menu.y);
                // print("{d}\n", .{alpha});
            }

            // Draw debug menu and its shadow
//            const menu_vec =
            rl.DrawTextEx(font, string.ptr, rl.Vector2{ .x = scale * 2, .y = @intToFloat(f32, scale) + menu.y * @intToFloat(f32, scale) * 0.75 }, 6 * scale, scale, rl.Color{ .r = 0, .g = 0, .b = 0, .a = @divTrunc(alpha, 3) });
            rl.DrawTextEx(font, string.ptr, rl.Vector2{ .x = scale, .y = menu.y * @intToFloat(f32, scale) }, 6 * scale, scale, rl.Color{ .r = 192, .g = 192, .b = 192, .a = alpha });
    }
};

pub fn main() !void {
    // Enable vsync and resizing
    rl.SetConfigFlags(.FLAG_VSYNC_HINT);
    rl.SetConfigFlags(.FLAG_WINDOW_RESIZABLE);
    rl.InitWindow(screenWidth * scale, screenHeight * scale, title);

    font = rl.LoadFont("resources/vanilla/vanilla/ui/fonts/4x8/full.fnt");

    // Disable exit on keypress
    rl.SetExitKey(.KEY_NULL);
    // rl.SetTraceLogLevel(7);

    var player = Player{};
    var menu = DebugMenu{ .player = &player };

    var hotbar_item = rl.LoadImage("resources/vanilla/vanilla/ui/hotbar_item.png");
    rl.ImageResizeNN(&hotbar_item, tileSize * scale, tileSize * scale);
    var hotbar_item_texture = rl.LoadTextureFromImage(hotbar_item);

    //var menu_frame = rl.LoadImage("resources/vanilla/vanilla/ui/menu.png");
    //rl.ImageResizeNN(&menu_frame, 128 * scale, 128 * scale);
    //var menu_frame_texture = rl.LoadTextureFromImage(menu_frame);

    chunks[0] = try Chunk.init("DEVTEST", "vanilla0", -1, -1);
    chunks[1] = try Chunk.init("DEVTEST", "vanilla0", -1,  0);
    chunks[2] = try Chunk.init("DEVTEST", "vanilla0", -1,  1);
    chunks[3] = try Chunk.init("DEVTEST", "vanilla0",  0, -1);
    chunks[4] = try Chunk.init("DEVTEST", "vanilla0",  0,  0);
    chunks[5] = try Chunk.init("DEVTEST", "vanilla0",  0,  1);
    chunks[6] = try Chunk.init("DEVTEST", "vanilla0",  1, -1);
    chunks[7] = try Chunk.init("DEVTEST", "vanilla0",  1,  0);
    chunks[8] = try Chunk.init("DEVTEST", "vanilla0",  1,  1);

    var n: usize = 1;

    var player_image = rl.LoadImage("resources/vanilla/vanilla/entities/players/player_front.png");
    rl.ImageResizeNN(&player_image, 12 * scale, 24 * scale);
    player.frames_idle[0] = rl.LoadTextureFromImage(player_image);

    // Load player frames
    while (n < 8) {
        // TODO: get this working with bufPrint or something more efficient
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        var alloc = arena.allocator();

        // TODO: Add enum array and iterate through to load frames
        //inline for (.{
        //    .{ "right" },
        //    .{ "left" },
        //    .{ "down" },
        //    .{ "up" },
        //}) | direction | {
        var path = fmt.allocPrint(alloc, "resources/vanilla/vanilla/entities/players/player_{s}_{x}.png", .{ "right", n }) catch unreachable;
        var player_image1 = rl.LoadImage(path.ptr);
        rl.ImageResizeNN(&player_image1, 12 * scale, 24 * scale);
        player.frames_right[n - 1] = rl.LoadTextureFromImage(player_image1);
        //n = n+1;
        //}

        path = fmt.allocPrint(alloc, "resources/vanilla/vanilla/entities/players/player_{s}_{x}.png", .{ "left", n }) catch unreachable;
        var player_image2 = rl.LoadImage(path.ptr);
        rl.ImageResizeNN(&player_image2, 12 * scale, 24 * scale);
        player.frames_left[n - 1] = rl.LoadTextureFromImage(player_image2);
        n = n + 1;
    }

    //player_images = undefined;

    player.frame = &player.frames_right[0];

    //    rl.ImageResizeNN(&player_image1, 12*scale, 24*scale);
    //    rl.ImageResizeNN(&player_image2, 12*scale, 24*scale);

    // var fontImg = rl.LoadImage("resources/vanilla/vanilla/ui/fonts/6x12/0-7f.png");

    var grass = rl.LoadImage("resources/vanilla/vanilla/tiles/grass.png");
    rl.ImageResizeNN(&grass, tileSize * scale, tileSize * scale + 8 * scale);
    var sand = rl.LoadImage("resources/vanilla/vanilla/tiles/sand.png");
    rl.ImageResizeNN(&sand, tileSize * scale, tileSize * scale + 8 * scale);

    tiles[1] = rl.LoadTextureFromImage(grass);

    tiles[3] = rl.LoadTextureFromImage(sand);

    // Main game loop
    while (!rl.WindowShouldClose()) { // Detect window close button or ESC key
        //         var fps_avg: f32 = undefined;
        delta = rl.GetFrameTime();

        screenWidth = @divTrunc(rl.GetScreenWidth(), scale);
        screenHeight = @divTrunc(rl.GetScreenHeight(), scale);

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
            rl.ToggleFullscreen();
        }

        var player_mod_x: i32 = undefined;
        var player_mod_y: i32 = undefined;

        // Player modulo is to draw tiles at their correct locations relative
        // to player coords.
        // Disabling pixel snap makes the motion look more fluid on >1x scaling
        // but isn't true to pixel
        if (pixel_snap) {
            player_mod_y = @mod(@floatToInt(i32, player.y), tileSize) * scale;
            player_mod_x = @mod(@floatToInt(i32, player.x), tileSize) * scale;
        } else {
            const scale_f = @intToFloat(f32, scale);
            player_mod_y = @mod(@floatToInt(i32, player.y * scale_f), tileSize * scale);
            player_mod_x = @mod(@floatToInt(i32, player.x * scale_f), tileSize * scale);
        }

        if (player.y < 0 and player_mod_y == 0) {
            player_mod_y = 12 * scale;
        }

        // Screen modulo is to draw tiles offset depending on screen resolution
        // this only matters if the window resolution isn't a factor of 16 eg:
        // active resizing
        var screen_mod_x = @mod(@divTrunc(screenWidth, 2), tileSize) * scale;
        var screen_mod_y = @mod(@divTrunc(screenHeight, 2), tileSize) * scale;


        // Draw
       // rl.ClearBackground(rl.BLACK);

        //   var w: i32 = rl.GetScreenWidth();

        // Draw grass tiles
        // Start at -16



        var x_num = @floatToInt(i32, @divFloor(player.x, 12));
        const y_num = @floatToInt(i32, @divFloor(player.y, 12));

        var x: i32 = 12;
        var y: i32 = 1;

        var rec: rl.Rectangle = undefined;

        while (y * tileSize <= screenHeight) : (y += 1) {
            x = 5;
            while (x * tileSize <= screenWidth + tileSize) : (x += 1) {
                for (chunks) |chunk| {

                    const x_pos = @intToFloat(f32, x * tileSize * scale - player_mod_x + screen_mod_x);
                    const y_pos = @intToFloat(f32, y * tileSize * scale - player_mod_y + screen_mod_y + 12 * scale);

                //            print("collision {d}\n", .{y_pos});


                    // 24 because its tileSize*2
                    var tile_x = @mod(x_num + x - @divFloor(screenWidth, 24), chunk_size);
                    var tile_y = ((y_num + y) - @divFloor(screenHeight, 24) - chunk.y) * chunk_size;

                    // Check if tile is on screen
                    if (x + x_num - @divFloor(screenWidth, 24)  >= chunk.x and x + x_num - @divFloor(screenWidth, 24)  < chunk.x + chunk_size and
                        y + y_num - @divFloor(screenHeight, 24) >= chunk.y and y + y_num - @divFloor(screenHeight, 24) < chunk.y + chunk_size*2) {

                        var raised: bool = false;

                        if (tile_x + tile_y >= 0 and tile_x + tile_y < chunk_size*chunk_size and
                            chunk.tiles[@intCast(usize, tile_x + tile_y) + chunk_size*chunk_size] != 0) {
                                raised = true;
                        }

                        // Tile collision detection
                        const c_x = (@divTrunc(screenWidth,  2) - tileSize) * scale;
                        const c_y = (@divTrunc(screenHeight, 2))            * scale ;

                        // If collision detected
//                         if (@floatToInt(i32, x_pos) >= c_x and @floatToInt(i32, x_pos) < c_x + (12 * scale) and
//                             @floatToInt(i32, y_pos) >= c_y and @floatToInt(i32, y_pos) < c_y + (12 * scale) and raised) {
//
//                             // Check one pixel to the side of the player and apply collision accordingly
//                             // TODO: stop the player from clipping into walls
//                             if (@floatToInt(i32, x_pos) >= c_x+scale and @floatToInt(i32, x_pos) < c_x + (13 * scale)) {
//                                 player.x -= std.math.fabs(player.x_speed);
//                             }
//                             if (@floatToInt(i32, x_pos) >= c_x-scale and @floatToInt(i32, x_pos) < c_x + (11 * scale)) {
//                                 player.x += std.math.fabs(player.x_speed);
//                             }
//                             if (@floatToInt(i32, y_pos) >= c_y+scale and @floatToInt(i32, y_pos) < c_y + (13 * scale)) {
//                                 player.y -= std.math.fabs(player.y_speed);
//                             }
//                             if (@floatToInt(i32, y_pos) >= c_y-scale and @floatToInt(i32, y_pos) < c_y + (11 * scale)) {
//                                 player.y += std.math.fabs(player.y_speed);
//                             }
//                         }

                        const player_rect = rl.Rectangle{
                            .x = @intToFloat(f32, @divTrunc(screenWidth * scale, 2) - 6 * scale),
                            .y = @intToFloat(f32, @divTrunc(screenHeight * scale + 24 * scale, 2) - 12 * scale),
                            .width = 12 * scale,
                            .height = 12 * scale,
                        };

                        const tile_rect = rl.Rectangle{
                            .x = x_pos,
                            .y = y_pos - 8*@intToFloat(f32, scale),
                            .width = 12 * scale,
                            .height = 12 * scale
                        };

                        var collision: rl.Rectangle = undefined;
                        if (rl.CheckCollisionRecs(player_rect, tile_rect)) {
                            collision = rl.GetCollisionRec(player_rect, tile_rect);
                            rec = collision;
                            print("{}\n", .{collision});
                        }

                        if (collision.width != collision.height) {

                            if (@floatToInt(i32, y_pos) >= c_y and @floatToInt(i32, y_pos) < c_y + (tileSize * scale) and raised) {

                                // Check one pixel to the side of the player and apply collision accordingly
                                // TODO: stop the player from clipping into walls


                                    if (collision.width < collision.height) {
                                        if (collision.x >= tile_rect.x and collision.width <= tile_rect.width)
                                            player.x -= player.x_speed;
                                    }

    //                             if (@floatToInt(i32, x_pos) >= c_x-scale and @floatToInt(i32, x_pos) < c_x + (11 * scale)) {
    //                                 player.x += std.math.fabs(player.x_speed);
    //                             }
    //                             if (@floatToInt(i32, y_pos) >= c_y+scale and @floatToInt(i32, y_pos) < c_y + (13 * scale)) {
    //                                 player.y -= std.math.fabs(player.y_speed);
    //                             }
    //                             if (@floatToInt(i32, y_pos) >= c_y-scale and @floatToInt(i32, y_pos) < c_y + (11 * scale)) {
    //                                 player.y += std.math.fabs(player.y_speed);
    //                             }
                            }
                            if (@floatToInt(i32, x_pos) >= c_x and @floatToInt(i32, x_pos) < c_x + (tileSize * scale) and raised) {

                                // Check one pixel to the side of the player and apply collision accordingly
                                // TODO: stop the player from clipping into walls


                                    if (collision.width > collision.height){
                                        if (collision.y >= tile_rect.y and collision.height <= tile_rect.height)
                                            player.y -= player.y_speed;
                                    }

                            }
                        }
                    }
                }
            }
        }

        rl.BeginDrawing();

        x = -1;
        y = -3;
        while (y * tileSize <= screenHeight) : (y += 1) {
            x = -1;
            while (x * tileSize <= screenWidth + tileSize) : (x += 1) {
                for (chunks) |chunk| {

                    const x_pos = @intToFloat(f32, x * tileSize * scale - player_mod_x + screen_mod_x);
                    const y_pos = @intToFloat(f32, y * tileSize * scale - player_mod_y + screen_mod_y + 12 * scale);

                //            print("collision {d}\n", .{y_pos});


                    // 24 because its tileSize*2
                    var tile_x = @mod(x_num + x - @divFloor(screenWidth, 24), chunk_size);
                    var tile_y = ((y_num + y) - @divFloor(screenHeight, 24) - chunk.y) * chunk_size;

                    // Check if tile is on screen
                    if (x + x_num - @divFloor(screenWidth, 24)  >= chunk.x and x + x_num - @divFloor(screenWidth, 24)  < chunk.x + chunk_size and
                        y + y_num - @divFloor(screenHeight, 24) >= chunk.y and y + y_num - @divFloor(screenHeight, 24) < chunk.y + chunk_size*2) {

                        // Only loop through the first half of chunk tiles (floor level)
                        if (tile_x + tile_y >= 0 and tile_x + tile_y < chunk_size*chunk_size) {
                            // If wall level tile exists, draw it instead
                            if (chunk.tiles[@intCast(usize, tile_x + tile_y) + chunk_size*chunk_size] == 0) {
                                rl.DrawTextureEx(tiles[chunk.tiles[@intCast(usize, tile_x + tile_y)]], rl.Vector2{ .x = x_pos, .y = y_pos }, 0, 1, rl.LIGHTGRAY);
                            } else {
                                // Shadow
//                                rl.DrawTextureEx(tiles[chunk.tiles[@intCast(usize, tile_x + tile_y)]], rl.Vector2{ .x = x_pos -8, .y = y_pos - 8*@intToFloat(f32, scale) }, 0, 1, rl.GRAY);
                                rl.DrawTextureEx(tiles[chunk.tiles[@intCast(usize, tile_x + tile_y)]], rl.Vector2{ .x = x_pos, .y = y_pos - 8*@intToFloat(f32, scale) }, 0, 1, rl.WHITE);
                            }
                        }
                    }
                }
            }
        }

        rl.DrawRectangleRec(rec, rl.WHITE);

        // Draw player in the center of the screen
        rl.DrawTexture(player.frame.*, scale * @divTrunc(screenWidth, 2) - 6 * scale, scale * @divTrunc(screenHeight, 2) - 12 * scale, rl.WHITE);
        //rl.DrawTextureEx(playerTexture, rl.Vector2{.x = @intToFloat(f32, scale*@divTrunc(screenWidth, 2)-8*scale), .y = @intToFloat(f32, scale*@divTrunc(screenHeight, 2)-16*scale)}, 90, 1, rl.WHITE);

        // Draw hotbar
        var i: i32 = 0;
        const mid = (scale * @divTrunc(screenWidth, 2) - 38 * scale);
        while (i < 6) {
            rl.DrawTexture(hotbar_item_texture, mid + i * scale * 13, scale * screenHeight - 13 * scale, rl.WHITE);
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
        "0", "1", "2", "3",
        "4", "5", "6", "7",
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
