const std = @import("std");
const engine = @import("../engine.zig");

pub fn Item(comptime IdType: type, comptime ItemIdType: type) type {
    return union(enum) {
        const Self = @This();
        tile: IdType,
        item: ItemIdType,

        pub fn canStackWith(self: Self, other: Self) bool {
            const tag = std.meta.activeTag(self);
            if (tag != std.meta.activeTag(other)) {
                return false;
            }

            return switch (self) {
                .tile => self.tile == other.tile,
                .item => self.item == other.item,
            };
        }
    };
}
