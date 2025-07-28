const std = @import("std");

const engine = @import("engine");
const textures = @import("textures.zig");

const allocator = std.heap.wasm_allocator;

var x_off: usize = 0;
export fn callbacke(timestamp: f64) void {
    _ = timestamp;
    update();
}

// Called once at program initialization
pub export fn init() void {
}

// Called on every frame
pub export fn update() void {
    engine.beginDrawing();

    engine.backend.clearBackground(.{
        .r = 0,
        .g = 12,
        .b = 12,
    });

    @constCast(&textures.tiles.grass).draw(
        .{
            .x = x_off,
            .y = 15,
        },
    );

    x_off += 1;

    if (x_off > engine.screen_width) x_off = 0;

    engine.endDrawing();
}

fn updaw() void {
    engine.beginDrawing();

    engine.backend.clearBackground(.{
        .r = 15,
        .g = 12,
        .b = 15,
    });

    //engine.backend.run(allocator, f) catch {};

    textures.tiles.grass.draw(
        .{
            .x = 2,
            .y = 2,
        },
    );

    textures.tiles.sand.draw(
        .{
            .x = 2 + (12),
            .y = 2,
        },
    );

    textures.tiles.stone.draw(
        .{
            .x = 2 + (24),
            .y = 2,
        },
    );

    engine.endDrawing();
}

export fn engineScale() u32 {
    return engine.scale;
}
