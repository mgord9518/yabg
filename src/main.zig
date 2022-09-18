const rl     = @import("raylib");
const std    = @import("std");
const perlin = @import("perlin");
const fmt    = std.fmt;
const print  = std.debug.print;
const fs     = std.fs;
const RndGen = std.rand.DefaultPrng;

//const Player
//var debugEnabled = false;
//var debugMenuHeight: i32 = -96;

const tileSize     = 12;
const scale: i32        = 6;
// Set game ticks per second
const tps    = 30;
const chunk_size = 16;

//var screenWidth:  i32  = 240;
//var screenHeight: i32 = 160;
var screenWidth:  i32  = 160;
var screenHeight: i32 = 144;
const title = "Yet Another Block Game (YABG)";
const id    = "io.github.mgord9518.yabg";
var delta: f32 = 0;

const Chunk = struct {
    x: i32,
    y: i32,
    level: i32 = 0x80,
    tiles: [256]u8 = undefined,
};

const Direction = enum {
    left,
    right,
    up,
    down,
};

fn loadChunk(save_name: []const u8, mod_pack: []const u8, x: i32, y: i32) !Chunk {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const string = try fmt.allocPrint(
        alloc,
        "saves/{s}/{d}_{d}.{s}", .{
            save_name,
            x,
            y,
            mod_pack,
        },
    );

    var chunk = Chunk{.x = x*chunk_size, .y = y*chunk_size};
    var f = try fs.cwd().openFile(string, .{.read = true });
    defer f.close();

    _ = try f.read(chunk.tiles[0..]);
    return chunk;
}

fn inputDirection(direction: Direction) bool {
   // const axis_threashold = 0.1;



    // TODO: get gamepad working
    switch (direction) {
        .left => {
            if (rl.IsKeyDown(rl.KeyboardKey.KEY_A) or rl.IsGamepadButtonDown(0, rl.GamepadButton.GAMEPAD_BUTTON_UNKNOWN)) {
                return true;
            }
        },
        .right => {
            if (rl.IsKeyDown(rl.KeyboardKey.KEY_D) or rl.IsGamepadButtonDown(0, rl.GamepadButton.GAMEPAD_BUTTON_MIDDLE_RIGHT)) {
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
    texture:  *rl.Texture = undefined,
};

const Animation = enum {
    idle,
    walk_right,
    walk_left,
    walk_down,
    walk_up,
};

const Player = struct {
    x:         i32 = 0,
    y:         i32 = 0,
    subX:      f32 = 0,
    subY:      f32 = 0,

    frame:    *rl.Texture = undefined,
    frames_idle:  [1]rl.Texture = undefined,
    frames_right: [7]rl.Texture = undefined,

    frame_num_idle:  usize = 0,
    frame_num_right: usize = 0,
    frame_sub: f32 = 0,

    animation: Animation = .idle,

    fn updatePlayerFrames(player: *Player, frame: Animation) void {
        switch (frame) {
            .idle => {
                player.frame = &player.frames_idle[player.frame_num_idle];
            },
            .walk_right => {
                // Given an FPS of 60, this means that the animation will
                // update at 14 FPS
                player.frame_sub += tps*0.25*delta;

                if (player.frame_sub >= 1) {
                    player.frame_sub -= 1;
                    player.frame_num_right += 1;
                }

                if (player.frame_num_right >= 7) {
                    player.frame_num_right = 0;
                }
                player.frame = &player.frames_right[player.frame_num_right];
            },
            .walk_left => {},
            .walk_up => {},
            .walk_down => {},
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

};

const DebugMenu = struct {
    enabled: bool = false,
    min_y:    f32 = -96,

    x:        f32 = 0,
    y:        f32 = -96,
  //  text:    []u8,

    fn draw(self: *DebugMenu) void {
        print("test {}", .{self});
    }
};

pub fn main() !void {
    // Enable vsync and resizing
    rl.SetConfigFlags(rl.ConfigFlags.FLAG_VSYNC_HINT);
    rl.SetConfigFlags(rl.ConfigFlags.FLAG_WINDOW_RESIZABLE);
    rl.InitWindow(screenWidth*scale, screenHeight*scale, title);
   // rl.SetTraceLogLevel(7);

    var player = Player{};
    var menu   = DebugMenu{};
    var chunks: [9]Chunk = undefined;

    var grass  = rl.LoadImage("resources/vanilla/vanilla/tiles/grass.png");

    var font = rl.LoadFont("resources/vanilla/vanilla/ui/fonts/4x8/full.fnt");


    var hotbar_item = rl.LoadImage("resources/vanilla/vanilla/ui/hotbar_item.png");
    rl.ImageResizeNN(&hotbar_item, tileSize*scale, tileSize*scale);
    var hotbar_item_texture = rl.LoadTextureFromImage(hotbar_item);

    chunks[0] = try loadChunk("DEVTEST", "vanilla0", 0, 0);

    var player_image = rl.LoadImage("resources/vanilla/vanilla/entities/player_front.png");
    rl.ImageResizeNN(&player_image, 12*scale, 24*scale);
    player.frames_idle[0]  = rl.LoadTextureFromImage(player_image);

    var player_image1 = rl.LoadImage("resources/vanilla/vanilla/entities/player_right0.png");
    rl.ImageResizeNN(&player_image1, 12*scale, 24*scale);
    player.frames_right[0]  = rl.LoadTextureFromImage(player_image1);

    var player_image2 = rl.LoadImage("resources/vanilla/vanilla/entities/player_right1.png");
    rl.ImageResizeNN(&player_image2, 12*scale, 24*scale);
    player.frames_right[1]  = rl.LoadTextureFromImage(player_image2);

    var player_image3 = rl.LoadImage("resources/vanilla/vanilla/entities/player_right2.png");
    rl.ImageResizeNN(&player_image3, 12*scale, 24*scale);
    player.frames_right[2]  = rl.LoadTextureFromImage(player_image3);

    var player_image4 = rl.LoadImage("resources/vanilla/vanilla/entities/player_right3.png");
    rl.ImageResizeNN(&player_image4, 12*scale, 24*scale);
    player.frames_right[3]  = rl.LoadTextureFromImage(player_image4);

    player.frames_right[4]  = rl.LoadTextureFromImage(player_image1);

    var player_image5 = rl.LoadImage("resources/vanilla/vanilla/entities/player_right4.png");
    rl.ImageResizeNN(&player_image5, 12*scale, 24*scale);
    player.frames_right[5]  = rl.LoadTextureFromImage(player_image5);

    var player_image6 = rl.LoadImage("resources/vanilla/vanilla/entities/player_right5.png");
    rl.ImageResizeNN(&player_image6, 12*scale, 24*scale);
    player.frames_right[6]  = rl.LoadTextureFromImage(player_image6);

    player.frame = &player.frames_right[0];

    rl.ImageResizeNN(&grass,  tileSize*scale, tileSize*scale+8*scale);
//    rl.ImageResizeNN(&player_image1, 12*scale, 24*scale);
//    rl.ImageResizeNN(&player_image2, 12*scale, 24*scale);

   // var fontImg = rl.LoadImage("resources/vanilla/vanilla/ui/fonts/6x12/0-7f.png");

    var grassTexture = rl.LoadTextureFromImage(grass);


    // Main game loop
    while (!rl.WindowShouldClose()) { // Detect window close button or ESC key
//         var fps_avg: f32 = undefined;
        delta = rl.GetFrameTime();

        screenWidth  = @divTrunc(rl.GetScreenWidth(),  scale);
        screenHeight = @divTrunc(rl.GetScreenHeight(), scale);

        // Define our allocator,
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        var alloc = arena.allocator();

        player.updatePlayerFrames(player.animation);


        // Update player coords based on keys pressed
        if (inputDirection(.right) and rl.IsKeyDown(rl.KeyboardKey.KEY_S)) {
            player.animation = .walk_right;
            player.subX += tps*1.4*delta;
            player.subY += tps*1.4*delta;
        } else if (inputDirection(.left) and rl.IsKeyDown(rl.KeyboardKey.KEY_S)) {
            player.subX -= tps*1.4*delta;
            player.subY += tps*1.4*delta;
        } else if (inputDirection(.right) and rl.IsKeyDown(rl.KeyboardKey.KEY_W)) {
            player.animation = .walk_right;
            player.subX += tps*1.4*delta;
            player.subY -= tps*1.4*delta;
        } else if (inputDirection(.left) and rl.IsKeyDown(rl.KeyboardKey.KEY_W)) {
            player.subX -= tps*1.4*delta;
            player.subY -= tps*1.4*delta;
        } else if (inputDirection(.right)) {
            player.animation = .walk_right;
            player.subX += tps*2*delta;
        } else if (inputDirection(.left)) {
            player.subX -= tps*2*delta;
        } else if (rl.IsKeyDown(rl.KeyboardKey.KEY_S)) {
            player.subY += tps*2*delta;
        } else if (rl.IsKeyDown(rl.KeyboardKey.KEY_W)) {
            player.subY -= tps*2*delta;
        } else {
            player.animation = .idle;
        }

        player.updateCoords();

        if (rl.IsKeyPressed(rl.KeyboardKey.KEY_F3)) {
            menu.enabled = !menu.enabled;
        }

        if (rl.IsKeyPressed(rl.KeyboardKey.KEY_F11)) {
            rl.ToggleFullscreen();
        }

        // Player modulo is to draw tiles at their correct locations relative
        // to player coords
        const player_mod_x = @mod(player.x, tileSize)*scale;
        const player_mod_y = @mod(player.y, tileSize)*scale;

        // Screen modulo is to draw tiles offset depending on screen resolution
        // this only matters if the window resolution isn't a factor of 16 eg:
        // active resizing
        const screen_mod_x = @mod(@divTrunc(screenWidth,  2), tileSize)*scale;
        const screen_mod_y = @mod(@divTrunc(screenHeight, 2), tileSize)*scale;

        // Draw
        rl.BeginDrawing();
        rl.ClearBackground(rl.BLACK);

     //   var w: i32 = rl.GetScreenWidth();

        // Draw grass tiles
        // Start at -16

        const x_num = @divFloor(player.x, 12);
        const y_num = @divFloor(player.y, 12);

        var x: i32 = -1;
        var y: i32 = -2;
        while (y*tileSize <= screenHeight) : (y += 1) {
            x = -1;
            while (x*tileSize <= screenWidth+tileSize) : (x += 1) {
                //    rl.DrawTexture(grassTexture, x*tileSize*scale-player_mod_x+screen_mod_x, y*tileSize*scale-player_mod_y+screen_mod_y, rl.WHITE);



                const x_pos = @intToFloat(f32, x*tileSize*scale-player_mod_x+screen_mod_x);
                const y_pos = @intToFloat(f32, y*tileSize*scale-player_mod_y+screen_mod_y+12*scale);

                // TODO: FIX TILE_Y!!! TILE_X WORKS
                // 24 because its tileSize*2
                var tile_x = @mod(x_num + x - @divFloor(screenWidth, 24), 16);
                var tile_y = ((y_num + y) - @divFloor(screenHeight, 24) - chunks[0].y) * 16;

                if ( //x_num + @divFloor(screenWidth, 24) +x > chunks[0].x and x_num - @divFloor(screenWidth, 24) <= chunks[0].x+chunk_size and
                    //y_num + @divFloor(screenHeight, 24) +y  > chunks[0].y and y_num - @divFloor(screenHeight, 24) <= chunks[0].y+chunk_size and
                    x + x_num - @divFloor(screenWidth, 24) >= chunks[0].x and x + x_num - @divFloor(screenWidth, 24) < chunks[0].x+chunk_size and
                    y + y_num - @divFloor(screenHeight, 24) >= chunks[0].y and y + y_num - @divFloor(screenHeight, 24) < chunks[0].y+chunk_size) {

                    if (tile_x+tile_y >= 0 and tile_x+tile_y < 256 and chunks[0].tiles[@intCast(usize, tile_x+tile_y)] == 0) {
                        rl.DrawTextureEx(grassTexture, rl.Vector2{.x = x_pos, .y = y_pos}, 0, 1,    rl.WHITE);
                    }
                }
            }

        }

        //print("{d}", .{@divTrunc(screenWidth, 2)});
        // Draw player in the center of the screen
        rl.DrawTexture(player.frame.*, scale*@divTrunc(screenWidth, 2)-6*scale, scale*@divTrunc(screenHeight, 2)-12*scale, rl.WHITE);
        //rl.DrawTextureEx(playerTexture, rl.Vector2{.x = @intToFloat(f32, scale*@divTrunc(screenWidth, 2)-8*scale), .y = @intToFloat(f32, scale*@divTrunc(screenHeight, 2)-16*scale)}, 90, 1, rl.WHITE);

        // Draw hotbar
        var i: i32 = 0;
        const mid = (scale*@divTrunc(screenWidth, 2)-38*scale);
        while (i < 6) {
            rl.DrawTexture(hotbar_item_texture, mid+i*scale*13, scale*screenHeight-13*scale, rl.WHITE);
            //                                    ^average w         ^ bottom, one px space
            i += 1;

        //    print("test", .{});
        }


            // Draw debug menu
        if (menu.enabled or menu.y > menu.min_y) {
            if (menu.enabled and menu.y < 0) {
                menu.y += 4*tps*delta;
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

            //   print("{s}\n", .{try int2Dozenal(@divTrunc(px, tileSize), &alloc)});
            //print("{s}\n", .{x_str});


            // Casted because rl.DrawText* wants an array, not slice
            const string = @ptrCast(*u8, try fmt.allocPrint(
                alloc,
                "FPS: {d} (vsync)\nX:{s}{s}.{s}\nY:{s}{s}.{s}\n\nRune test: ᚠᚢᚦᚫᚱᚲ\nDozenal: 0123456789ⅩƐ", .{ rl.GetFPS(),
                    negX,
                    try int2Dozenal(@divTrunc(px, tileSize), &alloc),
                    try int2Dozenal(@mod(px, tileSize), &alloc),
                    negY,
                    try int2Dozenal(@divTrunc(py, tileSize), &alloc),
                    try int2Dozenal(@mod(py, tileSize), &alloc),
                },
            ));
            //print("{s}\n", .{x_str});


            var alpha: u8 = undefined;
            if (menu.y < 0) {
                alpha = @floatToInt(u8, 192+menu.y);
               // print("{d}\n", .{alpha});
            }

            // Draw debug menu and its shadow
            rl.DrawTextEx(font, string, rl.Vector2{.x = scale*2, .y = @intToFloat(f32, scale)+menu.y*@intToFloat(f32, scale)*0.75}, 6*scale, scale, rl.Color{.r = 0,   .g = 0,   .b = 0,   .a = @divTrunc(alpha, 3)});
            rl.DrawTextEx(font, string, rl.Vector2{.x = scale,   .y = menu.y*@intToFloat(f32, scale)},     6*scale, scale, rl.Color{.r = 192, .g = 192, .b = 192, .a = alpha});
        }
        if (!menu.enabled and menu.y > menu.min_y) {
            menu.y -= 4*tps*delta;
        }


        rl.EndDrawing();
    }

    rl.CloseWindow();
}

fn int2Dozenal(i: i32, alloc: *std.mem.Allocator) ![]u8 {
    var n = i;

    // Symbols to extend the arabic number set
    const symbols = [_][]const u8{ "Ⅹ", "Ɛ" };
    var num: []u8 = "";

    if (n == 0) {
        return try fmt.allocPrint(alloc.*, "0", .{});
    }

    while ( n > 0 ) {
        var rem = @intCast(usize, @mod(n, 12));
       // var res: [20]u8 = undefined;

        if ( rem < 10 ) {
            //num = try fmt.allocPrint(alloc, "{d}", .{rem});
         //   num = try fmt.allocPrint(alloc.*, "{d}", .{rem});
            num = try fmt.allocPrint(alloc.*, "{d}{s}", .{rem, num});
        } else {
            num = try fmt.allocPrint(alloc.*, "{s}{s}", .{symbols[rem-10], num});
           // num = symbols[rem-10];
        }

        n = @divFloor(n, 12);
    }

    return num;
}
