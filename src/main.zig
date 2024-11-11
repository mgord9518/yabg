const rl = @import("raylib");
const std = @import("std");
const builtin = @import("builtin");
const known_folders = @import("known-folders");
const psf = @import("psf.zig");

const Chunk = @import("Chunk.zig");
const Tile = @import("Tile.zig").Tile;
const Player = @import("Player.zig");
const Game = @import("Game.zig");

const font_data = @embedFile("font.psfu");
var font: Font = undefined;
var psf_font: psf.Font = undefined;

const Vec = struct {
    x: u16,
    y: u16,
};

const NewVec = struct {
    x: i16,
    y: i16,
};

const Font = struct {
    atlas: rl.Texture,
    glyph_offsets: std.AutoHashMap(u21, usize),
};

fn drawText(
    string: []const u8,
    coords: rl.Vector2,
) !void {
    var view = try std.unicode.Utf8View.init(string);
    var it = view.iterator();

    var line_offset: f32 = 0;
    const font_size = 8;

    var x_off: f32 = 0;

    while (it.nextCodepoint()) |codepoint| {
        if (codepoint == '\n') {
            x_off = 0;
            line_offset += font_size * Game.scale;
            continue;
        }

        rl.drawTexturePro(
            font.atlas,
            .{
                .x = @floatFromInt(font.glyph_offsets.get(codepoint) orelse 0),
                .y = 0,
                .width = 4 + 1,
                .height = 8 + 1,
            },
            .{
                .x = (coords.x + @as(f32, x_off)) * Game.scale,
                .y = coords.y * Game.scale + line_offset,
                .width = (4 + 1) * Game.scale,
                .height = (8 + 1) * Game.scale,
            },
            .{
                .x = 0,
                .y = 0,
            },
            0,
            rl.Color.white,
        );

        x_off += 5;
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

        rl.drawTextureV(menu.texture, pos, rl.Color.white);
    }
};

fn drawCharToImage(image: rl.Image, char: u21, pos: Vec) !void {
    const bitmap = psf_font.glyphs.get(char) orelse return;

    const imgw: usize = @intCast(image.width);
    const imgh: usize = @intCast(image.height);

    const image_data: []u16 = @as([*]u16, @ptrCast(@alignCast(image.data)))[0 .. imgw * imgh];

    const color = 0x7f_ee;
    const shadow_color = 0x7f_00;

    const x = pos.x;
    var y = pos.y;

    for (bitmap) |byte| {
        // Shadow
        if (byte & 0b10000000 != 0) image_data[x + 1 + (y + 1) * imgw] = shadow_color;
        if (byte & 0b01000000 != 0) image_data[x + 2 + (y + 1) * imgw] = shadow_color;
        if (byte & 0b00100000 != 0) image_data[x + 3 + (y + 1) * imgw] = shadow_color;
        if (byte & 0b00010000 != 0) image_data[x + 4 + (y + 1) * imgw] = shadow_color;
        if (byte & 0b00001000 != 0) image_data[x + 5 + (y + 1) * imgw] = shadow_color;

        if (byte & 0b10000000 != 0) image_data[x + 0 + y * imgw] = color;
        if (byte & 0b01000000 != 0) image_data[x + 1 + y * imgw] = color;
        if (byte & 0b00100000 != 0) image_data[x + 2 + y * imgw] = color;
        if (byte & 0b00010000 != 0) image_data[x + 3 + y * imgw] = color;
        if (byte & 0b00001000 != 0) image_data[x + 4 + y * imgw] = color;

        y += 1;

        if (y == psf_font.h) {
            y = pos.y;
        }
    }
}

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
        const string = try std.fmt.allocPrintZ(
            allocator,
            \\YABG {?s} {d}.{d}.{d}
            \\FPS: {s}; (vsync)
            \\
            \\X:{s}{s};{s}
            \\Y:{s}{s};{s}
            \\
            \\Built with Zig {d}.{d}.{d}
        ,
            .{
                Game.version.pre,
                Game.version.major,
                Game.version.minor,
                Game.version.patch,
                try int2Dozenal(rl.getFPS(), allocator),
                neg_x,
                try int2Dozenal(@divTrunc(px, Tile.size), allocator),
                try int2Dozenal(@mod(px, Tile.size), allocator),
                neg_y,
                try int2Dozenal(@divTrunc(py, Tile.size), allocator),
                try int2Dozenal(@mod(py, Tile.size), allocator),
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
        return std.fs.path.joinZ(self.allocator, &[_][]const u8{ self.base, p }) catch unreachable;
    }
};

fn loadTextureFallback(img_path: [:0]const u8) rl.Texture2D {
    const placeholder_data = @embedFile("embedded_files/placeholder.png");
    const placeholder = rl.loadImageFromMemory(
        ".png",
        placeholder_data,
    );

    const img = rl.loadImage(img_path.ptr);
    const data_maybe: ?*anyopaque = @ptrCast(img.data);
    if (data_maybe) |_| {
        return rl.loadTextureFromImage(img);
    }

    return rl.loadTextureFromImage(placeholder);
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var initialization_arena = std.heap.ArenaAllocator.init(allocator);
    defer initialization_arena.deinit();

    const env_map = try std.process.getEnvMap(initialization_arena.allocator());

    // Enable vsync, resizing and init audio devices
    rl.setConfigFlags(.{
        .vsync_hint = true,
        .window_resizable = true,
    });

    rl.setTraceLogLevel(.log_debug);
    rl.initAudioDevice();

    psf_font = try psf.Font.parse(allocator, font_data);

    const exe_path = (try known_folders.getPath(allocator, .executable_dir)).?;

    const app_dir = try std.fs.path.joinZ(
        initialization_arena.allocator(),
        &.{ exe_path, "../.." },
    );

    // Get enviornment variables and set window size to them if they exist
    const w_env: []const u8 = env_map.get("WINDOW_WIDTH") orelse "";
    const h_env: []const u8 = env_map.get("WINDOW_HEIGHT") orelse "";
    const scale_env: []const u8 = env_map.get("SCALE_FACTOR") orelse "";
    const speed_env: []const u8 = env_map.get("PLAYER_SPEED") orelse "";

    // Scale must be an int because fractionals cause tons of issues
    Game.scale = @floor(std.fmt.parseFloat(f32, scale_env) catch Game.scale);
    Player.walk_speed = std.fmt.parseFloat(f32, speed_env) catch Player.walk_speed;

    const scale_i: i32 = @intFromFloat(Game.scale);
    var width_i: u31 = @intFromFloat(Game.screen_width);
    var height_i: u31 = @intFromFloat(Game.screen_height);

    const w = std.fmt.parseInt(i32, w_env, 10) catch width_i * scale_i;
    const h = std.fmt.parseInt(i32, h_env, 10) catch height_i * scale_i;

    const data_dir = (try known_folders.getPath(allocator, .data)).?;

    const save_path = try std.fs.path.joinZ(
        allocator,
        &.{
            data_dir,
            Game.id,
            "saves",
            "DEVTEST",
        },
    );

    const vanilla_dir = try std.fs.path.joinZ(
        allocator,
        &.{
            app_dir,
            "usr",
            "share",
            "io.github.mgord9518.yabg",
            "vanilla",
            "vanilla",
        },
    );

    var player = Player.init(save_path);
    var menu = DebugMenu{ .player = &player };

    menu.enabled = env_map.get("DEBUG_MODE") != null;

    var vanilla = PathBuilder.init(allocator, vanilla_dir);

    rl.initWindow(w, h, Game.title);

    const data = try allocator.alloc(u16, 9 * (1024 * 4) + 1);

    @memset(data, 0);

    defer allocator.free(data);

    const font_image = rl.Image{
        .data = data.ptr,

        // Room for 1024 characters
        // This should be expanded in the future if needed
        .width = 1024 * 4 + 1,

        // One extra pixel for the shadow
        .height = 8 + 1,
        .mipmaps = 1,
        .format = .pixelformat_uncompressed_gray_alpha,
    };

    font = .{
        .atlas = undefined,
        .glyph_offsets = std.AutoHashMap(u21, usize).init(allocator),
    };

    var off: usize = 0;

    var key_it = psf_font.glyphs.keyIterator();
    while (key_it.next()) |key| : (off += (psf_font.w + 1)) {
        try drawCharToImage(font_image, key.*, .{
            .x = @intCast(off),
            .y = 0,
        });

        try font.glyph_offsets.put(key.*, off);
    }

    font.atlas = rl.loadTextureFromImage(font_image);

    defer font.glyph_offsets.deinit();

    // Disable exit on keypress
    rl.setExitKey(.key_null);

    Game.font = rl.loadFont(vanilla.join("ui/fonts/4x8/full.fnt").ptr);

    var hotbar_item = rl.loadImage(vanilla.join("ui/hotbar_item.png").ptr);
    const hotbar_item_height = hotbar_item.height * scale_i;
    const hotbar_item_width = hotbar_item.width * scale_i;

    rl.imageResizeNN(&hotbar_item, hotbar_item_height, hotbar_item_width);
    const hotbar_item_texture = rl.loadTextureFromImage(hotbar_item);

    var menu_frame = rl.loadImage(vanilla.join("ui/menu.png").ptr);
    rl.imageResizeNN(&menu_frame, scale_i * 128, scale_i * 128);
    const menu_frame_texture = rl.loadTextureFromImage(menu_frame);

    var settings = Menu{ .player = &player, .texture = menu_frame_texture };

    // Create save directory if it doesn't already exist
    const cwd = std.fs.cwd();
    cwd.makePath(save_path) catch |err| {
        if (err != error.PathAlreadyExists) {
            std.debug.print("Error creating save directory: {}", .{err});
        }
    };

    var chunk_x = @as(i32, @intFromFloat(@divTrunc(@divTrunc(player.x, Tile.size), Chunk.size)));
    var chunk_y = @as(i32, @intFromFloat(@divTrunc(@divTrunc(player.y, Tile.size), Chunk.size)));

    if (player.x < 0) {
        chunk_x = chunk_x - 1;
    }

    if (player.y < 0) {
        chunk_y = chunk_y - 1;
    }

    // Init chunk array
    // TODO: lower this number to 4 to so that less iterations have to be done
    var x_it = chunk_x - 1;
    var y_it = chunk_y - 1;
    var it: usize = 0;
    while (x_it <= chunk_x + 1) : (x_it += 1) {
        while (y_it <= chunk_y + 1) : (y_it += 1) {
            Game.chunks[it] = try Chunk.load(save_path, "vanilla0", x_it, y_it);
            it += 1;
        }
        y_it = chunk_y - 1;
    }

    const player_image = rl.loadImage(vanilla.join("entities/players/player_down_0.png"));
    player.frames[0][0] = rl.loadTextureFromImage(player_image);
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
            const img_path = try std.fmt.allocPrintZ(
                allocator,
                "{s}/usr/share/io.github.mgord9518.yabg/vanilla/vanilla/entities/players/player_{s}_{x}.png",
                .{ app_dir, direction, it },
            );

            const player_image1 = rl.loadImage(img_path.ptr);
            player.frames[direction_enum][it] = rl.loadTextureFromImage(player_image1);
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
        var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
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

        const tile_sound = rl.loadSound(try std.fmt.bufPrintZ(
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
    while (!rl.windowShouldClose()) {
        rl.clearBackground(rl.Color.black);

        var arena_allocator = std.heap.ArenaAllocator.init(allocator);
        defer arena_allocator.deinit();
        const arena = arena_allocator.allocator();

        Game.delta = rl.getFrameTime();

        Game.screen_width = @divTrunc(
            @as(f32, @floatFromInt(rl.getScreenWidth())),
            Game.scale,
        );

        Game.screen_height = @divTrunc(
            @as(f32, @floatFromInt(rl.getScreenHeight())),
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
            player.direction = .right;
            player.animation = .walk_right;
        } else if (input_vec.x < 0) {
            player.direction = .left;
            player.animation = .walk_left;
        } else if (input_vec.y > 0) {
            player.direction = .down;
            player.animation = .walk_down;
        } else if (input_vec.y < 0) {
            player.direction = .up;
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

        if (rl.isKeyPressed(.key_f3) or rl.isGamepadButtonPressed(0, .gamepad_button_middle_left)) {
            menu.enabled = !menu.enabled;
        }

        if (rl.isKeyPressed(.key_escape) or rl.isGamepadButtonPressed(0, .gamepad_button_middle_right)) {
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
        const screen_mod_x: i32 = @intFromFloat(
            @mod(@divTrunc(Game.screen_width, 2), Tile.size),
        );

        const screen_mod_y: i32 = @intFromFloat(
            @mod(@divTrunc(Game.screen_height, 2), Tile.size),
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

                    const tile_x = @mod(x_num + x - screen_width_in_tiles, Chunk.size);
                    const tile_y = ((y_num + y) - screen_height_in_tiles - chnk.y) * Chunk.size;

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

                        _ = tile_front_rect;

                        const player_point = rl.Vector2{
                            .x = player_rect.x + player_rect.width / 2,
                            .y = player_rect.y + player_rect.height / 2,
                        };

                        const player_target_point = switch (player.direction) {
                            .left => .{
                                .x = player_point.x - Tile.size * Game.scale,
                                .y = player_point.y,
                            },
                            .right => .{
                                .x = player_point.x + Tile.size * Game.scale,
                                .y = player_point.y,
                            },
                            .up => .{
                                .x = player_point.x,
                                .y = player_point.y - Tile.size * Game.scale,
                            },
                            .down => .{
                                .x = player_point.x,
                                .y = player_point.y + Tile.size * Game.scale,
                            },
                        };

                        if (rl.checkCollisionPointRec(player_target_point, tile_rect)) {
                            if (rl.isKeyPressed(.key_period) or rl.isGamepadButtonPressed(0, .gamepad_button_right_face_left)) {
                                rl.playSound(wall_tile.sound());
                                chnk.tiles[tile_idx + Chunk.size * Chunk.size].id = .air;
                                if (floor_tile.id == .grass and wall_tile.id != .air) {
                                    chnk.tiles[tile_idx].id = .dirt;
                                }
                            }

                            if (rl.isKeyPressed(.key_slash) or rl.isGamepadButtonPressed(0, .gamepad_button_right_face_down)) {
                                const stone_dummy = Tile.init(.{ .id = .stone });
                                rl.playSound(stone_dummy.sound());
                                if (floor_tile.id == .water) {
                                    chnk.tiles[tile_idx].id = .stone;
                                } else if (wall_tile.id == .air) {
                                    chnk.tiles[tile_idx + Chunk.size * Chunk.size].id = .stone;
                                }
                            }
                        }

                        // Change walking sound to whatever tile the player is
                        // standing on
                        // TODO: Different sounds for walking on vs placing
                        // tiles
                        if (rl.checkCollisionPointRec(player_point, tile_rect)) {
                            player.standing_on = floor_tile;
                        }

                        if (wall_tile.id == .air and floor_tile.id != .water) {
                            continue;
                        }

                        if (rl.checkCollisionRecs(player_rect, tile_rect)) {
                            const collision = rl.getCollisionRec(player_rect, tile_rect);

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

        const px: i32 = @intFromFloat(player.x);
        const py: i32 = @intFromFloat(player.y);

        player_mod_x = @mod(px, Tile.size);
        player_mod_y = @mod(py, Tile.size);

        if (player.y < 0 and player_mod_y == 0) {
            player_mod_y = Tile.size;
        }

        if (player.x < 0 and player_mod_x == 0) {
            player_mod_x = Tile.size;
        }

        rl.beginDrawing();

        x = -1;
        y = -3;
        while (y * Tile.size <= height_i) : (y += 1) {
            x = -1;
            while (x * Tile.size <= width_i + Tile.size) : (x += 1) {
                for (Game.chunks) |chnk| {
                    const y_pos: f32 = @floatFromInt(y * Tile.size * scale_i - player_mod_y + screen_mod_y + 12 * scale_i);

                    const screen_width_in_tiles = width_i / (Tile.size * 2);
                    const screen_height_in_tiles = height_i / (Tile.size * 2);

                    const tile_x: i32 = @mod(x_num + x - screen_width_in_tiles, Chunk.size);
                    const tile_y: i32 = ((y_num + y) - screen_height_in_tiles - chnk.y) * Chunk.size;

                    // Skip if tile not on screen
                    if (x + x_num - screen_width_in_tiles < chnk.x or
                        x + x_num - screen_width_in_tiles >= chnk.x + Chunk.size or
                        y + y_num - screen_height_in_tiles < chnk.y or
                        y + y_num - screen_height_in_tiles >= chnk.y + Chunk.size) continue;

                    if (tile_x + tile_y < 0 or tile_x + tile_y > Chunk.size * Chunk.size) continue;

                    // Only loop through the first half of chunk Game.tiles (floor level)
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
                            if (y_pos >= Game.screen_height * Game.scale / 2) continue;

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
        //rl.DrawTexture(player.frame.*, @floatToInt(i32, Game.scale * @divTrunc(Game.screen_width, 2) - 5.5 * Game.scale), @floatToInt(i32, Game.scale * @divTrunc(Game.screen_height, 2) - 12 * Game.scale), rl.WHITE);
        drawTexture(
            player.frame.*,
            .{
                .x = @intFromFloat(
                    (Game.screen_width / 2) - 6,
                ),
                .y = @intFromFloat(
                    (Game.screen_height / 2) - 10,
                ),
            },
            rl.Color.white,
        );

        // Now draw all raised Game.tiles that sit above the player in front to give
        // an illusion of depth
        x = -1;
        y = -3;
        while (y * Tile.size <= height_i) : (y += 1) {
            x = -1;
            while (x * Tile.size <= width_i + Tile.size) : (x += 1) {
                for (Game.chunks) |chnk| {
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

                    // Only draw raised Game.tiles
                    if (chnk.tile(.wall, @intCast(tile_x), @intCast(tile_y)).id == .air) continue;

                    if (y_pos >= Game.screen_height * Game.scale / 2) {
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
        const mid = (width_i * @divTrunc(scale_i, 2) - 35 * scale_i);
        const hotbar_y = scale_i * height_i - 13 * scale_i;
        while (i < 6) {
            const hotbar_x = mid + i * scale_i * 12;
            rl.drawTexture(hotbar_item_texture, hotbar_x, hotbar_y, rl.Color.white);
            i += 1;
        }

        // Draw debug menu
        if (menu.enabled) {
            // Draws a red rectangle at the player's collision rect
            rl.drawRectangleRec(player_collision, rl.Color{ .r = 255, .g = 0, .b = 0, .a = 0x60 });
            rl.drawRectangleRec(player_rect, rl.Color{ .r = 255, .g = 0, .b = 255, .a = 0x60 });
            try menu.draw(arena);
        }

        if (settings.enabled) {
            try settings.draw(arena);
        }

        rl.endDrawing();
    }

    for (Game.chunks) |chunk| {
        try chunk.save(player.save_path, "vanilla0");
    }

    try player.save();

    rl.closeWindow();
}

fn drawTexture(texture: rl.Texture, pos: NewVec, tint: rl.Color) void {
    rl.drawTextureEx(
        texture,
        .{
            .x = @as(f32, @floatFromInt(pos.x)) * Game.scale,
            .y = @as(f32, @floatFromInt(pos.y)) * Game.scale,
        },
        0,
        Game.scale,
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
