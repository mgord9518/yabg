pub const ui = @import("ui.zig");

const std = @import("std");
const rl = @import("raylib");

const Font = struct {
    atlas: rl.Texture,
    glyph_offsets: std.AutoHashMap(u21, usize),
};

const Vec = struct {
    x: u16,
    y: u16,
};

const Size = struct {
    x: u16,
    y: u16,
};
