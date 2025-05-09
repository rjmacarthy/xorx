const std = @import("std");
const node = @import("node.zig");
const errors = @import("errors.zig");
const utils = @import("utils.zig");
const constants = @import("constants.zig");

const NodeId = node.NodeId;
const K = constants.k;
const mem = std.mem;

const RoutingEntry = struct {
    id: NodeId,
    last_seen: i64,
    address: std.net.Address,
};

pub const RoutingTable = struct {
    buckets: [constants.bucket_count]std.ArrayList(RoutingEntry),
    local_id: [20]u8,

    pub fn init(allocator: std.mem.Allocator, local_id: [20]u8) !RoutingTable {
        var buckets: [constants.bucket_count]std.ArrayList(RoutingEntry) = undefined;

        for (&buckets) |*bucket| {
            bucket.* = std.ArrayList(RoutingEntry).init(allocator);
        }

        return RoutingTable{
            .buckets = buckets,
            .local_id = local_id,
        };
    }

    pub fn deinit(self: *RoutingTable) void {
        for (self.buckets) |*bucket| {
            bucket.deinit();
        }
    }

    pub fn pingNode(self: *RoutingTable, entry: RoutingEntry) !bool {
        _ = self;
        _ = entry;
        return std.crypto.random.int(u1) == 0;
    }

    pub fn addNode(
        self: *RoutingTable,
        new_node: NodeId,
    ) errors.RoutingTableError!void {
        const dist = utils.xorDistance(new_node.id, self.local_id);
        const bucket_idx = utils.getBucketIndex(dist);
        const bucket = &self.buckets[bucket_idx];

        for (bucket.items) |item| {
            if (mem.eql(u8, &item.id.id, &new_node.id)) {
                return;
            }
        }

        if (bucket.items.len < K) {
            try bucket.append(RoutingEntry{
                .id = new_node,
                .last_seen = std.time.milliTimestamp(),
                .address = try std.net.Address.parseIp4("127.0.0.1", 9000),
            });
            return;
        }

        const oldest = bucket.items[0]; // assume index 0 for now
        const success = try self.pingNode(oldest);

        if (!success) {
            bucket.items[0] = RoutingEntry{
                .id = new_node,
                .last_seen = std.time.milliTimestamp(),
                .address = try std.net.Address.parseIp4("127.0.0.1", 9000),
            };
        } else {
            return errors.RoutingTableError.NoSpace;
        }
    }

    pub fn getKClosest(self: *RoutingTable, target: NodeId, k: usize) []const NodeId {
        var all_nodes: [constants.max_node_count]NodeId = undefined;
        var count: usize = 0;

        for (self.buckets) |bucket| {
            for (bucket.items) |bucketNode| {
                all_nodes[count] = bucketNode.id;
                count += 1;
            }
        }

        std.mem.sort(NodeId, all_nodes[0..count], target, utils.comparator);

        return all_nodes[0..@min(k, count)];
    }

    pub fn getClosest(self: *RoutingTable, target: NodeId) NodeId {
        var closest: ?NodeId = null;
        var closest_dist: [20]u8 = undefined;
        for (self.buckets) |bucket| {
            for (bucket.items) |bucketNode| {
                const dist = utils.xorDistance(bucketNode.id.id, target.id);

                if (closest == null or utils.compareXorDistance(dist, closest_dist) == -1) {
                    closest = bucketNode.id;
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
                for (bucket.items, 0..) |bucketNode, j| {
                    try stdout.print("    Node {}: ", .{j});
                    for (bucketNode.id.id) |byte| {
                        try stdout.print("{x:0>2}", .{byte});
                    }
                    try stdout.print("\n", .{});
                }
            }
        }
    }
};

test "instantiation" {
    var da = std.heap.DebugAllocator(.{}){};
    const allocator = da.allocator();
    const id = [_]u8{0x11} ++ [_]u8{0} ** 19;
    const routing_table = try RoutingTable.init(allocator, id);
    try std.testing.expectEqual(routing_table.buckets.len, 160);
}

test "add node" {
    var da = std.heap.DebugAllocator(.{}){};
    const allocator = da.allocator();
    const id = [_]u8{0x11} ++ [_]u8{0} ** 19;
    var table = try RoutingTable.init(allocator, id);
    const new_node = NodeId{ .id = [_]u8{0x13} ++ [_]u8{0} ** 19 };
    try table.addNode(new_node);
}

test "get closest" {
    var da = std.heap.DebugAllocator(.{}){};
    const allocator = da.allocator();
    const id = [_]u8{0x11} ++ [_]u8{0} ** 19;
    var table = try RoutingTable.init(allocator, id);
    const new_node = NodeId{ .id = [_]u8{0x11} ++ [_]u8{0} ** 19 };
    try table.addNode(new_node);
    const closest = table.getClosest(new_node);
    try std.testing.expectEqual(closest.id, new_node.id);
}
