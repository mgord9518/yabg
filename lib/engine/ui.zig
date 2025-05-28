const std = @import("std");
const engine = @import("../engine.zig");
const rl = @import("raylib");

pub const Vec = struct {
    x: i16,
    y: i16,
};

pub const Rectangle = struct {
    x: i16,
    y: i16,
    w: u15,
    h: u15,
};

pub fn drawTexture(texture: engine.Texture, pos: Vec, tint: rl.Color) void {
    rl.drawTextureEx(
        texture,
        .{
            .x = @floatFromInt(pos.x * engine.scale),
            .y = @floatFromInt(pos.y * engine.scale),
        },
        0,
        @floatFromInt(engine.scale),
        tint,
    );
}

pub fn drawTextureRect(texture: engine.Texture, rect: Rectangle, pos: Vec, tint: rl.Color) void {
    rl.drawTexturePro(
        texture,
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

pub fn drawText(
    string: []const u8,
    coords: Vec,
    shade: rl.Color,
) !void {
    const font_w = 5;
    const font_h = 8;

    var view = try std.unicode.Utf8View.init(string);
    var it = view.iterator();

    var y_off: u15 = 0;
    var x_off: u15 = 0;

    while (it.nextCodepoint()) |codepoint| {
        if (codepoint == '\n') {
            x_off = 0;
            y_off += font_h;
            continue;
        }

        drawTextureRect(
            engine.font.atlas,
            .{
                .x = @intCast(engine.font.glyph_offsets.get(codepoint) orelse 0),
                .y = 0,

                // Add one to include shadow
                .w = font_w + 1,
                .h = font_h + 1,
            },
            .{
                .x = coords.x + x_off,
                .y = coords.y + y_off,
            },
            shade,
        );

        x_off += font_w;
    }
}

pub fn drawRect(rect: Rectangle, tint: rl.Color) void {
    rl.drawRectangleRec(
        .{
            .x = @floatFromInt(rect.x * engine.scale),
            .y = @floatFromInt(rect.y * engine.scale),
            .width = @floatFromInt(rect.w * engine.scale),
            .height = @floatFromInt(rect.h * engine.scale),
        },
        tint,
    );
}

pub fn button(label: []const u8, rectangle: Rectangle) !void {
    try drawText(
        label,
        .{ .x = rectangle.x + 4, .y = rectangle.y + 4 },
        rl.Color.white,
    );

    rl.drawRectangleLinesEx(
        .{
            .x = @as(f32, @floatFromInt(rectangle.x)) * engine.scale,
            .y = @as(f32, @floatFromInt(rectangle.y)) * engine.scale,
            .width = @as(f32, @floatFromInt(rectangle.w)) * engine.scale,
            .height = @as(f32, @floatFromInt(rectangle.h)) * engine.scale,
        },
        engine.scale,
        rl.Color.red,
    );
}
