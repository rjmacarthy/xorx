const std = @import("std");
const node = @import("node.zig");
const errors = @import("errors.zig");
const utils = @import("utils.zig");
const constants = @import("constants.zig");
const mem = std.mem;
const Node = node.Node;
const NodeId = node.NodeId;
const BUCKET_COUNT = 160;
const K = 8;

pub const RoutingTable = struct {
    buckets: [BUCKET_COUNT]std.ArrayList(NodeId),

    pub fn init(allocator: std.mem.Allocator) !RoutingTable {
        var buckets: [BUCKET_COUNT]std.ArrayList(NodeId) = undefined;

        var i: usize = 0;

        while (i < BUCKET_COUNT) : (i += 1) {
            buckets[i] = std.ArrayList(NodeId).init(allocator);
        }

        return RoutingTable{
            .buckets = buckets,
        };
    }

    pub fn deinit(self: *RoutingTable) void {
        for (self.buckets) |*bucket| {
            bucket.deinit();
        }
    }

    pub fn add_node(self: *RoutingTable, new_node: NodeId, local_id: NodeId) errors.RoutingTableError!void {
        const dist = utils.xor_distance(new_node.id, local_id.id);
        const bucket_idx = utils.get_bucket_index(dist);

        const bucket = self.buckets[bucket_idx];

        if (bucket.items.len >= K) {
            return errors.RoutingTableError.NoSpace;
        }

        try bucket.append(new_node);
    }

    pub fn get_k_closest_nodes(self: *RoutingTable, target: NodeId, k: usize) []const NodeId {
        var all_nodes: [constants.MAX_NODE_COUNT]NodeId = undefined;
        var count: usize = 0;

        for (self.buckets) |bucket| {
            for (bucket.items) |bucket_node| {
                all_nodes[count] = bucket_node;
                count += 1;
            }
        }

        std.mem.sort(NodeId, all_nodes[0..count], target, utils.comparator);

        return all_nodes[0..@min(k, count)];
    }

    pub fn get_closest_node(self: *RoutingTable, target: NodeId) NodeId {
        var closest: ?NodeId = null;
        var closest_dist: [20]u8 = undefined;
        for (self.buckets) |bucket| {
            for (bucket.items) |bucket_node| {
                const dist = utils.xor_distance(bucket_node.id, target.id);

                if (closest == null or utils.compare_xor_distance(dist, closest_dist) == -1) {
                    closest = bucket_node;
                    closest_dist = dist;
                }
            }
        }
        return closest.?;
    }

    pub fn print(self: *const RoutingTable) !void {
        const stdout = std.io.getStdOut().writer();
        try stdout.print("Routing Table:\n", .{});
        for (self.buckets, 0..) |bucket, i| {
            const count = bucket.items.len;
            if (count > 0) {
                try stdout.print("  Bucket {} ({} nodes):\n", .{ i, count });
                for (bucket.items, 0..) |bucket_node, j| {
                    try stdout.print("    Node {}: ", .{j});
                    for (bucket_node.id) |byte| {
                        try stdout.print("{x:0>2}", .{byte});
                    }
                    try stdout.print("\n", .{});
                }
            }
        }
    }
};
