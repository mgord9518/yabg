const rl = @import("raylib");
const enums = @import("enums.zig");
const Direction = enums.Direction;
const Game = @import("Game.zig").Game;

pub const Tile = packed struct {
    pub const size = 12;

    // 8 bits
    id: Id,

    // If the tile was generated by the game through world generation, this
    // will be true, if placed by a player, it will be false
    naturally_generated: bool,

    // The `grade` of a material. This can mean very different things dependin
    // on the tile in question. If a grass tile, this could mean how tall the
    // grass is and what seeds it contains. If an ore, it could dictate how
    // much metal you'll get from it
    // (4 different possibilities)
    grade: u2,

    // The damage level of the tile. This can be caused by player mining,
    // explosions, etc.
    // (8 different possibilities)
    damage: u3,

    // The direction the tile is facing
    // (4 different possibilities)
    direction: Direction,

    pub const Options = struct {
        id: Id,
        naturally_generated: bool = false,
        grade: u2 = 0,
        damage: u3 = 0,
        direction: Direction = .down,
    };

    pub fn init(opts: Options) Tile {
        return Tile{
            .id = opts.id,
            .naturally_generated = opts.naturally_generated,
            .grade = opts.grade,
            .damage = opts.damage,
            .direction = opts.direction,
        };
    }

    pub fn texture(self: *const Tile) rl.Texture {
        return Game.tileTextures[@enumToInt(self.id)];
    }

    pub fn setTexture(id: Id, tex: rl.Texture) void {
        Game.tileTextures[@enumToInt(id)] = tex;
    }

    pub fn sound(self: *const Tile) rl.Sound {
        return Game.tileSounds[@enumToInt(self.id)];
    }

    pub fn setSound(id: Id, snd: rl.Sound) void {
        Game.tileSounds[@enumToInt(id)] = snd;
    }

    /// Categories should denote the basic qualities of a specific tile.
    /// While different submaterials (eg: grass and sand or cobblestone and brick)
    /// may have different hardnesses and sound, they're still collected with the
    /// same type of tool
    pub const Id = enum(u8) {
        air = 0,

        // Various kinds of soil, sand, gravel, etc.
        dirt = 8,
        grass,
        sand,

        // Logs, planks, bamboo
        wood = 16,

        // Cobblestone, smooth stone, bricks, ore
        stone = 32,

        metal = 48,

        // Computers, wires, machines
        electronic = 64,

        water = 80,

        misc = 240,

        // Tile dedicated to the `placeholder` texture
        placeholder = 255,
    };
};
