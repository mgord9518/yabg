pub const Inventory = @This();

const engine = @import("../engine.zig");

items: [6]?ItemStack = .{null} ** 6,
selected_slot: usize = 0,

pub const ItemStack = struct {
    value: engine.Item,
    count: u8,
};

// Returns `true` if items were successfully added to inventory
pub fn add(self: *Inventory, item: engine.Item, count: u8) bool {
    var remaining = count;

    for (&self.items) |*maybe_slot_stack| {
        if (remaining == 0) break;

        if (maybe_slot_stack.*) |*slot_stack| {
            if (slot_stack.*.value.canStackWith(item)) {
                // TODO: check max stack size
                slot_stack.*.count += remaining;
                remaining -= remaining;
            }
        } else {
            maybe_slot_stack.* = .{ .value = item, .count = remaining };
            remaining -= remaining;
        }
    }

    if (remaining != 0) {
        return false;
    }

    return true;
}
