const std = @import("std");
const fmt = std.fmt;
const print = std.debug.print;
const fs = std.fs;
const perlin = @import("perlin");
const builtin = @import("builtin");
const Tile = @import("Tile.zig").Tile;

// TODO: save chunks on unload
pub const Chunk = struct {
    x: i32,
    y: i32,

    level: i32 = 0x80,
    tiles: [size * size * 2]Tile,

    version: u8,

    /// Width / height of chunk measured in tiles
    pub const size = 24;

    pub fn save(self: *const Chunk, save_path: []const u8, mod_pack: []const u8) !void {
        var buf: [256]u8 = undefined;
        const path = try fmt.bufPrint(
            &buf,
            "{s}/{x}_{x}.{s}",
            .{
                save_path,
                self.x,
                self.y,
                mod_pack,
            },
        );

        const file = try std.fs.cwd().createFile(
            path,
            .{ .read = true },
        );

        var save_buf: [6 + size * size * 2]u8 = undefined;
        std.mem.copy(save_buf, "YABGc");
        save_buf[5] = self.version;
        std.mem.copy(save_buf[6..], @bitCast([size * size * 2 * 2]u8, self.tiles));

        _ = try file.write(&save_buf);
    }

    pub fn load(save_path: []const u8, mod_pack: []const u8, x: i32, y: i32) !Chunk {
        var buf: [256]u8 = undefined;
        const path = try fmt.bufPrint(
            &buf,
            "{s}/{x}_{x}.{s}",
            .{
                save_path,
                x,
                y,
                mod_pack,
            },
        );

        const cwd = std.fs.cwd();
        var file = cwd.openFile(path, .{}) catch {
            return Chunk.init(x, y);
        };

        var header_buf: [6]u8 = undefined;
        var byte_count = try file.read(&header_buf);

        if (byte_count < 6) unreachable;

        var chunk = Chunk{
            .tiles = undefined,

            .x = x * size,
            .y = y * size,

            .version = header_buf[5],
        };

        var tile_buf = @bitCast([size * size * 2 * 2]u8, chunk.tiles);

        // Read tile data
        byte_count = try file.read(&tile_buf);
        //std.mem.copy(@bitCast([size * size * 2 * 2]u8, chunk.tiles), );
        //
        return chunk;
    }

    pub fn init(x: i32, y: i32) !Chunk {
        // Ensure magic number is valid
        //        if (!std.mem.eql(u8, data[0..5], "YABGc")) {
        //            print(data[0..5]);
        //            unreachable;
        //        }

        const max_supported_version = 0;

        // Chunk version is an 8 bit int at offset 5
        const version = 0;

        // Ensure version number is valid
        if (version > max_supported_version) unreachable;

        var chunk = Chunk{
            .tiles = undefined,

            .x = x * size,
            .y = y * size,

            .version = version,
        };

        var t_x: i32 = undefined;
        var t_y: i32 = undefined;

        // Set the upper layer of the chunk to byte 0x00, which is air tiles.
        // As an overwhelming majority of the upper layer will be air on generation,
        // this keeps from needing to iterate through all those bytes
        //        @memset(@ptrCast([*]u8, chunk.tiles[size * size..]), 0, size * size * 2);

        @memset(@ptrCast([*]u8, chunk.tiles[size * size ..])[0 .. size * size * 2], 0);

        for (&chunk.tiles, 0..) |*tile, idx| {
            if (idx >= size * size) {
                break;
            }

            t_x = chunk.x + @intCast(i32, @mod(idx, size));
            t_y = chunk.y + @intCast(i32, @divTrunc(idx, size));

            // TODO: Allow the world directory to control world gen
            const s = 1.5;
            var val = perlin.noise2D(f64, @intToFloat(f32, t_x) * 0.02 * s, @intToFloat(f32, t_y) * 0.02 * s);
            val += perlin.noise2D(f64, @intToFloat(f32, t_x) * 0.05 * s, @intToFloat(f32, t_y) * 0.05 * s);
            val += perlin.noise2D(f64, @intToFloat(f32, t_x) * 0.10 * s, @intToFloat(f32, t_y) * 0.10 * s) / 2;

            //var val = perlin.noise2D(f64, @intToFloat(f32, t_x ) * 0.03, @intToFloat(f32, t_y) * 0.03);
            //val += perlin.noise2D(f64, @intToFloat(f32, t_x ) * 0.25, @intToFloat(f32, t_y) * 0.25);
            //val += perlin.noise2D(f64, @intToFloat(f32, t_x ) * 0.060, @intToFloat(f32, t_y) * 0.060);

            // Inside of mountains
            if (val > 0.60) {
                tile.id = .stone;
                chunk.tiles[idx + size * size].id = .stone;
            } else if (val > 0.3) {
                tile.id = .dirt;
                chunk.tiles[idx + size * size].id = .grass;
            } else if (val > -0.6) {
                tile.id = .grass;
                // chunk.tiles[idx + size * size].id = .air;
            } else if (val > -0.90) {
                tile.id = .sand;
                //   chunk.tiles[idx + size * size].id = .air;
            } else {
                tile.id = .water;
                //  chunk.tiles[idx + size * size].id = .air;
            }
        }

        return chunk;
    }
};
