const std = @import("std");
const perlin = @import("perlin");
const engine = @import("../../engine.zig");
const Chunk = @This();

x: i32,
y: i32,

level: i32 = 0x80,
tiles: [size * size * 2]engine.world.Tile,

version: u8,

const LoadError = error{
    BadMagic,
    InvalidFileSize,
    UnknownVersion,
};

pub const max_supported_version = 0;

/// Width / height of chunk measured in tiles
pub const size = 24;

pub fn save(self: *const Chunk, save_path: []const u8, mod_pack: []const u8) !void {
    const cwd = std.fs.cwd();

    var buf: [256]u8 = undefined;
    var path = try std.fmt.bufPrint(
        &buf,
        "{s}/chunks",
        .{save_path},
    );

    try cwd.makePath(path);

    path = try std.fmt.bufPrint(
        &buf,
        "{s}/chunks/{x}_{x}.{s}",
        .{
            save_path,
            @divTrunc(self.x, size),
            @divTrunc(self.y, size),
            mod_pack,
        },
    );

    const file = try std.fs.cwd().createFile(
        path,
        .{ .read = true },
    );

    var save_buf: [6 + size * size * 2 * 2]u8 = undefined;
    //@memset(&save_buf, 0);

    @memcpy(save_buf[0..5], "YABGc");

    //std.mem.copyForwards(u8, &save_buf, "YABGc");

    save_buf[5] = self.version;

    @memcpy(
        save_buf[6..],
        @as([size * size * 2 * 2]u8, @bitCast(self.tiles[0 .. size * size * 2].*))[0..],
    );

    _ = try file.writeAll(&save_buf);
}

pub const Layer = enum {
    floor,
    wall,
};

pub fn getTileAtOffset(self: *Chunk, layer: Layer, x: u16, y: u16) *engine.world.Tile {
    const offset: usize = if (layer == .wall) (Chunk.size * Chunk.size) else 0;

    return &self.tiles[@as(usize, x) + (@as(usize, y) * Chunk.size) + offset];
}

pub fn load(save_path: []const u8, mod_pack: []const u8, x: i32, y: i32) !Chunk {
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
        return Chunk.init(x, y);
    };

    var header_buf: [6]u8 = undefined;
    var byte_count = try file.read(&header_buf);

    // Ensure magic number is valid
    if (!std.mem.eql(u8, header_buf[0..5], "YABGc")) {
        return LoadError.BadMagic;
    }

    if (byte_count < 6) unreachable;

    var chunk = Chunk{
        .tiles = undefined,

        .x = x * size,
        .y = y * size,

        .version = header_buf[5],
    };

    if (chunk.version > max_supported_version) {
        std.debug.print("ver {d}\n", .{chunk.version});
        return LoadError.UnknownVersion;
    }

    var tile_buf: [size * size * 2 * 2]u8 = @bitCast(chunk.tiles);

    // Read tile data
    byte_count = try file.read(&tile_buf);

    // TODO: do this without copying
    std.mem.copyForwards(
        engine.world.Tile,
        chunk.tiles[0..],
        @as([size * size * 2]engine.world.Tile, @bitCast(tile_buf))[0..],
    );

    return chunk;
}

pub fn init(x: i32, y: i32) !Chunk {
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

    for (chunk.tiles[0 .. size * size * 2]) |*t| {
        t.* = engine.world.Tile{ .id = .air };
    }

    var idx: usize = 0;
    while (idx < size * size) : (idx += 1) {
        var t = &chunk.tiles[idx];

        t_x = chunk.x + @as(i32, @intCast(@mod(idx, size)));
        t_y = chunk.y + @as(i32, @intCast(@divTrunc(idx, size)));

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
