const std = @import("std");
const engine = @import("../engine.zig");

pub const ticks_per_second = 24;
const ns_per_tick = std.time.ns_per_s / ticks_per_second;

pub fn tickMainThread(comptime onEveryTickFn: fn () anyerror!void) !void {
    while (true) {
        const time_before = std.time.nanoTimestamp();
        try onEveryTickFn();
        const time_after = std.time.nanoTimestamp();

        engine.tick_time = @intCast(time_after - time_before);
        const ns_remaining = ns_per_tick - engine.tick_time;

        if (ns_remaining > 0) {
            std.time.sleep(@intCast(ns_remaining));
        } else {
            std.debug.print("{}::{} game tick took too long! {d} milliseconds longer than tick rate{}\n", .{
                engine.ColorName.yellow,
                engine.ColorName.default,
                @divTrunc(ns_remaining, std.time.ns_per_ms),
                engine.ColorName.default,
            });
        }
    }
}
