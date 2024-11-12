const rl = @import("raylib");
const std = @import("std");
const os = std.os;

const Chunk = @import("Chunk.zig");
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

frame: *rl.Texture2D = undefined,
frames_idle: [1]rl.Texture2D = undefined,

// Top-level array is the animation, 2nd is the current frame
frames: [5][8]rl.Texture2D = undefined,

frame_num: u3 = 0,
frame_sub: f32 = 0,

animation: Animation = .idle,
direction: Direction,

standing_on: Tile,

save_path: []const u8,

const PlayerJson = struct {
    x: i64,
    y: i64,

    direction: Direction,
};

pub fn init(save_path: []const u8) Player {
    const cwd = std.fs.cwd();
    var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;

    var player = Player{
        .save_path = save_path,
        .standing_on = Tile.init(.{ .id = .grass }),
        .direction = .down,
    };

    // TODO: Allow saving more than one player
    const player_file = std.fmt.bufPrint(
        &buf,
        "{s}/entities/players/0.json",
        .{player.save_path},
    ) catch unreachable;

    var file = cwd.openFile(player_file, .{}) catch {
        return player;
    };

    var json_buf: [4096]u8 = undefined;
    const json_data_len = file.read(&json_buf) catch unreachable;

    var fba_buf: [4096]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&fba_buf);
    const allocator = fba.allocator();

    std.debug.print("data: {s}\n", .{json_buf[0..json_data_len]});

    const player_coords: PlayerJson = std.json.parseFromSliceLeaky(
        PlayerJson,
        allocator,
        json_buf[0..json_data_len],
        .{},
    ) catch |err| {
        std.debug.print("Error loading player 0: {!}\n", .{err});

        return player;
    };

    player.x = @floatFromInt(player_coords.x);
    player.y = @floatFromInt(player_coords.y);
    player.direction = player_coords.direction;

    return player;
}

pub fn save(player: *Player) !void {
    const cwd = std.fs.cwd();

    var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;

    const path = try std.fmt.bufPrint(
        &buf,
        "{s}/entities/players",
        .{player.save_path},
    );

    cwd.makePath(path) catch |err| {
        if (err != error.PathAlreadyExists) {
            std.debug.print("fail to save player data: {!}", .{err});
        }
    };

    var fbs_buf: [4096]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&fbs_buf);

    try std.json.stringify(
        PlayerJson{
            .x = @intFromFloat(player.x),
            .y = @intFromFloat(player.y),
            .direction = player.direction,
        },
        .{},
        fbs.writer(),
    );

    // TODO: Allow saving more than one player
    const player_file = try std.fmt.bufPrint(
        &buf,
        "{s}/entities/players/0.json",
        .{player.save_path},
    );

    var file = try cwd.createFile(player_file, .{});

    _ = try file.write(fbs_buf[0..fbs.pos]);
}

pub fn getFrame(self: *Player, animation: Animation, frame_num: u3) *rl.Texture {
    return &self.frames[@intFromEnum(animation)][frame_num];
}

pub fn updateAnimation(self: *Player) void {
    self.animation = switch (self.direction) {
        .right => .walk_right,
        .left => .walk_left,
        .down => .walk_down,
        .up => .walk_up,
    };
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

    player.frame_sub += Game.tps * 0.4 * Game.delta * @abs(speed);

    if (player.frame_sub >= 1) {
        player.frame_sub -= 1;
        player.frame_num +%= 1;

        if (player.frame_num == 2 or player.frame_num == 6) {
            // Dummy tile
            //rl.PlaySound(Tile.init(.{ .id = .grass }).sound());
            rl.playSound(player.standing_on.sound());
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
    var chunk_x = @as(i32, @intFromFloat(@divTrunc(@divTrunc(player.x, Tile.size), Chunk.size)));
    var chunk_y = @as(i32, @intFromFloat(@divTrunc(@divTrunc(player.y, Tile.size), Chunk.size)));

    if (player.x < 0) {
        chunk_x = chunk_x - 1;
    }

    if (player.y < 0) {
        chunk_y = chunk_y - 1;
    }

    for (&Game.chunks) |*chnk| {
        const cx = @divTrunc(chnk.x, Chunk.size);
        const cy = @divTrunc(chnk.y, Chunk.size);

        if (@divTrunc(chnk.x, Chunk.size) > chunk_x + 1) {
            chnk.save(player.save_path, "vanilla0") catch unreachable;
            chnk.* = Chunk.load(player.save_path, "vanilla0", chunk_x - 1, cy) catch unreachable;
        } else if (@divTrunc(chnk.x, Chunk.size) < chunk_x - 1) {
            chnk.save(player.save_path, "vanilla0") catch unreachable;
            chnk.* = Chunk.load(player.save_path, "vanilla0", chunk_x + 1, cy) catch unreachable;
        } else if (@divTrunc(chnk.y, Chunk.size) > chunk_y + 1) {
            chnk.save(player.save_path, "vanilla0") catch unreachable;
            chnk.* = Chunk.load(player.save_path, "vanilla0", cx, chunk_y - 1) catch unreachable;
        } else if (@divTrunc(chnk.y, Chunk.size) < chunk_y - 1) {
            chnk.save(player.save_path, "vanilla0") catch unreachable;
            chnk.* = Chunk.load(player.save_path, "vanilla0", cx, chunk_y + 1) catch unreachable;
        }
    }

    // Sort chunks
    // TODO: refactor
    for (&Game.chunks) |*chunk| {
        for (&Game.chunks) |*swap_chunk| {
            if (swap_chunk.y < chunk.y) {
                const tmp = chunk.*;

                chunk.* = swap_chunk.*;
                swap_chunk.* = tmp;
            }

            if (swap_chunk.y == chunk.y and swap_chunk.x < chunk.x) {
                const tmp = chunk.*;

                chunk.* = swap_chunk.*;
                swap_chunk.* = tmp;
            }
        }
    }
}

// TODO: limit directions and use 2 (or maybe 3?) speeds if using a gamepad
// I'll probably end up doing a `sneak`, `walk` and `run`
// Currently limiting to 4 directions to simplify collision, if I can
// eventually implement it in a simple way without bugs I will re-enable
// 8 direction movement
pub fn inputVector(player: *Player) rl.Vector2 {
    _ = player;

    if (rl.isKeyDown(.key_a)) {
        return .{ .x = -1, .y = 0 };
    } else if (rl.isKeyDown(.key_d)) {
        return .{ .x = 1, .y = 0 };
    } else if (rl.isKeyDown(.key_w)) {
        return .{ .x = 0, .y = -1 };
    } else if (rl.isKeyDown(.key_s)) {
        return .{ .x = 0, .y = 1 };
    }

    const axis_x = rl.getGamepadAxisMovement(0, @intFromEnum(rl.GamepadAxis.gamepad_axis_left_x));
    const axis_y = rl.getGamepadAxisMovement(0, @intFromEnum(rl.GamepadAxis.gamepad_axis_left_y));

    const threashold = 0.25;

    if (axis_x < -threashold) {
        return .{ .x = -1, .y = 0 };
    } else if (axis_x > threashold) {
        return .{ .x = 1, .y = 0 };
    } else if (axis_y < -threashold) {
        return .{ .x = 0, .y = -1 };
    } else if (axis_y > threashold) {
        return .{ .x = 0, .y = 1 };
    }

    return .{ .x = 0, .y = 0 };
}
