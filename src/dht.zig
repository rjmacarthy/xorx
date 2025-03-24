const std = @import("std");
const node = @import("node.zig");
const utils = @import("utils.zig");

const Node = node.Node;
const NodeId = node.NodeId;
const RndGen = std.Random.DefaultPrng;

pub const DHT = struct {
    local_node: Node,
    prng: RndGen,

    pub fn init(seed: u64) DHT {
        var prng = RndGen.init(seed);
        const rand = prng.random();
        const local_id = NodeId.random(rand);
        return DHT{
            .local_node = Node.init(local_id),
            .prng = prng,
        };
    }

    pub fn generate_target(self: *DHT) NodeId {
        return NodeId.random(self.prng.random());
    }

    pub fn add_peer(self: *DHT, peer: NodeId) !void {
        try self.local_node.add_peer(peer);
    }

    pub fn add_random_peer(self: *DHT) !void {
        const peer_id = NodeId.random(self.prng.random());
        try self.add_peer(peer_id);
    }

    pub fn find_k_closest(self: *DHT, target: NodeId, k: usize) []const NodeId {
        return self.local_node.findKClosest(target, k);
    }

    pub fn printRoutingTable(self: *DHT) !void {
        try self.local_node.routing_table.print();
    }
};

pub const DHTNetwork = struct {
    dhts: [10]DHT,

    pub fn init() DHTNetwork {
        var result: DHTNetwork = undefined;

        var i: usize = 0;
        while (i < 10) : (i += 1) {
            result.dhts[i] = DHT.init(@intCast(i + 42));
        }

        return result;
    }
    pub fn print_all(self: *DHTNetwork) !void {
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
    fn find_node_index(self: *DHTNetwork, id: NodeId) ?usize {
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
        var current_index = start_index;
        var closest = self.dhts[current_index].local_node.id;
        var closest_dist = utils.xor_distance(closest.id, target.id);

        while (true) {
            visited[current_index] = true;

            const candidates = self.dhts[current_index].local_node.find_k_closest(target, k);

            var found_better = false;

            for (candidates) |candidate| {
                if (self.find_node_index(candidate)) |idx| {
                    if (!visited[idx]) {
                        const dist = utils.xor_distance(candidate.id, target.id);
                        if (utils.compare_xor_distance(dist, closest_dist) == -1) {
                            closest_dist = dist;
                            closest = candidate;
                            current_index = idx;
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
