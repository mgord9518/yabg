const rl = @import("raylib");
const std = @import("std");

const known_folders = @import("known-folders");

const Chunk  = @import("Chunk.zig");
const engine = @import("../engine.zig");
const Entity = @import("Entity.zig");

const Player = @This();

entity: Entity,
inventory: engine.Inventory,

standing_on: ?*const engine.Tile = null,

save_path: []const u8,

const PlayerJson = struct {
    pos: engine.Coordinate,

    inventory: engine.Inventory,

    direction: Entity.Direction,
};

pub fn init(allocator: std.mem.Allocator, save_path: []const u8) !Player {
    const cwd = std.fs.cwd();
    var buf: [std.fs.max_path_bytes]u8 = undefined;

    var player = Player{
        .save_path = save_path,
        .entity = .{
            .direction = .down,
            .animation_texture = undefined,
        },
        .inventory = engine.Inventory{},
    };

    inline for (std.meta.fields(Entity.Animation)) |animation| {
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

    player.entity.pos = player_coords.value.pos;
    player.entity.direction = player_coords.value.direction;
    player.inventory = player_coords.value.inventory;

    return player;
}

// Updates player state based on input
pub fn updateState(player: *Player) !void {
    // Keyboard/gamepad inputs
    const input_vec = player.inputVector();

    const previous_direction = player.entity.direction;

    if (player.entity.remaining_x == 0 and player.entity.remaining_y == 0) {
        if (input_vec.x > 0) {
            player.entity.direction = .right;
        } else if (input_vec.x < 0) {
            player.entity.direction = .left;
        } else if (input_vec.y > 0) {
            player.entity.direction = .down;
        } else if (input_vec.y < 0) {
            player.entity.direction = .up;
        }
    }

    if (previous_direction != player.entity.direction) {
        return;
    }

    // Collision detection
    var player_tile_offset_x: u16 = @intCast(@mod(player.entity.pos.x, Chunk.size));
    var player_tile_offset_y: u16 = @intCast(@mod(player.entity.pos.y, Chunk.size));

    // Middle chunk
    var target_chunk_num: usize = 4;

    // Find chunk player is looking at
    if (player_tile_offset_x == 0 and player.entity.direction == .left ) {
        if (player.entity.pos.x >= 0) {
            target_chunk_num -= 1;
        }

        player_tile_offset_x = Chunk.size;
    } else if (player_tile_offset_y == 0 and player.entity.direction == .up) {
        if (player.entity.pos.y >= 0) {
            target_chunk_num -= 3;
        }

        player_tile_offset_y = Chunk.size;
    } else if (player_tile_offset_x == 0 and player.entity.direction == .right) {
        if (player.entity.pos.x < 0) {
            target_chunk_num += 1;
        }
    } else if (player_tile_offset_y == 0 and player.entity.direction == .down) {
        if (player.entity.pos.y < 0) {
            target_chunk_num += 3;
        }
    }

    switch (player.entity.direction) {
        .left => player_tile_offset_x -= 1,
        .right => player_tile_offset_x += 1,
        .up => player_tile_offset_y -= 1,
        .down => player_tile_offset_y += 1,
    }

    if (player_tile_offset_x == Chunk.size and player.entity.direction == .right) {
        target_chunk_num = 5;

        player_tile_offset_x = 0;
    } else if (player_tile_offset_y == Chunk.size and player.entity.direction == .down) {
        target_chunk_num = 7;

        player_tile_offset_y = 0;
    }

    if (player_tile_offset_x == 0) {
        if (player.entity.direction == .down or player.entity.direction == .up) {
            if (player.entity.pos.x < 0) {
                target_chunk_num += 1;
            }
        }
    }

    if (player_tile_offset_y == 0) {
        if (player.entity.direction == .left or player.entity.direction == .right) {
            if (player.entity.pos.y < 0) {
                target_chunk_num += 3;
            }
        }
    }

    const target_chunk = &engine.chunks[target_chunk_num];

    var target_tile = target_chunk.getTileAtOffset(
        .wall,
        player_tile_offset_x,
        player_tile_offset_y,
    );

    var floor_tile = target_chunk.getTileAtOffset(
        .floor,
        player_tile_offset_x,
        player_tile_offset_y,
    );

    player.standing_on = target_chunk.getTileAtOffset(
        .floor,
        player_tile_offset_x,
        player_tile_offset_y,
    );

    if (rl.isKeyPressed(.period) or rl.isGamepadButtonPressed(0, .right_face_left)) {
        target_tile.playSound();

        // Apply damage to tile, break olnce it hits 3
        switch (target_tile.damage) {
            3 => {
                const added = player.inventory.add(.{ .tile = target_tile.*.id }, 1);
                if (!added) {
                    std.debug.print("failed to add item ({s}) to inventory!\n", .{@tagName(target_tile.*.id)});
                }

                target_tile.* = .{
                    .id = .air,
                    .damage = 0,
                    .naturally_generated = false,
                    .grade = 0,
                    .direction = .down,
                };
            },

            else => {
                if (target_tile.id != .air) {
                    target_tile.damage +%= 1;
                }
            },
        }

        if (floor_tile.id == .grass and target_tile.id != .air) {
            floor_tile.id = .dirt;
        }
    }

    if (
        (rl.isKeyPressed(.slash) or rl.isGamepadButtonPressed(0, .right_face_down)) and
        @abs(player.entity.remaining_x) == 0 and
        @abs(player.entity.remaining_y) == 0
    ) {
        if (player.inventory.items[player.inventory.selected_slot]) |*slot| {
            if (slot.value == .tile) {
                const temp_tile = engine.Tile.init(.{ .id = slot.value.tile } );

                if (floor_tile.id == .water) {
                    floor_tile.* = temp_tile;
                    slot.*.count -= 1;
                    temp_tile.playSound();
                } else if (target_tile.id == .air) {
                    target_tile.* = temp_tile;
                    slot.*.count -= 1;
                    temp_tile.playSound();
                }

                if (slot.*.count == 0) {
                    player.inventory.items[player.inventory.selected_slot] = null;
                }
            }
        }
    }

    if (input_vec.x != 0 and player.entity.remaining_x == 0 and player.entity.remaining_y == 0 and (target_tile.id == .air and floor_tile.id != .water)) {
        player.entity.remaining_x = 1;

        if (player.entity.direction == .left) player.entity.remaining_x = -player.entity.remaining_x;
    }

    if (input_vec.y != 0 and player.entity.remaining_y == 0 and player.entity.remaining_x == 0 and (target_tile.id == .air and floor_tile.id != .water)) {
        player.entity.remaining_y = 1;

        if (player.entity.direction == .up) player.entity.remaining_y = -player.entity.remaining_y;
    }

    if (player.entity.direction == .right and player.entity.remaining_x > 0 or player.entity.direction == .left and player.entity.remaining_x < 0) {
        var x_speed = engine.tps * Entity.walk_speed * engine.delta;
        if (player.entity.direction == .left) x_speed = -x_speed;

        player.entity.remaining_x -= x_speed;
    }

    if (player.entity.direction == .right and player.entity.remaining_x < 0 or player.entity.direction == .left and player.entity.remaining_x > 0) {
        player.entity.x_speed = 0;

        if (player.entity.direction == .right and player.entity.remaining_x < 0) {
            player.entity.pos.x += 1;
        } else if (player.entity.direction == .left and player.entity.remaining_x > 0) {
            player.entity.pos.x -= 1;
        }

        player.entity.remaining_x = 0;
    }

    if (player.entity.direction == .down and player.entity.remaining_y > 0 or player.entity.direction == .up and player.entity.remaining_y < 0) {
        player.entity.y_speed = engine.tps * Entity.walk_speed * engine.delta;
        if (player.entity.direction == .up) player.entity.y_speed = -player.entity.y_speed;

        player.entity.remaining_y -= player.entity.y_speed;
    } 

    if (player.entity.direction == .down and player.entity.remaining_y < 0 or player.entity.direction == .up and player.entity.remaining_y > 0) {
        player.entity.y_speed = 0;

        if (player.entity.direction == .down and player.entity.remaining_y < 0) {
            player.entity.pos.y += 1;
        } else if (player.entity.direction == .up and player.entity.remaining_y > 0) {
            player.entity.pos.y -= 1;
        }

        player.entity.remaining_y = 0;
    }

    if (input_vec.x == 0 and input_vec.y == 0 and player.entity.remaining_x == 0 and player.entity.remaining_y == 0) {
        player.entity.frame_num = 0;
    }

    if (target_tile.id != .air and player.entity.remaining_x == 0 and player.entity.remaining_y == 0) {
        player.entity.frame_num = 0;
    }

    if (rl.isKeyPressed(.right)) {
        if (player.inventory.selected_slot == player.inventory.items.len - 1) {
            player.inventory.selected_slot = 0;
        } else {
            player.inventory.selected_slot += 1;
        }
    } else if (rl.isKeyPressed(.left)) {
        if (player.inventory.selected_slot == 0) {
            player.inventory.selected_slot = player.inventory.items.len - 1;
        } else {
            player.inventory.selected_slot -= 1;
        }
    }

    if (rl.isKeyPressed(.one)) player.inventory.selected_slot = 0;
    if (rl.isKeyPressed(.two)) player.inventory.selected_slot = 1;
    if (rl.isKeyPressed(.three)) player.inventory.selected_slot = 2;
    if (rl.isKeyPressed(.four)) player.inventory.selected_slot = 3;
    if (rl.isKeyPressed(.five)) player.inventory.selected_slot = 4;
    if (rl.isKeyPressed(.six)) player.inventory.selected_slot = 5;
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
            .pos = player.entity.pos,
            .direction = player.entity.direction,
            .inventory = player.inventory,
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
        player.entity.frame_sub += engine.tps * 0.4 * engine.delta;
    }

    if (player.entity.frame_sub >= 1) {
        player.entity.frame_sub -= 1;
        player.entity.frame_num +%= 1;

        if (player.entity.frame_num == 2 or player.entity.frame_num == 6) {
            if (player.standing_on) |tile| {
                engine.playSound(tile.sound());
            }
        }
    }
}

// Checks and unloads any engine.chunks not surrounding the player in a 3x3 area
// then loads new chunks into their pointers
// Not yet sure how robust this is
pub fn reloadChunks(player: *Player) void {
    var chunk_x: i32 = @intCast(@divTrunc(player.entity.pos.x, Chunk.size));
    var chunk_y: i32 = @intCast(@divTrunc(player.entity.pos.y, Chunk.size));

    if (player.entity.pos.x < 0) {
        chunk_x = chunk_x - 1;
    }

    if (player.entity.pos.y < 0) {
        chunk_y = chunk_y - 1;
    }

    for (&engine.chunks) |*chnk| {
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
    for (&engine.chunks) |*chunk| {
        for (&engine.chunks) |*swap_chunk| {
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
