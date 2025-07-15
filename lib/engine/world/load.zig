const std = @import("std");
const engine = @import("../../engine.zig");

// Seconds
pub const time_between_loading_chunks = 5;

pub fn loadChunksMainThread(comptime onChunkLoadFn: fn () anyerror!void) !void {
    while (true) {
        const time_before = std.time.nanoTimestamp();
        try onChunkLoadFn();
        const time_after = std.time.nanoTimestamp();

        const ns_this_tick = time_after - time_before;
        const ns_remaining = (time_between_loading_chunks * std.time.ns_per_s) - ns_this_tick;

        if (ns_remaining > 0) {
            std.time.sleep(@intCast(ns_remaining));
        } else {
            std.debug.print("{}::{} Took {d}ms too long to save chunks!{}\n", .{
                engine.ColorName.yellow,
                engine.ColorName.default,
                @divTrunc(ns_remaining, std.time.ns_per_ms),
                engine.ColorName.default,
            });
        }
    }
}
