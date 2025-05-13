const rl = @import("raylib");

const Entity = @This();

pub const Direction = enum(u2) {
    down,
    left,
    up,
    right,
};

pub const Animation = enum {
    idle,
    walk_down,
    walk_left,
    walk_up,
    walk_right,
};

// Texels per tick
pub var walk_speed: f32 = 2;

x: i32 = 0,
y: i32 = 0,

remaining_x: f32 = 0,
remaining_y: f32 = 0,

// Current speeds
x_speed: f32 = 0,
y_speed: f32 = 0,

animation_texture: [5]rl.Texture,

frame_num: u3 = 0,
frame_sub: f32 = 0,

animation: Animation = .idle,
direction: Direction,
