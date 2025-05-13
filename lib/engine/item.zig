const std = @import("std");
const engine = @import("../engine.zig");

pub const Item = union(enum) {
    tile: engine.Tile.Id,

    pub fn canStackWith(self: Item, other: Item) bool {
        const tag = std.meta.activeTag(self);
        if (tag != std.meta.activeTag(other)) {
            return false;
        }

        return switch (self) {
            .tile => self.tile == other.tile,
        };
        
    }
};
