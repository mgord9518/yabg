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
