const std = @import("std");
const fmt = std.fmt;
const fs = std.fs;
const perlin = @import("perlin");


pub const Chunk = struct {
    x: i32,
    y: i32,
    level: i32 = 0x80,
    tiles: [size*size*2]u8 = undefined,
    pub const size = 24;


    pub fn init(save_name: []const u8, mod_pack: []const u8, x: i32, y: i32) !Chunk {
        var buf: [144]u8 = undefined;
        const string = try fmt.bufPrint(
            &buf,
            "saves/{s}/{d}_{d}.{s}",
            .{
                save_name,
                x,
                y,
                mod_pack,
            },
        );

        var chunk = Chunk{
            .x = x * size,
            .y = y * size,
        };

        // Generate chunk if unable to find file
        var f = fs.cwd().openFile(string, .{}) catch return genChunk(save_name, mod_pack, x, y);
        defer f.close();

        _ = try f.read(chunk.tiles[0..]);
        return chunk;
    }

    fn genChunk(save_name: []const u8, mod_pack: []const u8, x: i32, y: i32) !Chunk {
        var buf: [144]u8 = undefined;
        const path = try fmt.bufPrint(
            &buf,
            "saves/{s}/{d}_{d}.{s}",
            .{
                save_name,
                x,
                y,
                mod_pack,
            },
        );

//        print("GENERATING CHUNK AT {x}, {x}\n", .{x, y});
//        chunks_generated += 1;

        // TODO: Save bytes to disk
        var chunk = Chunk{ .x = x * size, .y = y * size };
        var f = fs.cwd().createFile(path, .{ .read = true }) catch unreachable;

        var t_x: i32 = undefined;
        var t_y: i32 = undefined;
        // Use Perlin noise to generate the world
        for (chunk.tiles) |*tile, idx| {
            if (idx >= size*size) {
                break;
            }

            t_x = chunk.x + @intCast(i32,      @mod(idx, size));
            t_y = chunk.y + @intCast(i32, @divTrunc(idx, size));

            // TODO: Fix formatting on this
            var val = @floatToInt(u8, (1+perlin.noise3D(f64, @intToFloat(f32, t_x-100)*0.05, @intToFloat(f32, t_y)*0.05, 0))*127.5/4);
            val += @floatToInt(u8, (1+perlin.noise3D(f64, @intToFloat(f32, t_x-100)*0.05, @intToFloat(f32, t_y)*0.05, 0))*127.5/4);
            val += @floatToInt(u8, (1+perlin.noise3D(f64, @intToFloat(f32, t_x-100)*0.05, @intToFloat(f32, t_y)*0.05, 0))*127.5/4);
            val += @floatToInt(u8, (1+perlin.noise3D(f64, @intToFloat(f32, t_x-100)*0.2, @intToFloat(f32, t_y)*0.2, 0))*127.5/4);

            if (val > 170) {
                tile.* = 0x01;
                chunk.tiles[idx + size*size] = 0x01;
            } else if (val > 72) {
                tile.* = 0x01;
                chunk.tiles[idx + size*size] = 0x00;
            } else if (val > 48) {
                tile.* = 0x03;
                chunk.tiles[idx + size*size] = 0x00;
            } else {
                tile.* = 0x00;
                chunk.tiles[idx + size*size] = 0x00;
            }
        }

        _ = try f.write(&chunk.tiles);

        return chunk;
    }

};
