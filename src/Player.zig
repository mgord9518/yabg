const rl = @import("raylib");
const std = @import("std");

const Chunk = @import("Chunk.zig").Chunk;
const Tile = @import("Tile.zig").Tile;
const Direction = @import("enums.zig").Direction;
const Animation = @import("enums.zig").Animation;
const Game = @import("Game.zig").Game;

pub const Player = struct {
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

    frame_num: usize = 0,
    frame_sub: f32 = 0,

    animation: Animation = .idle,

    save_path: []const u8,

    pub fn init(save_path: []const u8) Player {
        return Player{ .save_path = save_path };
    }

    pub fn updatePlayerFrames(
        player: *Player,
        frame: Animation,
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
            player.frame_num += 1;

            if (player.frame_num == 2 or player.frame_num == 6) {
                // Dummy tile
                rl.PlaySound(Tile.init(.{ .id = .grass }).sound());
            }
        }

        if (player.frame_num > 7) {
            player.frame_num = 0;
        }

        // Given an FPS of 60, this means that the animation will
        // update at 14 FPS
        switch (frame) {
            .idle => player.frame = &player.frames[0][0],
            .walk_left => {
                player.frame = &player.frames[1][player.frame_num];
            },
            .walk_right => {
                player.frame = &player.frames[2][player.frame_num];
            },
            .walk_up => player.frame = &player.frames[4][player.frame_num],
            .walk_down => player.frame = &player.frames[3][player.frame_num],
        }
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

        var vec: rl.Vector2 = undefined;

        if (rl.IsKeyDown(.KEY_A) and rl.IsKeyDown(.KEY_S)) {
            vec.x = -0.7;
            vec.y = -0.7;
        } else if (rl.IsKeyDown(.KEY_A) and rl.IsKeyDown(.KEY_W)) {
            vec.x = -0.7;
            vec.y = 0.7;
        } else if (rl.IsKeyDown(.KEY_D) and rl.IsKeyDown(.KEY_S)) {
            vec.x = 0.7;
            vec.y = -0.7;
        } else if (rl.IsKeyDown(.KEY_D) and rl.IsKeyDown(.KEY_W)) {
            vec.x = 0.7;
            vec.y = 0.7;
        } else if (rl.IsKeyDown(.KEY_A)) {
            vec.x = -1;
        } else if (rl.IsKeyDown(.KEY_D)) {
            vec.x = 1;
        } else {
            vec.x = rl.GetGamepadAxisMovement(0, .GAMEPAD_AXIS_LEFT_X);
        }

        if (rl.IsKeyDown(.KEY_W)) {
            vec.y = -1;
        } else if (rl.IsKeyDown(.KEY_S)) {
            vec.y = 1;
        } else {
            vec.y = rl.GetGamepadAxisMovement(0, .GAMEPAD_AXIS_LEFT_Y);
        }

        return vec;
    }
};
