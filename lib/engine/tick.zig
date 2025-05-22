const std = @import("std");

pub const ticks_per_second = 24;
const ns_per_tick = std.time.ns_per_s / ticks_per_second;

pub fn tickMainThread(comptime onEveryTickFn: fn() anyerror!void) !void {
    while (true) {
        const time_before = std.time.nanoTimestamp();
        try onEveryTickFn();
        const time_after = std.time.nanoTimestamp();

        const ns_this_tick = time_after - time_before;
        const ns_remaining = ns_per_tick - ns_this_tick;

        if (ns_remaining > 0) {
            //std.debug.print("remaining time = {d}\n", .{ns_remaining});
            std.time.sleep(@intCast(ns_remaining));
        } else {
            std.debug.print("game tick took too long! {d} nanoseconds greater than tick rate\n", .{@abs(ns_remaining)});
        }

    }

}
