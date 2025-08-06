const engine = @import("../engine.zig");

pub var hotbar_item: engine.ImageNew = undefined;
pub var active_hotbar_item: engine.ImageNew = undefined;
pub var cursor: engine.ImageNew = undefined;

pub var tiles: [256]engine.Texture = undefined;
pub var tile_images: [256]engine.ImageNew = undefined;
