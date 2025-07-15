const std = @import("std");
const engine = @import("../engine.zig");

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

pub fn drawText(
    string: []const u8,
    coords: Vec,
    shade: engine.Color,
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

        engine.drawTextureRect(
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

pub fn button(label: []const u8, rectangle: Rectangle) !void {
    try drawText(
        label,
        .{ .x = rectangle.x + 4, .y = rectangle.y + 4 },
        .{ .r = 255, .g = 255, .b = 255, .a = 255 },
    );

//    rl.drawRectangleLinesEx(
  //      .{
    //        .x = @as(f32, @floatFromInt(rectangle.x)) * engine.scale,
      //      .y = @as(f32, @floatFromInt(rectangle.y)) * engine.scale,
        //    .width = @as(f32, @floatFromInt(rectangle.w)) * engine.scale,
          //  .height = @as(f32, @floatFromInt(rectangle.h)) * engine.scale,
        //},
        //engine.scale,
        //rl.Color.red,
    //);
}
