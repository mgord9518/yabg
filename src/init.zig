const std = @import("std");
const engine = @import("engine");

const textures = @import("textures.zig");

pub fn initTextures(comptime IdType: type) !void {
    // UI elements
    engine.textures.hotbar_item = engine.loadTextureEmbedded("ui/hotbar_item");

    engine.textures.cursor = try textures.cursor.toTexture();

    inline for (std.meta.fields(IdType)) |tile| {
        std.debug.print("loading {s}\n", .{tile.name});
        const tile_id: IdType = @enumFromInt(tile.value);

        // Exceptions
        switch (tile_id) {
            .air => continue,
            else => {},
        }

        const tile_texture = engine.loadTextureEmbedded("tiles/" ++ tile.name);

        engine.textures.tiles[tile.value] = tile_texture;

        // TODO: replace all PNG files with in-code images
        if (@hasDecl(textures.tiles, tile.name)) {
            engine.textures.tiles[tile.value] = try @field(textures.tiles, tile.name).toTexture();
        }
    }
}
