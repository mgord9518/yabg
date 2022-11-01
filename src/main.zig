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

const Chunk = struct {
    x: i32,
    y: i32,
    level: i32 = 0x80,
    tiles: [chunk_size*chunk_size*2]u8 = undefined,
};

var chunks: [9]Chunk = undefined;

const Direction = enum {
    left,
    right,
    up,
    down,
};

fn loadChunk(save_name: []const u8, mod_pack: []const u8, x: i32, y: i32) !Chunk {
    //var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    //defer arena.deinit();
    //const alloc = arena.allocator();

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
    var f = fs.cwd().openFile(string, .{ .read = true }) catch return genChunk(save_name, mod_pack, x, y);
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

    print("GENERATING CHUNK AT {x}, {x}\n", .{x, y});
    chunks_generated = chunks_generated + 1;

    _ = mod_pack;
    _ = save_name;

    // TODO: Save bytes to disk
    var chunk = Chunk{ .x = x * chunk_size, .y = y * chunk_size };
    var f = fs.cwd().createFile(path, .{ .read = true }) catch unreachable;
    _ = f;


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

    return chunk;

}

fn inputDirection(direction: Direction) bool {
    // const axis_threashold = 0.1;

    // TODO: get gamepad working
    switch (direction) {
        .left => {
            if (rl.IsKeyDown(.KEY_A) or rl.IsGamepadButtonDown(0, .GAMEPAD_BUTTON_UNKNOWN)) {
                return true;
            }
        },
        .right => {
            if (rl.IsKeyDown(.KEY_D) or rl.IsGamepadButtonDown(0, .GAMEPAD_BUTTON_MIDDLE_RIGHT)) {
                return true;
            }
        },
        .up => {},
        .down => {},
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
    x: i32 = 0,
    y: i32 = 0,
    subX: f32 = 0,
    subY: f32 = 0,

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

    //loadedChunks: [9]*Chunk = undefined,

    animation: Animation = .Idle,

    fn updatePlayerFrames(player: *Player, frame: Animation) void {
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

    // Updates the player's coords to a pixel snap value
    fn updateCoords(player: *Player) void {
        if (inputDirection(.right) and rl.IsKeyDown(rl.KeyboardKey.KEY_S)) {
            if (player.subX > 1 and player.subY > 1) {
                player.x += 1;
                player.y += 1;
                player.subX -= 1;
                player.subY -= 1;
            }

            return;
        } else if (inputDirection(.left) and rl.IsKeyDown(rl.KeyboardKey.KEY_S)) {
            if (player.subX < -1 and player.subY > 1) {
                player.x -= 1;
                player.y += 1;
                player.subX += 1;
                player.subY -= 1;
            }

            return;
        } else if (rl.IsKeyDown(rl.KeyboardKey.KEY_D) and rl.IsKeyDown(rl.KeyboardKey.KEY_W)) {
            if (player.subX > 1 and player.subY < -1) {
                player.x += 1;
                player.y -= 1;
                player.subX -= 1;
                player.subY += 1;
            }

            return;
        } else if (inputDirection(.left) and rl.IsKeyDown(rl.KeyboardKey.KEY_W)) {
            if (player.subX < -1 and player.subY < -1) {
                player.x -= 1;
                player.y -= 1;
                player.subX += 1;
                player.subY += 1;
            }

            return;
        }

        if (player.subX > 1) {
            player.x += 1;
            player.subX -= 1;
        }
        if (player.subX < -1) {
            player.x -= 1;
            player.subX += 1;
        }
        if (player.subY > 1) {
            player.y += 1;
            player.subY -= 1;
        }
        if (player.subY < -1) {
            player.y -= 1;
            player.subY += 1;
        }
    }

    // Checks and unloads any chunks not surrounding the player in a 9x9 area
    // then loads new chunks into their pointers
    // Not yet sure how robust this is
    fn reloadChunks(player: *Player) void {
        var cx_origin = @divTrunc(@divTrunc(player.x, tileSize), chunk_size);
        var cy_origin = @divTrunc(@divTrunc(player.y, tileSize), chunk_size);

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
                chunk.* = loadChunk("DEVTEST", "vanilla0", cx_origin - 1, cy) catch unreachable;
            } else if (@divTrunc(chunk.x, chunk_size) < cx_origin - 1) {
                chunk.* = loadChunk("DEVTEST", "vanilla0", cx_origin + 1, cy) catch unreachable;
            } else if (@divTrunc(chunk.y, chunk_size) > cy_origin + 1) {
                chunk.* = loadChunk("DEVTEST", "vanilla0", cx, cy_origin - 1) catch unreachable;
            } else if (@divTrunc(chunk.y, chunk_size) < cy_origin - 1) {
                chunk.* = loadChunk("DEVTEST", "vanilla0", cx, cy_origin + 1) catch unreachable;
            }
        }
    }
};

const DebugMenu = struct {
    enabled: bool = false,
    min_y: f32 = -96,

    x: f32 = 0,
    y: f32 = -96,
    //  text:    []u8,

    fn draw(self: *DebugMenu) void {
        print("test {}", .{self});
    }
};

pub fn main() !void {
    // Enable vsync and resizing
    rl.SetConfigFlags(rl.ConfigFlags.FLAG_VSYNC_HINT);
    rl.SetConfigFlags(rl.ConfigFlags.FLAG_WINDOW_RESIZABLE);
    rl.InitWindow(screenWidth * scale, screenHeight * scale, title);
    rl.SetExitKey(rl.KeyboardKey.KEY_NULL);
    // rl.SetTraceLogLevel(7);

    var player = Player{};
    var menu = DebugMenu{};

    const font = rl.LoadFont("resources/vanilla/vanilla/ui/fonts/4x8/full.fnt");

    var hotbar_item = rl.LoadImage("resources/vanilla/vanilla/ui/hotbar_item.png");
    rl.ImageResizeNN(&hotbar_item, tileSize * scale, tileSize * scale);
    var hotbar_item_texture = rl.LoadTextureFromImage(hotbar_item);

    //var menu_frame = rl.LoadImage("resources/vanilla/vanilla/ui/menu.png");
    //rl.ImageResizeNN(&menu_frame, 128 * scale, 128 * scale);
    //var menu_frame_texture = rl.LoadTextureFromImage(menu_frame);

    chunks[0] = try loadChunk("DEVTEST", "vanilla0", -1, -1);
    chunks[1] = try loadChunk("DEVTEST", "vanilla0", -1,  0);
    chunks[2] = try loadChunk("DEVTEST", "vanilla0", -1,  1);
    chunks[3] = try loadChunk("DEVTEST", "vanilla0",  0, -1);
    chunks[4] = try loadChunk("DEVTEST", "vanilla0",  0,  0);
    chunks[5] = try loadChunk("DEVTEST", "vanilla0",  0,  1);
    chunks[6] = try loadChunk("DEVTEST", "vanilla0",  1, -1);
    chunks[7] = try loadChunk("DEVTEST", "vanilla0",  1,  0);
    chunks[8] = try loadChunk("DEVTEST", "vanilla0",  1,  1);

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
        if (inputDirection(.right) and rl.IsKeyDown(rl.KeyboardKey.KEY_S)) {
            player.animation = .WalkRight;
            player.subX += tps * 1.4 * delta;
            player.subY += tps * 1.4 * delta;
        } else if (inputDirection(.left) and rl.IsKeyDown(rl.KeyboardKey.KEY_S)) {
            player.animation = .WalkLeft;
            player.subX -= tps * 1.4 * delta;
            player.subY += tps * 1.4 * delta;
        } else if (inputDirection(.right) and rl.IsKeyDown(rl.KeyboardKey.KEY_W)) {
            player.animation = .WalkRight;
            player.subX += tps * 1.4 * delta;
            player.subY -= tps * 1.4 * delta;
        } else if (inputDirection(.left) and rl.IsKeyDown(rl.KeyboardKey.KEY_W)) {
            player.animation = .WalkLeft;
            player.subX -= tps * 1.4 * delta;
            player.subY -= tps * 1.4 * delta;
        } else if (inputDirection(.right)) {
            player.animation = .WalkRight;
            player.subX += tps * 2 * delta;
        } else if (inputDirection(.left)) {
            player.animation = .WalkLeft;
            player.subX -= tps * 2 * delta;
        } else if (rl.IsKeyDown(.KEY_S)) {
            player.subY += tps * 2 * delta;
        } else if (rl.IsKeyDown(.KEY_W)) {
            player.subY -= tps * 2 * delta;
        } else {
            player.animation = .Idle;
        }

        player.updateCoords();

        if (rl.IsKeyPressed(.KEY_F3)) {
            menu.enabled = !menu.enabled;
        }

        if (rl.IsKeyPressed(.KEY_F11)) {
            rl.ToggleFullscreen();
        }

        // Player modulo is to draw tiles at their correct locations relative
        // to player coords
        const player_mod_x = @mod(player.x, tileSize) * scale;
        const player_mod_y = @mod(player.y, tileSize) * scale;

        // Screen modulo is to draw tiles offset depending on screen resolution
        // this only matters if the window resolution isn't a factor of 16 eg:
        // active resizing
        const screen_mod_x = @mod(@divTrunc(screenWidth, 2), tileSize) * scale;
        const screen_mod_y = @mod(@divTrunc(screenHeight, 2), tileSize) * scale;

        // Draw
        rl.BeginDrawing();
        rl.ClearBackground(rl.BLACK);

        //   var w: i32 = rl.GetScreenWidth();

        // Draw grass tiles
        // Start at -16

        const x_num = @divFloor(player.x, 12);
        const y_num = @divFloor(player.y, 12);

        var x: i32 = -1;
        var y: i32 = -3;
        while (y * tileSize <= screenHeight) : (y += 1) {
            x = -1;
            while (x * tileSize <= screenWidth + tileSize) : (x += 1) {
                for (chunks) |chunk| {

                    const x_pos = @intToFloat(f32, x * tileSize * scale - player_mod_x + screen_mod_x);
                    const y_pos = @intToFloat(f32, y * tileSize * scale - player_mod_y + screen_mod_y + 12 * scale);

                    // 24 because its tileSize*2
                    var tile_x = @mod(x_num + x - @divFloor(screenWidth, 24), chunk_size);
                    var tile_y = ((y_num + y) - @divFloor(screenHeight, 24) - chunk.y) * chunk_size;

                    // Check if tile is on screen
                    if (x + x_num - @divFloor(screenWidth, 24)  >= chunk.x and x + x_num - @divFloor(screenWidth, 24)  < chunk.x + chunk_size and
                        y + y_num - @divFloor(screenHeight, 24) >= chunk.y and y + y_num - @divFloor(screenHeight, 24) < chunk.y + chunk_size*2) {

                        var raised: bool = false;

                        // Only loop through the first half of chunk tiles (floor level)
                        if (tile_x + tile_y >= 0 and tile_x + tile_y < chunk_size*chunk_size) {
                            // If wall level tile exists, draw it instead
                            if (chunk.tiles[@intCast(usize, tile_x + tile_y) + chunk_size*chunk_size] == 0) {
                                rl.DrawTextureEx(tiles[chunk.tiles[@intCast(usize, tile_x + tile_y)]], rl.Vector2{ .x = x_pos, .y = y_pos }, 0, 1, rl.LIGHTGRAY);
                            } else {
                                // Shadow
//                                rl.DrawTextureEx(tiles[chunk.tiles[@intCast(usize, tile_x + tile_y)]], rl.Vector2{ .x = x_pos -8, .y = y_pos - 8*@intToFloat(f32, scale) }, 0, 1, rl.GRAY);
                                raised = true;
                                rl.DrawTextureEx(tiles[chunk.tiles[@intCast(usize, tile_x + tile_y)]], rl.Vector2{ .x = x_pos, .y = y_pos - 8*@intToFloat(f32, scale) }, 0, 1, rl.WHITE);
                            }
                        }

                        // Tile collision detection
                        const c_x = (@divTrunc(screenWidth, 2)-12) * scale ;
                        const c_y = (@divTrunc(screenHeight, 2)) *scale ;

                        // If collision detected
                        if (@floatToInt(i32, x_pos) >= c_x and @floatToInt(i32, x_pos) < c_x + (12 * scale) and
                            @floatToInt(i32, y_pos) >= c_y and @floatToInt(i32, y_pos) < c_y + (12 * scale) and raised) {

                            // Check one pixel to the side of the player and apply collision accordingly
                            // TODO: stop the player from clipping into walls
                            if (@floatToInt(i32, x_pos) >= c_x+scale and @floatToInt(i32, x_pos) < c_x + (13 * scale)) {
                                player.x -= 1;
                            }
                            if (@floatToInt(i32, x_pos) >= c_x-scale and @floatToInt(i32, x_pos) < c_x + (11 * scale)) {
                                player.x += 1;
                            }
                            if (@floatToInt(i32, y_pos) >= c_y+scale and @floatToInt(i32, y_pos) < c_y + (13 * scale)) {
                                player.y -= 1;
                            }
                            if (@floatToInt(i32, y_pos) >= c_y-scale and @floatToInt(i32, y_pos) < c_y + (11 * scale)) {
                                player.y += 1;
                            }
                           // player.x -= 1;
                            print("collision {d} {d}\n", .{x_pos, c_x});
                        }
                    }
                }
            }
        }

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

        // Draw debug menu
        if (menu.enabled or menu.y > menu.min_y) {
            if (menu.enabled and menu.y < 0) {
                menu.y += 4 * tps * delta;
            }
            if (menu.y > 0) {
                menu.y = 0;
            }

            var negX = " ";
            if (player.x < 0) {
                negX = "-";
            }
            var negY = " ";
            if (player.y < 0) {
                negY = "-";
            }

            var px = player.x;
            if (px < 0) {
                px *= -1;
            }
            var py = player.y;
            if (py < 0) {
                py *= -1;
            }

            const string = try fmt.allocPrint(
                alloc,
                "FPS: {s}; (vsync)\nX:{s}{s};{s}\nY:{s}{s};{s}\n\nUTF8: ᚠᚢᚦᚫᚱᚲ®ÝƒÄ{{}}~\nChunks generated: {s};",
                .{
                    int2Dozenal(rl.GetFPS(), &alloc),
                    negX,
                    int2Dozenal(@divTrunc(px, tileSize), &alloc),
                    int2Dozenal(@mod(px, tileSize), &alloc),
                    negY,
                    int2Dozenal(@divTrunc(py, tileSize), &alloc),
                    int2Dozenal(@mod(py, tileSize), &alloc),
                    int2Dozenal(chunks_generated, &alloc),
                },
            );

            var alpha: u8 = undefined;
            if (menu.y < 0) {
                alpha = @floatToInt(u8, 192 + menu.y);
                // print("{d}\n", .{alpha});
            }

            // Draw debug menu and its shadow
            rl.DrawTextEx(font, string.ptr, rl.Vector2{ .x = scale * 2, .y = @intToFloat(f32, scale) + menu.y * @intToFloat(f32, scale) * 0.75 }, 6 * scale, scale, rl.Color{ .r = 0, .g = 0, .b = 0, .a = @divTrunc(alpha, 3) });
            rl.DrawTextEx(font, string.ptr, rl.Vector2{ .x = scale, .y = menu.y * @intToFloat(f32, scale) }, 6 * scale, scale, rl.Color{ .r = 192, .g = 192, .b = 192, .a = alpha });
        }
        if (!menu.enabled and menu.y > menu.min_y) {
            menu.y -= 4 * tps * delta;
        }

        rl.EndDrawing();
    }

    rl.CloseWindow();
}

fn int2Dozenal(i: i32, alloc: *std.mem.Allocator) ![]u8 {
    var n = i;

    // Symbols to extend the arabic number set
    // If your font has trouble reading the last 2, they are "TURNED DIGIT 2" and
    // "TURNED DIGIT 3" from Unicode 8.
    const symbols = [_][]const u8{ "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "↊", "↋" };
    var num: []u8 = "";

    if (n == 0) return try fmt.allocPrint(alloc.*, "0", .{});

    while (n > 0) {
        var rem = @intCast(usize, @mod(n, 12));
        num = try fmt.allocPrint(alloc.*, "{s}{s}", .{ symbols[rem], num });
        n = @divFloor(n, 12);
    }

    return num;
}
