const rl = @import("raylib");
const std = @import("std");

const known_folders = @import("known-folders");

const Chunk = @import("Chunk.zig");
const Tile = @import("Tile.zig").Tile;
const Direction = @import("enums.zig").Direction;
const Animation = @import("enums.zig").Animation;
const engine = @import("engine/init.zig");
const Game = engine;
const Entity = @import("Entity.zig");

const Player = @This();

// The max speed at which the player is allowed to walk
pub var walk_speed: f32 = 2;

entity: Entity,
invintory: [6]?Game.Item,

standing_on: Tile,

save_path: []const u8,

const PlayerJson = struct {
    x: i64,
    y: i64,

    direction: Direction,
};

pub fn init(allocator: std.mem.Allocator, save_path: []const u8) !Player {
    const cwd = std.fs.cwd();
    var buf: [std.fs.max_path_bytes]u8 = undefined;

    const exe_path = (try known_folders.getPath(allocator, .executable_dir)).?;
    const app_dir = try std.fs.path.joinZ(
        allocator,
        &.{ exe_path, "../.." },
    );

    allocator.free(exe_path);
    defer allocator.free(app_dir);

    var player = Player{
        .save_path = save_path,
        .standing_on = Tile.init(.{ .id = .grass }),
        .entity = .{
            .direction = .down,
            .animation_texture = undefined,
        },
        .invintory = .{null} ** 6,
    };

    player.invintory[0] = .{ .value = .{ .tile = .stone }, .count = 12 };

    inline for (std.meta.fields(Animation)) |animation| {
        const animation_texture = engine.loadTextureEmbedded("entities/player_" ++ animation.name);

        player.entity.animation_texture[animation.value] = animation_texture;
    }

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

    const player_coords = std.json.parseFromSlice(
        PlayerJson,
        allocator,
        json_buf[0..json_data_len],
        .{},
    ) catch |err| {
        std.debug.print("Error loading player 0: {!}\n", .{err});

        return player;
    };

    defer player_coords.deinit();

    player.entity.x = @floatFromInt(player_coords.value.x);
    player.entity.y = @floatFromInt(player_coords.value.y);
    player.entity.direction = player_coords.value.direction;

    return player;
}

pub fn save(player: *Player) !void {
    const cwd = std.fs.cwd();

    var buf: [std.fs.max_path_bytes]u8 = undefined;

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
            .x = @intFromFloat(player.entity.x),
            .y = @intFromFloat(player.entity.y),
            .direction = player.entity.direction,
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

pub fn updateAnimation(self: *Player) void {
    self.entity.animation = switch (self.entity.direction) {
        .right => .walk_right,
        .left => .walk_left,
        .down => .walk_down,
        .up => .walk_up,
    };
}

pub fn updatePlayerFrames(
    player: *Player,
) void {
    if (player.entity.remaining_x != 0 or player.entity.remaining_y != 0) {
        player.entity.frame_sub += Game.tps * 0.4 * Game.delta;
    }

    if (player.entity.frame_sub >= 1) {
        player.entity.frame_sub -= 1;
        player.entity.frame_num +%= 1;

        if (player.entity.frame_num == 2 or player.entity.frame_num == 6) {
            rl.playSound(player.standing_on.sound());
        }
    }
}

// Checks and unloads any Game.chunks not surrounding the player in a 9x9 area
// then loads new Game.chunks into their pointers
// Not yet sure how robust this is
pub fn reloadChunks(player: *Player) void {
    var chunk_x = @as(i32, @intFromFloat(@divTrunc(@divTrunc(player.entity.x, Tile.size), Chunk.size)));
    var chunk_y = @as(i32, @intFromFloat(@divTrunc(@divTrunc(player.entity.y, Tile.size), Chunk.size)));

    if (player.entity.x < 0) {
        chunk_x = chunk_x - 1;
    }

    if (player.entity.y < 0) {
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
            if (swap_chunk.y > chunk.y) {
                const tmp = chunk.*;

                chunk.* = swap_chunk.*;
                swap_chunk.* = tmp;
            }

            if (swap_chunk.y == chunk.y and swap_chunk.x > chunk.x) {
                const tmp = chunk.*;

                chunk.* = swap_chunk.*;
                swap_chunk.* = tmp;
            }
        }
    }
}

pub fn inputVector(player: *Player) rl.Vector2 {
    _ = player;

    if (rl.isKeyDown(.a)) {
        return .{ .x = -1, .y = 0 };
    } else if (rl.isKeyDown(.d)) {
        return .{ .x = 1, .y = 0 };
    } else if (rl.isKeyDown(.w)) {
        return .{ .x = 0, .y = -1 };
    } else if (rl.isKeyDown(.s)) {
        return .{ .x = 0, .y = 1 };
    }

    const axis_x = rl.getGamepadAxisMovement(0, .left_x);
    const axis_y = rl.getGamepadAxisMovement(0, .left_y);

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
