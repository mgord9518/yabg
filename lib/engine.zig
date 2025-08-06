const std = @import("std");
const builtin = @import("builtin");

pub const backend = switch (builtin.cpu.arch) {
    .wasm32 => @import("engine/backends/wasm.zig"),
//    .x86_64 => @import("engine/backends/glfw.zig"),
    else => @import("engine/backends/raylib.zig"),
};
const psf = @import("engine/psf.zig");

pub fn engine(TileIdType: type, ItemIdType: type) type {
    return struct {
        pub const Player = @import("engine/Player.zig").Player(TileIdType, ItemIdType);

        pub var chunk_mutex = std.Thread.Mutex{};
        pub var chunks: std.AutoHashMap(world.ChunkCoordinate, world.Chunk) = undefined;

        pub const Item = @import("engine/item.zig").Item(TileIdType, ItemIdType);
        pub const Inventory = @import("engine/inventory.zig").Inventory(TileIdType, ItemIdType);

        pub const world = struct {
            pub const chunk_size = 24;
            pub const tile_size = 12;

            pub const ChunkCoordinate = struct {
                x: i32,
                y: i32,

                pub fn fromCoordinate(coordinate: Coordinate) ChunkCoordinate {
                    var chunk_x: i32 = @intCast(@divTrunc(coordinate.x, chunk_size));
                    var chunk_y: i32 = @intCast(@divTrunc(coordinate.y, chunk_size));

                    if (coordinate.x < 0) {
                        chunk_x -= 1;
                    }

                    if (coordinate.y < 0) {
                        chunk_y -= 1;
                    }

                    return .{
                        .x = chunk_x,
                        .y = chunk_y
                    };
                }
            };

            pub const Chunk = @import("engine/world/chunk.zig").Chunk(TileIdType, ItemIdType);
            pub const Tile = @import("engine/world/tile.zig").Tile(TileIdType, ItemIdType);

            // Load in all chunks that should be loaded (3x3) around a certain
            // origin
            pub fn loadChunks(save_path: []const u8, origin: ChunkCoordinate) !void {
                var it = ChunkIterator{ .origin = origin };

                chunk_mutex.lock();

                while (it.next()) |chunk_coordinate| {
                    const result = try engine(TileIdType, ItemIdType).chunks.getOrPut(chunk_coordinate);

                    if (!result.found_existing) {
                        result.value_ptr.* = try Chunk.load(
                            save_path,
                            "vanilla0",
                            chunk_coordinate.x,
                            chunk_coordinate.y,
                        );

                        std.debug.print("{}::{} loaded chunk {d}, {d}\n", .{
                            ColorName.green,
                            ColorName.default,
                            chunk_coordinate.x,
                            chunk_coordinate.y,
                        });
                    }
                }

                chunk_mutex.unlock();
            }

            pub const ChunkIterator = struct {
                x: i3 = -1,
                y: i3 = -1,

                origin: ChunkCoordinate,

                pub fn next(self: *ChunkIterator) ?ChunkCoordinate {
                    if (self.x > 1) {
                        self.x = -1;
                        self.y += 1;
                    }

                    if (self.y > 1) {
                        return null;
                    }

                    defer self.x += 1;

                    return .{
                        .x = self.origin.x + self.x,
                        .y = self.origin.y + self.y
                    };
                }
            };
        };
    };
}

pub const textures = @import("engine/textures.zig");
pub const ui = @import("engine/ui.zig");
//pub const Player = @import("engine/Player.zig").Player;
pub const Entity = @import("engine/Entity.zig");
pub const Inventory = @import("engine/inventory.zig").Inventory;
pub const tick = @import("engine/tick.zig");

pub const init = @import("engine/init.zig").init;

pub const Button = enum {
    left,
    right,
    up,
    down,
    debug,
    primary,
    secondary,
    inventory_next,
    inventory_previous,
    inventory_0,
    inventory_1,
    inventory_2,
    inventory_3,
    inventory_4,
    inventory_5,
};

const FontOld = struct {
    atlas: Texture,
    glyph_offsets: std.AutoHashMap(u21, usize),
};

pub const Font = struct {
    glyphs: std.AutoHashMap(u21, ImageNew),
};

pub const Coordinate = struct {
    x: i64,
    y: i64,
};

pub var screen_width: u15 = 160;
pub var screen_height: u15 = 144;
pub var scale: u15 = 4;
pub const id = "io.github.mgord9518.yabg";

pub const font_data = @embedFile("engine/fonts/5x8.psfu");
pub var font: FontOld = undefined;

pub var entities: std.SegmentedList(Entity, 0) = undefined;

pub const version = std.SemanticVersion{
    .pre = "alpha",

    .major = 0,
    .minor = 0,
    .patch = 67,
};

pub var rand: std.Random.DefaultPrng = undefined;

// The amount of nanoseconds the last tick took
pub var tick_time: u32 = 0;
pub var delta: f32 = 0;

pub const ImageOld = backend.Image;

// Opaque types specific to the backend
pub const Texture = DummyType("Texture");
pub const Sound = backend.Sound;

fn DummyType(comptime maybe_type: []const u8) type {
    if (@hasDecl(backend, maybe_type)) {
        return @field(backend, maybe_type);
    } else {
        return u0;
    }
}

pub const Rectangle = struct {
    x: i32,
    y: i32,
    w: u31,
    h: u31,
};

pub fn run(
    comptime onEveryTickFn: fn () anyerror!void,
) !void {
    _ = try std.Thread.spawn(.{}, tick.tickMainThread, .{onEveryTickFn});

    backend.run();
}

pub const ImageNew = struct {
    data: []const u2,
    palette: *const [4]Color,
    w: u8,
    h: u8,

    // Backend-dependent, field may be empty
    maybe_texture: ?Texture = null,

    pub fn toTexture(image: ImageNew) !Texture {
        return try backend.textureFromImage(std.heap.page_allocator, image);
    }

    pub fn draw(image: ImageNew, pos: Coordinate) void {
        if (@hasDecl(backend, "textureFromImage") and image.maybe_texture == null) {
            unreachable;
        }

        backend.drawImage(image, pos);
    }

    pub fn drawMutable(image: *ImageNew, pos: Coordinate) void {
        if (@hasDecl(backend, "textureFromImage") and image.maybe_texture == null) {
            @branchHint(.unlikely);

            // TODO
            image.maybe_texture = backend.textureFromImage(std.heap.page_allocator, image.*) catch unreachable;
        }

        backend.drawImage(image.*, pos);
    }
};

pub const Color = packed struct(u16) {
    r: u4,
    g: u4,
    b: u4,
    _12: u3 = 0,
    a: u1 = 1,
};

pub var tileSounds: [256]Sound = undefined;


pub const getFps = backend.getFps;
pub const shouldContinueRunning = backend.shouldContinueRunning;
pub const loadTextureEmbedded = backend.loadTextureEmbedded;
pub const loadSoundEmbedded = backend.loadSoundEmbedded;
pub const beginDrawing = backend.beginDrawing;
pub const endDrawing = backend.endDrawing;
pub const deltaTime = backend.deltaTime;
pub const screenWidth = backend.screenWidth;
pub const screenHeight = backend.screenHeight;
pub const loadTextureFromImage = backend.loadTextureFromImage;
pub const isButtonPressed = backend.isButtonPressed;
pub const isButtonDown = backend.isButtonDown;
// TODO: remove drawTexture
pub const drawTexture = backend.drawTexture;
pub const drawImage = backend.drawImage;
pub const drawTextureRect = backend.drawTextureRect;
pub const drawRect = backend.drawRect;
pub const closeWindow = backend.closeWindow;
pub const mousePosition = backend.mousePosition;

pub fn playSound(sound: Sound) void {
    const pitch_offset = rand.random().float(f32) / 4;

    backend.playSound(
        sound,
        pitch_offset + 0.875,
    );
}

pub const ColorName = enum(u8) {
    reset = 0,
    default = 39,

    black = 30,
    red = 31,
    green = 32,
    yellow = 33,
    blue = 34,
    magenta = 35,
    cyan = 36,
    white = 37,

    bright_black = 90,
    bright_red = 91,
    bright_green = 92,
    bright_yellow = 93,
    bright_blue = 94,
    bright_magenta = 95,
    bright_cyan = 96,
    bright_white = 97,

    pub fn format(
        self: ColorName,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        out_stream: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        return out_stream.print(
            "\x1b[;{d}m",
            .{@intFromEnum(self)},
        );
    }
};

pub fn debug(level: u2, str: []const u8) void {
    switch (level) {
        0 => {},
        3 => {
            std.debug.print("{}::{} {s}{}\n", .{ ColorName.cyan, ColorName.default, str, ColorName.default });
        },
        2 => {
            std.debug.print("{}::{} {s}{}\n", .{ ColorName.yellow, ColorName.default, str, ColorName.default });
        },
        1 => {
            std.debug.print("{}::{} {s}{}\n", .{ ColorName.red, ColorName.default, str, ColorName.default });
        },
    }
}

pub fn drawCharToImage(psf_font: psf.Font, image: ImageOld, char: u21, pos: ui.Vec) !void {
    const bitmap = psf_font.glyphs.get(char) orelse return;

    const imgw: usize = @intCast(image.width);
    const imgh: usize = @intCast(image.height);

    const image_data: []align(1) u16 = @as([*]u16, @ptrCast(@alignCast(image.data)))[0 .. imgw * imgh];

    const color = 0x7f_ee;
    const shadow_color = 0x7f_00;

    const x: u15 = @intCast(pos.x);
    var y: u15 = @intCast(pos.y);

    for (bitmap) |byte| {
        // Shadow
        if (byte & 0b10000000 != 0) image_data[x + 1 + (y + 1) * imgw] = shadow_color;
        if (byte & 0b01000000 != 0) image_data[x + 2 + (y + 1) * imgw] = shadow_color;
        if (byte & 0b00100000 != 0) image_data[x + 3 + (y + 1) * imgw] = shadow_color;
        if (byte & 0b00010000 != 0) image_data[x + 4 + (y + 1) * imgw] = shadow_color;
        if (byte & 0b00001000 != 0) image_data[x + 5 + (y + 1) * imgw] = shadow_color;

        if (byte & 0b10000000 != 0) image_data[x + 0 + y * imgw] = color;
        if (byte & 0b01000000 != 0) image_data[x + 1 + y * imgw] = color;
        if (byte & 0b00100000 != 0) image_data[x + 2 + y * imgw] = color;
        if (byte & 0b00010000 != 0) image_data[x + 3 + y * imgw] = color;
        if (byte & 0b00001000 != 0) image_data[x + 4 + y * imgw] = color;

        y += 1;

        if (y == psf_font.h) {
            y = @intCast(pos.y);
        }
    }
}

