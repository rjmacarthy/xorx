const std = @import("std");
const node = @import("node.zig");
const errors = @import("errors.zig");
const utils = @import("utils.zig");
const constants = @import("constants.zig");

const Node = node.Node;
const NodeId = node.NodeId;

pub const RoutingTable = struct {
    buckets: [5][3]NodeId,
    counts: [5]usize,

    pub fn init() RoutingTable {
        return RoutingTable{
            .buckets = undefined,
            .counts = [_]usize{0} ** 5,
        };
    }

    pub fn add_node(self: *RoutingTable, new_node: NodeId, local_id: NodeId) errors.RoutingTableError!void {
        const dist = utils.xor_distance(new_node.id, local_id.id);
        const bucket_idx = utils.get_bucket_index(dist);

        if (self.counts[bucket_idx] >= 3) {
            return errors.RoutingTableError.NoSpace;
        }

        self.buckets[bucket_idx][self.counts[bucket_idx]] = new_node;
        self.counts[bucket_idx] += 1;
    }

    pub fn get_k_closest_nodes(self: *RoutingTable, target: NodeId, k: usize) []const NodeId {
        var all_nodes: [constants.MAX_NODE_COUNT]NodeId = undefined;
        var count: usize = 0;

        for (self.buckets, self.counts) |bucket, bucket_count| {
            for (bucket[0..bucket_count]) |bucket_node| {
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
        for (self.buckets, self.counts) |bucket, count| {
            for (bucket[0..count]) |bucket_node| {
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
        for (self.buckets, self.counts, 0..) |bucket, count, i| {
            if (count > 0) {
                try stdout.print("  Bucket {} ({} nodes):\n", .{ i, count });
                for (bucket[0..count], 0..) |bucket_node, j| {
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
