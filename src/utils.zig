const std = @import("std");
const node = @import("node.zig");
const routing_table = @import("routing_table.zig");

const Node = node.Node;
const NodeId = node.NodeId;

pub fn get_bucket_index(dist: [20]u8) usize {
    return @min(dist[0] / 51, 4);
}

pub fn comparator(ctx: NodeId, a: NodeId, b: NodeId) bool {
    const dist_a = xor_distance(ctx.id, a.id);
    const dist_b = xor_distance(ctx.id, b.id);
    return compare_xor_distance(dist_a, dist_b) == -1;
}

pub fn xor_distance(a: [20]u8, b: [20]u8) [20]u8 {
    var result: [20]u8 = undefined;
    for (result, 0..) |_, i| {
        result[i] = a[i] ^ b[i];
    }
    return result;
}

pub fn compare_xor_distance(a: [20]u8, b: [20]u8) i2 {
    var i: usize = 0;
    while (i < 20) : (i += 1) {
        if (a[i] < b[i]) return -1;
        if (a[i] > b[i]) return 1;
    }
    return 0;
}

test "xor_distance of identical IDs is zero" {
    const a = [_]u8{1} ** 20;
    const b = [_]u8{1} ** 20;
    const dist = xor_distance(a, b);
    for (dist) |byte| {
        try std.testing.expectEqual(@as(u8, 0), byte);
    }
}

test "xor_distance is symmetric" {
    const a = [_]u8{0xAA} ** 20;
    const b = [_]u8{0x55} ** 20;

    const dist1 = xor_distance(a, b);
    const dist2 = xor_distance(b, a);

    for (dist1, 0..) |byte, i| {
        try std.testing.expectEqual(byte, dist2[i]);
    }
}

test "compare_xor_distance ordering" {
    const d1 = [_]u8{ 0, 0, 0, 0, 1 } ++ [_]u8{0} ** 15;
    const d2 = [_]u8{ 0, 0, 0, 0, 2 } ++ [_]u8{0} ** 15;
    const d3 = d1;

    try std.testing.expectEqual(@as(i2, -1), compare_xor_distance(d1, d2));
    try std.testing.expectEqual(@as(i2, 1), compare_xor_distance(d2, d1));
    try std.testing.expectEqual(@as(i2, 0), compare_xor_distance(d1, d3));
}

test "get_k_closest_nodes returns sorted closest nodes" {
    var da = std.heap.DebugAllocator(.{}){};
    const allocator = da.allocator();
    var table = try routing_table.RoutingTable.init(allocator);
    const target = NodeId{ .id = [_]u8{0x10} ++ [_]u8{0} ** 19 };

    const node1 = NodeId{ .id = [_]u8{0x11} ++ [_]u8{0} ** 19 }; // dist = 0x01
    const node2 = NodeId{ .id = [_]u8{0x13} ++ [_]u8{0} ** 19 }; // dist = 0x03
    const node3 = NodeId{ .id = [_]u8{0x18} ++ [_]u8{0} ** 19 }; // dist = 0x08

    try table.add_node(node1, target);
    try table.add_node(node2, target);
    try table.add_node(node3, target);

    const top2 = table.get_k_closest_nodes(target, 2);

    try std.testing.expectEqual(top2.len, 2);
    try std.testing.expectEqual(top2[0].id, node1.id);
    try std.testing.expectEqual(top2[1].id, node2.id);
}
