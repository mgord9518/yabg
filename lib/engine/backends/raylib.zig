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

pub fn init(allocator: std.mem.Allocator, window_width: u32, window_height: u32) !void {
    raylib.SetConfigFlags(raylib.FLAG_VSYNC_HINT | raylib.FLAG_WINDOW_RESIZABLE);

    raylib.SetTraceLogLevel(raylib.LOG_ERROR);
    raylib.InitAudioDevice();

    const title = try std.fmt.allocPrintZ(allocator, "YABG {}", .{engine.version});
    defer allocator.free(title);

    raylib.InitWindow(@intCast(window_width), @intCast(window_height), title);
    raylib.SetWindowMinSize(@intCast(128 * engine.scale), @intCast(128 * engine.scale));
    raylib.HideCursor();

    root.init();
}

const Rgba4 = packed struct(u16) {
    a: u4,
    b: u4,
    g: u4,
    r: u4,
};

pub fn textureFromImage(allocator: std.mem.Allocator, image: engine.ImageNew) !Texture {
    // Won't need this after the texture has been loaded from the image
    const data = try allocator.alloc(Rgba4, image.w * image.h);
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
}

pub fn endDrawing() void {
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

pub fn screenWidth() u32 {
    return @intCast(raylib.GetScreenWidth());
}

pub fn screenHeight() u32 {
    return @intCast(raylib.GetScreenHeight());
}

pub fn getFps() usize {
    return @intCast(raylib.GetFPS());
}

pub export fn run() void {
    while (!raylib.WindowShouldClose()) {
        root.update();
        engine.delta = deltaTime();

        engine.screen_width = @divTrunc(
            @as(u15, @intCast(screenWidth())),
            engine.scale,
        );

        engine.screen_height = @divTrunc(
            @as(u15, @intCast(screenHeight())),
            engine.scale,
        );
    }
}

pub fn shouldContinueRunning() bool {
    return !raylib.WindowShouldClose();
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

pub fn drawImage(image: engine.ImageNew, pos: engine.Coordinate) void {
    drawTexture(image.maybe_texture.?, pos, .{ .r = 255, .g = 255, .b = 255, .a = 255 });
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

