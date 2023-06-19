const rl = @import("raylib");
const std = @import("std");

const Chunk = @import("Chunk.zig").Chunk;
const Tile = @import("Tile.zig").Tile;
const Direction = @import("enums.zig").Direction;
const Animation = @import("enums.zig").Animation;
const Game = @import("Game.zig");

const Player = @This();

// The max speed at which the player is allowed to walk
pub var walk_speed: f32 = 2;

x: f32 = 0,
y: f32 = 0,

// Current speeds
x_speed: f32 = 0,
y_speed: f32 = 0,

// Chunk coords, this is used to check when the player has moved over a chunk boundry
cx: i32 = 0,
cy: i32 = 0,

frame: *rl.Texture2D = undefined,
frames_idle: [1]rl.Texture2D = undefined,

// Top-level array is the animation, 2nd is the current frame
frames: [5][8]rl.Texture2D = undefined,

frame_num: u3 = 0,
frame_sub: f32 = 0,

animation: Animation = .idle,

standing_on: Tile,

save_path: []const u8,

pub fn init(save_path: []const u8) Player {
    return Player{
        .save_path = save_path,
        .standing_on = Tile.init(.{ .id = .grass }),
    };
}

pub fn getFrame(self: *Player, animation: Animation, frame_num: u3) *rl.Texture2D {
    return &self.frames[@enumToInt(animation)][frame_num];
}

pub fn updatePlayerFrames(
    player: *Player,
    animation: Animation,
) void {
    var speed: f32 = undefined;

    if (player.x_speed != 0 and player.y_speed != 0) {
        // Not really sure why this number works but it does
        speed = std.math.sqrt((player.x_speed * player.x_speed) + (player.y_speed * player.y_speed)) * 0.8;
    } else {
        speed = std.math.sqrt((player.x_speed * player.x_speed) + (player.y_speed * player.y_speed));
    }

    player.frame_sub += Game.tps * 0.4 * Game.delta * @fabs(speed);

    if (player.frame_sub >= 1) {
        player.frame_sub -= 1;
        player.frame_num +%= 1;

        if (player.frame_num == 2 or player.frame_num == 6) {
            // Dummy tile
            //rl.PlaySound(Tile.init(.{ .id = .grass }).sound());
            rl.PlaySound(player.standing_on.sound());
        }
    }

    // Given an FPS of 60, this means that the animation will
    // update at 14 FPS
    player.frame = player.getFrame(animation, player.frame_num);
    //std.debug.print("{}\n", .{animation});
}

// Checks and unloads any Game.chunks not surrounding the player in a 9x9 area
// then loads new Game.chunks into their pointers
// Not yet sure how robust this is
pub fn reloadChunks(player: *Player) void {
    var cx_origin = @floatToInt(i32, @divTrunc(@divTrunc(player.x, Tile.size), Chunk.size));
    var cy_origin = @floatToInt(i32, @divTrunc(@divTrunc(player.y, Tile.size), Chunk.size));

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

    for (&Game.chunks) |*chnk| {
        const cx = @divTrunc(chnk.x, Chunk.size);
        const cy = @divTrunc(chnk.y, Chunk.size);

        if (@divTrunc(chnk.x, Chunk.size) > cx_origin + 1) {
            chnk.* = Chunk.load(player.save_path, "vanilla0", cx_origin - 1, cy) catch unreachable;
        } else if (@divTrunc(chnk.x, Chunk.size) < cx_origin - 1) {
            chnk.* = Chunk.load(player.save_path, "vanilla0", cx_origin + 1, cy) catch unreachable;
        } else if (@divTrunc(chnk.y, Chunk.size) > cy_origin + 1) {
            chnk.* = Chunk.load(player.save_path, "vanilla0", cx, cy_origin - 1) catch unreachable;
        } else if (@divTrunc(chnk.y, Chunk.size) < cy_origin - 1) {
            chnk.* = Chunk.load(player.save_path, "vanilla0", cx, cy_origin + 1) catch unreachable;
        }
    }
}

// TODO: limit to 8 directions and 2 (or maybe 3? speeds)
// I'll probably end up doing a `sneak`, `walk` and `run`
pub fn inputVector(player: *Player) rl.Vector2 {
    _ = player;

    if (rl.IsKeyDown(.KEY_A) and rl.IsKeyDown(.KEY_S)) {
        return .{ .x = -0.7, .y = 0.7 };
    } else if (rl.IsKeyDown(.KEY_A) and rl.IsKeyDown(.KEY_W)) {
        return .{ .x = -0.7, .y = -0.7 };
    } else if (rl.IsKeyDown(.KEY_D) and rl.IsKeyDown(.KEY_S)) {
        return .{ .x = 0.7, .y = 0.7 };
    } else if (rl.IsKeyDown(.KEY_D) and rl.IsKeyDown(.KEY_W)) {
        return .{ .x = 0.7, .y = -0.7 };
    }

    if (rl.IsKeyDown(.KEY_A)) {
        return .{ .x = -1, .y = 0 };
    } else if (rl.IsKeyDown(.KEY_D)) {
        return .{ .x = 1, .y = 0 };
    } else if (rl.IsKeyDown(.KEY_W)) {
        return .{ .x = 0, .y = -1 };
    } else if (rl.IsKeyDown(.KEY_S)) {
        return .{ .x = 0, .y = 1 };
    }

    const axis_x = rl.GetGamepadAxisMovement(0, .GAMEPAD_AXIS_LEFT_X);
    const axis_y = rl.GetGamepadAxisMovement(0, .GAMEPAD_AXIS_LEFT_Y);

    var ret: rl.Vector2 = .{
        .x = 0,
        .y = 0,
    };

    const threashold = 0.25;

    if (axis_x < -threashold and axis_y > threashold) {
        return .{ .x = -0.7, .y = 0.7 };
    } else if (axis_x < -threashold and axis_y < -threashold) {
        return .{ .x = -0.7, .y = -0.7 };
    } else if (axis_x > threashold and axis_y < -threashold) {
        return .{ .x = 0.7, .y = -0.7 };
    } else if (axis_x > threashold and axis_y > threashold) {
        return .{ .x = 0.7, .y = 0.7 };
    }

    if (axis_x < -threashold) {
        return .{ .x = -1, .y = 0 };
    } else if (axis_x > threashold) {
        return .{ .x = 1, .y = 0 };
    } else if (axis_y < -threashold) {
        return .{ .x = 0, .y = -1 };
    } else if (axis_y > threashold) {
        return .{ .x = 0, .y = 1 };
    }

    return ret;

    //std.debug.print("{d}:{d}\n", .{ vec.x, vec.y });
}
