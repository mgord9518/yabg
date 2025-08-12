const std = @import("std");

const root = @import("root");
const engine = @import("../../engine.zig");

const imports = struct {
    extern fn consoleLog(arg: u32) void;
    extern fn getWindowWidth() u32;
    extern fn getWindowHeight() u32;
    extern fn endDrawing() void;
    extern fn run() void;
};

const allocator = std.heap.wasm_allocator;

const Event = enum {
    click,
};

var mouse_pos = engine.Coordinate{ .x = 0, .y = 0 };

var fb: []TrueColor = undefined;

pub fn init() void {
    yabgEngine_init();
}

export fn yabgEngine_init() void {
    engine.screen_width = @intCast(imports.getWindowWidth() / engine.scale);
    engine.screen_height = @intCast(imports.getWindowHeight() / engine.scale);

    fb = allocator.alloc(
        TrueColor,
        @as(u32, engine.screen_width) * engine.screen_height,
    ) catch unreachable;
}

export fn yabgEngine_moveMouse(x: i32, y: i32) void {
    mouse_pos = .{
        .x = @divTrunc(x, engine.scale),
        .y = @divTrunc(y, engine.scale),
    };
}

pub fn mousePosition() engine.Coordinate {
    return mouse_pos;
}

pub fn beginDrawing() void {
}

pub fn endDrawing() void {
    imports.endDrawing();
}

export fn resetSize() void {
    const old_width = engine.screen_width;
    const old_height = engine.screen_height;
    engine.screen_width = @intCast(imports.getWindowWidth() / engine.scale);
    engine.screen_height = @intCast(imports.getWindowHeight() / engine.scale);

    if (old_width != engine.screen_width or old_height != engine.screen_height) {
        allocator.free(fb);

        fb = allocator.alloc(
            TrueColor,
            @as(u32, engine.screen_width) * engine.screen_height,
        ) catch unreachable;
    }
}

pub fn clearBackground(color: engine.Color) void {
    const true_color = TrueColor.fromColor(color);

    @memset(fb, true_color);
}

pub fn drawImage(image: engine.ImageNew, pos: engine.Coordinate) void {
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

        if (color.a > 0) {
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

pub const TrueColor = packed struct(u32) {
    r: u8,
    g: u8,
    b: u8,
    a: u8 = 255,

    pub fn fromColor(color: engine.Color) TrueColor {
        return .{
            .r = @as(u8, color.r) * 17,
            .g = @as(u8, color.g) * 17,
            .b = @as(u8, color.b) * 17,
            .a = @as(u8, color.a) * 255,
        };
    }
};

export fn getCanvasBufferPointer() [*]u8 {
    return @ptrCast(fb.ptr);
}

export fn getCanvasWidth() usize {
    return engine.screen_width;
}

export fn getCanvasHeight() usize {
    return engine.screen_height;
}
