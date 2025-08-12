const std = @import("std");

const root = @import("root");
const raylib = @cImport({
    @cInclude("raylib.h");
});

pub const Image = raylib.Image;
pub const Texture = raylib.Texture;
pub const Sound = raylib.Sound;
pub const Color = raylib.Color;

pub const ImageFormat = enum(c_int) {
    uncompressed_gray_alpha = raylib.PIXELFORMAT_UNCOMPRESSED_GRAY_ALPHA,
};

const engine = @import("../../engine.zig");
const resource_root = "../../engine/";

var allocator: std.mem.Allocator = undefined;

var fb: []TrueColor = undefined;

pub const TrueColor = packed struct(u16) {
    a: u4,
    b: u4,
    g: u4,
    r: u4,

    pub fn fromColor(color: engine.Color) TrueColor {
        return .{
            .r = color.r,
            .g = color.g,
            .b = color.b,
            .a = 15,
        };
    }
};

pub fn init(a: std.mem.Allocator, window_width: u32, window_height: u32) !void {
    allocator = a;
    raylib.SetConfigFlags(raylib.FLAG_VSYNC_HINT | raylib.FLAG_WINDOW_RESIZABLE);

    raylib.SetTraceLogLevel(raylib.LOG_ERROR);
    raylib.InitAudioDevice();

    const title = try std.fmt.allocPrintZ(allocator, "YABG {}", .{engine.version});
    defer allocator.free(title);

    raylib.InitWindow(@intCast(window_width), @intCast(window_height), title);
    raylib.SetWindowMinSize(@intCast(128 * engine.scale), @intCast(128 * engine.scale));
    raylib.HideCursor();

    // TODO: remove hacky fix
    engine.screen_width = 0;
    resetSize();

    root.init();
}

fn resetSize() void {
    const old_width = engine.screen_width;
    const old_height = engine.screen_height;
    engine.screen_width = @intCast(@divTrunc(raylib.GetScreenWidth(), engine.scale));
    engine.screen_height = @intCast(@divTrunc(raylib.GetScreenHeight(), engine.scale));

    if (old_width != engine.screen_width or old_height != engine.screen_height) {
        allocator.free(fb);

        fb = allocator.alloc(
            TrueColor,
            @as(u32, engine.screen_width) * engine.screen_height,
        ) catch unreachable;
    }
}

const Rgba4 = packed struct(u16) {
    a: u4,
    b: u4,
    g: u4,
    r: u4,
};

pub fn textureFromImage(a: std.mem.Allocator, image: engine.ImageNew) !Texture {
    _ = a;
    // Won't need this after the texture has been loaded from the image
    const data = try allocator.alloc(Rgba4, @as(u31, image.w) * image.h);
    defer allocator.free(data);

    const temp_image = Image{
        .data = data.ptr,

        .width = image.w,
        .height = image.h,

        .mipmaps = 1,
        .format = raylib.PIXELFORMAT_UNCOMPRESSED_R4G4B4A4,
    };

    for (image.data, 0..) |_, idx| {
        const palette_idx = image.data[idx];
        const palette_color = image.palette[palette_idx];

        data[idx] = .{
            .r = palette_color.r,
            .g = palette_color.g,
            .b = palette_color.b,
            .a = @as(u4, palette_color.a) * 15,
        };
    }

    return loadTextureFromImage(temp_image);
}

pub fn beginDrawing() void {
    raylib.BeginDrawing();
    raylib.ClearBackground(raylib.BLACK);
    clearBackground(.{ .r = 15, .g = 0, .b = 15 });
}

pub fn clearBackground(color: engine.Color) void {
    const true_color = TrueColor.fromColor(color);

    @memset(fb, true_color);
}

pub fn endDrawing() void {
    const fb_image = raylib.Image{
        .data = @ptrCast(fb.ptr),
        .width = engine.screen_width,
        .height = engine.screen_height,
        .mipmaps = 1,
        .format = raylib.PIXELFORMAT_UNCOMPRESSED_R4G4B4A4,
    };

    const fb_texture = raylib.LoadTextureFromImage(fb_image);
    defer raylib.UnloadTexture(fb_texture);

//    raylib.DrawTexture(fb_texture, 0, 0, raylib.WHITE);

    raylib.EndDrawing();
}

pub fn closeWindow() void {
    raylib.CloseWindow();
}

fn isButtonImpl(comptime keyboardFn: fn (c_int) callconv(.C) bool, comptime gamepadFn: fn (c_int, c_int) callconv(.C) bool) fn (c_int, c_int) bool {
    return struct {
        fn impl(keyboard_key: c_int, gamepad_button: c_int) bool {
            return keyboardFn(keyboard_key) or gamepadFn(0, gamepad_button);
        }
    }.impl;
}

fn buttonCheckImpl(buttonImpl: fn (c_int, c_int) bool, button: engine.Button) bool {
    return switch (button) {
        .left => buttonImpl(raylib.KEY_A, raylib.GAMEPAD_BUTTON_RIGHT_FACE_LEFT),
        .right => buttonImpl(raylib.KEY_D, raylib.GAMEPAD_BUTTON_RIGHT_FACE_RIGHT),
        .up => buttonImpl(raylib.KEY_W, raylib.GAMEPAD_BUTTON_RIGHT_FACE_UP),
        .down => buttonImpl(raylib.KEY_S, raylib.GAMEPAD_BUTTON_RIGHT_FACE_DOWN),
        .debug => buttonImpl(raylib.KEY_F3, raylib.GAMEPAD_BUTTON_MIDDLE_LEFT),
        .primary => buttonImpl(raylib.KEY_PERIOD, raylib.GAMEPAD_BUTTON_RIGHT_FACE_LEFT),
        .secondary => buttonImpl(raylib.KEY_SLASH, raylib.GAMEPAD_BUTTON_RIGHT_FACE_DOWN),
        .inventory_previous => buttonImpl(raylib.KEY_LEFT, 0),
        .inventory_next => buttonImpl(raylib.KEY_RIGHT, 0),
        .inventory_0 => buttonImpl(raylib.KEY_ONE, 0),
        .inventory_1 => buttonImpl(raylib.KEY_TWO, 0),
        .inventory_2 => buttonImpl(raylib.KEY_THREE, 0),
        .inventory_3 => buttonImpl(raylib.KEY_FOUR, 0),
        .inventory_4 => buttonImpl(raylib.KEY_FIVE, 0),
        .inventory_5 => buttonImpl(raylib.KEY_SIX, 0),
    };
}

pub fn isButtonDown(button: engine.Button) bool {
    const buttonImpl = isButtonImpl(raylib.IsKeyDown, raylib.IsGamepadButtonDown);

    return buttonCheckImpl(buttonImpl, button);
}

pub fn isButtonPressed(button: engine.Button) bool {
    const buttonImpl = isButtonImpl(raylib.IsKeyPressed, raylib.IsGamepadButtonPressed);

    return buttonCheckImpl(buttonImpl, button);
}

pub fn deltaTime() f32 {
    return raylib.GetFrameTime();
}

pub fn getFps() usize {
    return @intCast(raylib.GetFPS());
}

pub export fn run() void {
    while (!raylib.WindowShouldClose()) {
        resetSize();
        root.update();
        engine.delta = deltaTime();

    }
}

pub fn playSound(sound: Sound, pitch: f32) void {
    raylib.SetSoundPitch(sound, pitch);
    raylib.PlaySound(sound);
}

pub fn loadTextureEmbedded(comptime path: []const u8) Texture {
    const format = ".png";

    const embedded_file = @embedFile(resource_root ++ "textures/" ++ path ++ format);

    const image = raylib.LoadImageFromMemory(
        format,
        embedded_file,
        embedded_file.len,
    );

    return loadTextureFromImage(image);
}

pub fn loadTextureFromImage(image: Image) Texture {
    return raylib.LoadTextureFromImage(image);
}

pub fn loadSoundEmbedded(comptime path: []const u8) Sound {
    const format = ".ogg";

    const embedded_file = @embedFile(resource_root ++ "sounds/" ++ path ++ format);

    const wave = raylib.LoadWaveFromMemory(
        format,
        embedded_file,
        embedded_file.len,
    );

    return raylib.LoadSoundFromWave(wave);
}

pub fn mousePosition() engine.Coordinate {
    const pos = raylib.GetMousePosition();
    const unscaled_pos = engine.Coordinate{
        .x = @intFromFloat(pos.x),
        .y = @intFromFloat(pos.y),
    };

    return .{
        .x = @divTrunc(unscaled_pos.x, engine.scale),
        .y = @divTrunc(unscaled_pos.y, engine.scale),
    };
}

pub fn drawImageOld(image: engine.ImageNew, pos: engine.Coordinate) void {
    drawTexture(image.maybe_texture.?, pos, .{ .r = 255, .g = 255, .b = 255, .a = 255 });
}

pub fn drawImage(image: engine.ImageNew, pos: engine.Coordinate) void {
    if (image.maybe_texture != null) {
        drawImageOld(image, pos);
    }

    const x: i32 = @intCast(pos.x);
    const y: i32 = @intCast(pos.y);

    // Skip drawing if completely off screen
    if (@as(i32, image.w) +| x < 0) return;
    if (@as(i32, image.h) +| y < 0) return;
    if (x >= engine.screen_width) return;
    if (y >= engine.screen_height) return;

    var x_idx: usize = @intCast(@max(0, x));
    var y_idx: usize = @intCast(@max(0, y));
    var img_x_offset: usize = @intCast(@abs(@min(x, 0)));
    var img_y_offset: usize = @intCast(@abs(@min(y, 0)));

    while (img_x_offset < image.w and img_y_offset < image.h and y_idx < engine.screen_height) {
        const palette_idx = image.data[@as(u32, @intCast(img_y_offset)) * image.w + @as(u32, @intCast(img_x_offset))];
        const color = TrueColor.fromColor(image.palette[palette_idx]);

        if (image.palette[palette_idx].a > 0) {
            fb[(y_idx * engine.screen_width) + x_idx] = color;
        }

        x_idx += 1;
        img_x_offset += 1;

        if (img_x_offset == image.w or x_idx == engine.screen_width) {
            img_y_offset += 1;
            x_idx = @max(x, 0);
            y_idx += 1;
            img_x_offset = @abs(@min(x, 0));
        }
    }
}

pub fn drawTexture(texture: engine.Texture, pos: engine.Coordinate, tint: Color) void {
    raylib.DrawTextureEx(
        @bitCast(texture),
        .{
            .x = @floatFromInt(pos.x * engine.scale),
            .y = @floatFromInt(pos.y * engine.scale),
        },
        0,
        @floatFromInt(engine.scale),
        tint,
    );
}

pub fn drawTextureRect(texture: engine.Texture, rect: engine.ui.Rectangle, pos: engine.Coordinate, tint: Color) void {
    raylib.DrawTexturePro(
        @bitCast(texture),
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

pub fn drawRect(rect: engine.Rectangle, tint: Color) void {
    raylib.DrawRectangleRec(
        .{
            .x = @floatFromInt(rect.x * engine.scale),
            .y = @floatFromInt(rect.y * engine.scale),
            .width = @floatFromInt(rect.w * engine.scale),
            .height = @floatFromInt(rect.h * engine.scale),
        },
        tint,
    );
}

