const rl = @import("raylib");

pub const Tile = struct {
    pub const size = 12;

    hardness: u8 = 0,
    texture: *rl.Texture = undefined,
};
