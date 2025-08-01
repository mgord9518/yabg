const std = @import("std");
const perlin = @import("perlin");
const engine = @import("../../engine.zig");

pub fn Chunk(comptime IdType: type) type {
    return struct {
        const Self = @This();
        pub const Tile = engine.world.Tile(IdType);

        valid: bool = true,

        x: i32,
        y: i32,

        level: i32 = 0x80,
        tiles: [size * size * 2]Tile,

        version: u8,


        const LoadError = error{
            BadMagic,
            InvalidFileSize,
            UnknownVersion,
        };

        const magic = "YABGc";
        pub const max_supported_version = 0;

        /// Width / height of chunk measured in tiles
        pub const size = engine.world.chunk_size;

        pub fn save(self: *const Self, allocator: std.mem.Allocator, save_path: []const u8, mod_pack: []const u8) !void {
            const cwd = std.fs.cwd();

            const chunk_save_path = try std.fmt.allocPrint(
                allocator,
                "{s}/chunks",
                .{save_path},
            );
            defer allocator.free(chunk_save_path);

            try cwd.makePath(chunk_save_path);

            var chunk_save_dir = try cwd.openDir(chunk_save_path, .{});
            defer chunk_save_dir.close();

            const chunk_file_name = try std.fmt.allocPrint(
                allocator,
                "{x}_{x}.{s}",
                .{
                    self.x,
                    self.y,
                    mod_pack,
                },
            );
            defer allocator.free(chunk_file_name);

            const file = try chunk_save_dir.createFile(
                chunk_file_name,
                .{ .read = true },
            );
            defer file.close();

            try file.writer().writeAll(magic);
            try file.writer().writeByte(self.version);
            try file.writer().writeAll(@ptrCast(&self.tiles));
        }

        pub const Layer = enum {
            floor,
            wall,
        };

        pub fn getTileAtOffset(self: *Self, layer: Layer, x: u16, y: u16) *Tile {
            const offset: usize = if (layer == .wall) (Self.size * Self.size) else 0;

            return &self.tiles[@as(usize, x) + (@as(usize, y) * Self.size) + offset];
        }

        pub fn load(save_path: []const u8, mod_pack: []const u8, x: i32, y: i32) !Self {
            var buf: [256]u8 = undefined;
            const path = try std.fmt.bufPrint(
                &buf,
                "{s}/chunks/{x}_{x}.{s}",
                .{
                    save_path,
                    x,
                    y,
                    mod_pack,
                },
            );

            const cwd = std.fs.cwd();
            var file = cwd.openFile(path, .{}) catch {
                return Self.init(x, y);
            };
            defer file.close();

            // Ensure magic number is valid
            if (!std.mem.eql(
                u8,
                &(try file.reader().readBytesNoEof(5)),
                magic,
            )) {
                return LoadError.BadMagic;
            }

            const version = try file.reader().readByte();

            var chunk = Self{
                .tiles = undefined,

                .x = x,
                .y = y,

                .version = version,
            };

            if (chunk.version > max_supported_version) {
                return LoadError.UnknownVersion;
            }

            try file.reader().readNoEof(@ptrCast(&chunk.tiles));

            return chunk;
        }

        pub fn init(x: i32, y: i32) !Self {
            // Chunk version is an 8 bit int at offset 5
            const version = 0;

            // Ensure version number is valid
            if (version > max_supported_version) unreachable;

            var chunk = Self{
                .tiles = undefined,

                .x = x,
                .y = y,

                .version = version,
            };

            var t_x: i32 = undefined;
            var t_y: i32 = undefined;

            for (chunk.tiles[0 .. size * size * 2]) |*t| {
                t.* = Tile{ .id = .air };
            }

            var idx: usize = 0;
            while (idx < size * size) : (idx += 1) {
                var t = &chunk.tiles[idx];

                t_x = (chunk.x * size) + @as(i32, @intCast(@mod(idx, size)));
                t_y = (chunk.y * size) + @as(i32, @intCast(@divTrunc(idx, size)));

                // TODO: Allow the world directory to control world gen
                const s = 1.5;

                var val = perlin.noise(f64, perlin.permutation, .{
                    .x = @as(f32, @floatFromInt(t_x)) * 0.02 * s,
                    .y = @as(f32, @floatFromInt(t_y)) * 0.02 * s,
                });

                val += perlin.noise(f64, perlin.permutation, .{
                    .x = @as(f32, @floatFromInt(t_x)) * 0.05 * s,
                    .y = @as(f32, @floatFromInt(t_y)) * 0.05 * s,
                });

                val += perlin.noise(f64, perlin.permutation, .{
                    .x = @as(f32, @floatFromInt(t_x)) * 0.10 * s,
                    .y = @as(f32, @floatFromInt(t_y)) * 0.10 * s,
                    //}) / 2;
                });

                // Inside of mountains
                if (val > 0.60) {
                    t.id = .stone;
                    chunk.tiles[idx + size * size].id = .stone;
                } else if (val > 0.3) {
                    t.id = .dirt;
                    chunk.tiles[idx + size * size].id = .grass;
                } else if (val > -0.6) {
                    t.id = .grass;
                } else if (val > -0.90) {
                    t.id = .sand;
                } else {
                    t.id = .water;
                }
            }

            return chunk;
        }
    };
}
