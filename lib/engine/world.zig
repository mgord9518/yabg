pub const chunk_size = 24;
pub const tile_size = 12;

pub const ChunkCoordinate = struct {
    x: i32,
    y: i32,
};

pub const Chunk = @import("world/chunk.zig").Chunk;
pub const Tile = @import("world/tile.zig").Tile;
pub const load = @import("world/load.zig");
