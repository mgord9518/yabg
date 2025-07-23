const std = @import("std");
const engine = @import("../engine.zig");

pub fn Item(comptime IdType: type) type {
    return union(enum) {
        const Self = @This();
        tile: IdType,

        pub fn canStackWith(self: Self, other: Self) bool {
            const tag = std.meta.activeTag(self);
            if (tag != std.meta.activeTag(other)) {
                return false;
            }

            return switch (self) {
                .tile => self.tile == other.tile,
            };
        }
    };
}
