const std = @import("std");
const Game = @import("Game.zig");
const rl = @import("raylib");

pub const NewVec = struct {
    x: i16,
    y: i16,
};

pub const Rectangle = struct {
    x: i16,
    y: i16,
    w: u15,
    h: u15,
};

pub fn drawText(
    string: []const u8,
    coords: NewVec,
    shade: rl.Color,
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
            Game.font.atlas,
            .{
                .x = @floatFromInt(Game.font.glyph_offsets.get(codepoint) orelse 0),
                .y = 0,
                .width = 4 + 1,
                .height = 8 + 1,
            },
            .{
                .x = (@as(f32, @floatFromInt(coords.x)) + x_off) * Game.scale,
                .y = @as(f32, @floatFromInt(coords.y)) * Game.scale + line_offset,
                .width = (4 + 1) * Game.scale,
                .height = (8 + 1) * Game.scale,
            },
            .{
                .x = 0,
                .y = 0,
            },
            0,
            shade,
        );

        x_off += 5;
    }
}

pub fn button(label: []const u8, rectangle: Rectangle) !void {
    try drawText(
        label,
        .{ .x = rectangle.x + 4, .y = rectangle.y + 4 },
        rl.Color.white,
    );

    rl.drawRectangleLinesEx(
        .{
            .x = @as(f32, @floatFromInt(rectangle.x)) * Game.scale,
            .y = @as(f32, @floatFromInt(rectangle.y)) * Game.scale,
            .width = @as(f32, @floatFromInt(rectangle.w)) * Game.scale,
            .height = @as(f32, @floatFromInt(rectangle.h)) * Game.scale,
        },
        Game.scale,
        rl.Color.red,
    );
}
