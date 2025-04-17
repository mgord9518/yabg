const rl = @import("raylib");

const Direction = @import("enums.zig").Direction;
const Animation = @import("enums.zig").Animation;

const Entity = @This();

// The max speed at which the player is allowed to walk
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
