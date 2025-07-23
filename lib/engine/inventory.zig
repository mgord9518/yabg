const engine = @import("../engine.zig");

pub fn Inventory(comptime IdType: type) type {
    return struct{
        const Self = @This();
        const Item = engine.Item(IdType);
        const stack_size = 96;

        items: [6]?ItemStack = .{null} ** 6,
        selected_slot: usize = 0,

        pub const ItemStack = struct {
            value: Item,
            count: u8,
        };

        // Returns `true` if items were successfully added to inventory
        pub fn add(self: *Self, item: Item, count: u8) bool {
            var remaining = count;

            for (&self.items) |*maybe_slot_stack| {
                if (remaining == 0) break;

                if (maybe_slot_stack.*) |*slot_stack| {
                    if (slot_stack.*.value.canStackWith(item)) {
                        const extra_slots = stack_size - slot_stack.*.count;

                        const take = @min(extra_slots, count);

                        slot_stack.*.count += take;
                        remaining -= take;
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
    };
}
