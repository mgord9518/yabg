const std = @import("std");

const known_folders = @import("known-folders");

const engine = @import("../engine.zig");
const Entity = @import("Entity.zig");

pub fn Player(comptime IdType: type) type {
    return struct{
        const Self = @This();
        const Chunk = engine.world.Chunk(IdType);

        entity: Entity,
        inventory: engine.Inventory(IdType),

        standing_on: ?*const engine.world.Tile(IdType) = null,

        save_path: []const u8,

        const PlayerJson = struct {
            pos: engine.Coordinate,

            inventory: engine.Inventory(IdType),

            direction: Entity.Direction,
        };

        pub fn init(allocator: std.mem.Allocator, save_path: []const u8) !Self {
            const cwd = std.fs.cwd();
            var buf: [std.fs.max_path_bytes]u8 = undefined;

            var player = Self{
                .save_path = save_path,
                .entity = .{
                    .direction = .down,
                    .animation_texture = undefined,
                },
                .inventory = engine.Inventory(IdType){},
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

        // ms since last changed direction
        var last_changed_direction: isize = 0;

        // 1/8th of a second
        const direction_change_timeout = 125;

        // Updates player state based on input
        pub fn updateState(player: *Self) !void {
            const previous_direction = player.entity.direction;

            if (player.entity.remaining_x == 0 and player.entity.remaining_y == 0) {
                if (engine.isButtonDown(.right)) {
                    player.entity.direction = .right;
                } else if (engine.isButtonDown(.left)) {
                    player.entity.direction = .left;
                } else if (engine.isButtonDown(.down)) {
                    player.entity.direction = .down;
                } else if (engine.isButtonDown(.up)) {
                    player.entity.direction = .up;
                }
            }

            if (previous_direction != player.entity.direction) {
                last_changed_direction = std.time.milliTimestamp();
            }

            if (std.time.milliTimestamp() - last_changed_direction < direction_change_timeout) {
                return;
            }

            const target = player.targetTile();

            var target_tile = target.chunk.getTileAtOffset(
                .wall,
                target.tile_x,
                target.tile_y,
            );

            var floor_tile = target.chunk.getTileAtOffset(
                .floor,
                target.tile_x,
                target.tile_y,
            );

            player.standing_on = target.chunk.getTileAtOffset(
                .floor,
                target.tile_x,
                target.tile_y,
            );

            if (engine.isButtonPressed(.primary)) {
                target_tile.playSound();

                target_tile.callback(player);

                if (floor_tile.id == .grass and target_tile.id != .air) {
                    floor_tile.id = .dirt;
                }
            }

            if (engine.isButtonPressed(.secondary) and
                @abs(player.entity.remaining_x) == 0 and
                @abs(player.entity.remaining_y) == 0)
            {
                if (player.inventory.items[player.inventory.selected_slot]) |*slot| {
                    if (slot.value == .tile) {
                        const temp_tile = engine.world.Tile(IdType){ .id = slot.value.tile };

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

            if ((player.entity.remaining_x + player.entity.remaining_y == 0) and (target_tile.id == .air and floor_tile.id != .water)) {
                if (engine.isButtonDown(.left)) {
                    player.entity.remaining_x = -1;
                } else if (engine.isButtonDown(.right)) {
                    player.entity.remaining_x = 1;
                } else if (engine.isButtonDown(.up)) {
                    player.entity.remaining_y = -1;
                } else if (engine.isButtonDown(.down)) {
                    player.entity.remaining_y = 1;
                }

                if (!engine.isButtonDown(.right) and !engine.isButtonDown(.left) and !engine.isButtonDown(.up) and !engine.isButtonDown(.down)) {
                    player.entity.frame_num = 0;
                }
            }

            if (target_tile.id != .air and player.entity.remaining_x == 0 and player.entity.remaining_y == 0) {
                player.entity.frame_num = 0;
            }

            if (player.entity.direction == .right and player.entity.remaining_x > 0 or player.entity.direction == .left and player.entity.remaining_x < 0) {
                var x_speed = engine.tick.ticks_per_second * Entity.walk_speed * engine.delta;
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
                player.entity.y_speed = engine.tick.ticks_per_second * Entity.walk_speed * engine.delta;
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

            if (engine.isButtonPressed(.inventory_next)) {
                if (player.inventory.selected_slot == player.inventory.items.len - 1) {
                    player.inventory.selected_slot = 0;
                } else {
                    player.inventory.selected_slot += 1;
                }
            } else if (engine.isButtonPressed(.inventory_previous)) {
                if (player.inventory.selected_slot == 0) {
                    player.inventory.selected_slot = player.inventory.items.len - 1;
                } else {
                    player.inventory.selected_slot -= 1;
                }
            }

            if (engine.isButtonPressed(.inventory_0)) player.inventory.selected_slot = 0;
            if (engine.isButtonPressed(.inventory_1)) player.inventory.selected_slot = 1;
            if (engine.isButtonPressed(.inventory_2)) player.inventory.selected_slot = 2;
            if (engine.isButtonPressed(.inventory_3)) player.inventory.selected_slot = 3;
            if (engine.isButtonPressed(.inventory_4)) player.inventory.selected_slot = 4;
            if (engine.isButtonPressed(.inventory_5)) player.inventory.selected_slot = 5;
        }

        pub const TargetTile = struct {
            tile_x: u15,
            tile_y: u15,
            chunk: *Chunk,
        };

        pub fn targetTile(player: *Self) TargetTile {
            var chunk_x: i32 = @intCast(@divTrunc(player.entity.pos.x, engine.world.chunk_size));
            var chunk_y: i32 = @intCast(@divTrunc(player.entity.pos.y, engine.world.chunk_size));

            if (player.entity.pos.x < 0) {
                chunk_x -= 1;
            }

            if (player.entity.pos.y < 0) {
                chunk_y -= 1;
            }

            const start_x = chunk_x;
            const start_y = chunk_y;

            // Collision detection
            var player_tile_offset_x: u15 = @intCast(@mod(player.entity.pos.x, engine.world.chunk_size));
            var player_tile_offset_y: u15 = @intCast(@mod(player.entity.pos.y, engine.world.chunk_size));

            // Find chunk player is looking at
            if (player_tile_offset_x == 0 and player.entity.direction == .left) {
                if (player.entity.pos.x >= 0) {
                    chunk_x -= 1;
                }

                player_tile_offset_x = engine.world.chunk_size;
            } else if (player_tile_offset_y == 0 and player.entity.direction == .up) {
                if (player.entity.pos.y >= 0) {
                    chunk_y -= 1;
                }

                player_tile_offset_y = engine.world.chunk_size;
            } else if (player_tile_offset_x == 0 and player.entity.direction == .right) {
                if (player.entity.pos.x < 0) {
                    chunk_x += 1;
                }
            } else if (player_tile_offset_y == 0 and player.entity.direction == .down) {
                if (player.entity.pos.y < 0) {
                    chunk_y += 1;
                }
            }

            switch (player.entity.direction) {
                .left => player_tile_offset_x -= 1,
                .right => player_tile_offset_x += 1,
                .up => player_tile_offset_y -= 1,
                .down => player_tile_offset_y += 1,
            }

            if (player_tile_offset_x == engine.world.chunk_size and player.entity.direction == .right) {
                //target_chunk_num = 5;
                chunk_x = start_x + 1;
                chunk_y = start_y;

                player_tile_offset_x = 0;
            } else if (player_tile_offset_y == engine.world.chunk_size and player.entity.direction == .down) {
                chunk_x = start_x;
                chunk_y = start_y + 1;

                player_tile_offset_y = 0;
            }

            if (player_tile_offset_x == 0) {
                if (player.entity.direction == .down or player.entity.direction == .up) {
                    if (player.entity.pos.x < 0) {
                        //target_chunk_num += 1;
                        chunk_x += 1;
                    }
                }
            }

            if (player_tile_offset_y == 0) {
                if (player.entity.direction == .left or player.entity.direction == .right) {
                    if (player.entity.pos.y < 0) {
                        //target_chunk_num += 3;
                        chunk_y += 1;
                    }
                }
            }

            return .{
                .chunk = engine.engine(IdType).chunks.getPtr(.{ .x = chunk_x, .y = chunk_y }).?,
                .tile_x = player_tile_offset_x,
                .tile_y = player_tile_offset_y,
            };
        }

        pub fn save(player: *Self) !void {
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

        pub fn updateAnimation(self: *Self) void {
            self.entity.animation = switch (self.entity.direction) {
                .right => .walk_right,
                .left => .walk_left,
                .down => .walk_down,
                .up => .walk_up,
            };
        }

        pub fn updatePlayerFrames(
            player: *Self,
        ) void {
            if (player.entity.remaining_x != 0 or player.entity.remaining_y != 0) {
                player.entity.frame_sub += engine.tick.ticks_per_second * 0.4 * engine.delta;
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
        pub fn reloadChunks(player: *Self) !void {
            var chunk_x: i32 = @intCast(@divTrunc(player.entity.pos.x, engine.world.chunk_size));
            var chunk_y: i32 = @intCast(@divTrunc(player.entity.pos.y, engine.world.chunk_size));

            if (player.entity.pos.x < 0) {
                chunk_x -= 1;
            }

            if (player.entity.pos.y < 0) {
                chunk_y -= 1;
            }

            engine.chunk_mutex.lock();

            try engine.engine(IdType).worldNew.loadChunks(
                player.save_path,
                .{ .x = chunk_x, .y = chunk_y }
            );

            var y = chunk_y - 1;
            var idx: usize = 0;

            while (y <= chunk_y + 1) : (y += 1) {
                var x = chunk_x - 1;

                while (x <= chunk_x + 1) : (x += 1) {
                    engine.chunks(IdType)[idx] = engine.engine(IdType).chunks.getPtr(.{ .x = x, .y = y }).?;

                    idx += 1;
                }
            }

            engine.chunk_mutex.unlock();
        }
    };
}
