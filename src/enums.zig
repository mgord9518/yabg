pub const Direction = enum(u2) {
    down,
    right,
    up,
    left,
};

pub const Animation = enum {
    idle,
    walk_right,
    walk_left,
    walk_down,
    walk_up,
};
