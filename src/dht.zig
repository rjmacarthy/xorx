const std = @import("std");
const node = @import("node.zig");
const utils = @import("utils.zig");

const Node = node.Node;
const NodeId = node.NodeId;

pub const DHT = struct {
    local_node: Node,

    pub fn init() !DHT {
        const local_id = NodeId.random();
        return DHT{
            .local_node = try Node.init(local_id),
        };
    }

    pub fn addNode(self: *DHT, peer: NodeId) !void {
        try self.local_node.addNode(peer);
    }

    pub fn findKClosest(self: *DHT, target: NodeId, k: usize) []const NodeId {
        return self.local_node.find_k_closest(target, k);
    }

    pub fn print(self: *DHT) !void {
        try self.local_node.routing_table.print();
    }
};

test "dht init" {
    var dht = try DHT.init(42);
    try std.testing.expect(true);

    try dht.addNode(NodeId{ .id = [_]u8{0} ** (20) });
    try std.testing.expectEqual(dht.local_node.routing_table.buckets.len, 160);
}

pub const DHTNetwork = struct {
    dhts: [10]DHT,

    pub fn init() !DHTNetwork {
        var result: DHTNetwork = undefined;

        var i: usize = 0;
        while (i < 10) : (i += 1) {
            result.dhts[i] = try DHT.init();
        }

        return result;
    }
    pub fn print(self: *DHTNetwork) !void {
        const allocator = std.heap.page_allocator;
        for (&self.dhts, 0..) |*dht, i| {
            const string = try std.fmt.allocPrint(
                allocator,
                "{}",
                .{i},
            );
            try dht.local_node.id.print(string);
            defer allocator.free(string);
        }
    }
    fn findNodeIndex(self: *DHTNetwork, id: NodeId) ?usize {
        for (self.dhts, 0..) |dht, i| {
            if (std.mem.eql(u8, dht.local_node.id.id[0..], id.id[0..])) {
                return i;
            }
        }
        return null;
    }
    pub fn lookup(self: *DHTNetwork, start_index: usize, target: NodeId) NodeId {
        const k = 3;
        var visited: [10]bool = [_]bool{false} ** 10;
        var currentIndex = start_index;
        var closest = self.dhts[currentIndex].local_node.id;
        var closestDistance = utils.xorDistance(closest.id, target.id);

        while (true) {
            visited[currentIndex] = true;

            const candidates = self.dhts[currentIndex].local_node.getKClosest(target, k);

            var found_better = false;

            for (candidates) |candidate| {
                if (self.findNodeIndex(candidate)) |idx| {
                    if (!visited[idx]) {
                        const dist = utils.xorDistance(candidate.id, target.id);
                        if (utils.compareXorDistance(dist, closestDistance) == -1) {
                            closestDistance = dist;
                            closest = candidate;
                            currentIndex = idx;
                            found_better = true;
                        }
                    }
                }
            }
            if (!found_better) break;
        }
        return closest;
    }
};
