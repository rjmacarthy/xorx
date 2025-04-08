const std = @import("std");
const routing_table = @import("routing_table.zig");
const dht = @import("dht.zig");
const RoutingTable = routing_table.RoutingTable;

const DHT = dht.DHT;

pub const NodeId = struct {
    id: [20]u8,
    pub fn random(rnd: std.Random) NodeId {
        var id = NodeId{ .id = undefined };
        rnd.bytes(&id.id);
        return id;
    }
    pub fn fromBytes(bytes: [20]u8) NodeId {
        return NodeId{ .id = bytes };
    }
    pub fn print(self: *const NodeId, label: []const u8) !void {
        const stdout = std.io.getStdOut().writer();
        try stdout.print("{s}: ", .{label});
        for (self.id) |byte| {
            try stdout.print("{x:0>2}", .{byte});
        }
        try stdout.print("\n", .{});
    }
};

pub const Node = struct {
    id: NodeId,
    last_seen: i64,
    address: std.net.Address,
    routing_table: RoutingTable,
    allocator: std.mem.Allocator,
    buffer: [1024]u8,

    pub fn init(id: NodeId) !Node {
        var node = Node{
            .id = id,
            .last_seen = std.time.milliTimestamp(),
            .address = try std.net.Address.parseIp4("127.0.0.1", 9000),
            .allocator = undefined,
            .routing_table = undefined,
            .buffer = undefined,
        };

        var node_ptr = &node;
        var fba = std.heap.FixedBufferAllocator.init(&node_ptr.buffer);
        node_ptr.allocator = fba.allocator();
        node_ptr.routing_table = try RoutingTable.init(node_ptr.allocator);

        return node;
    }

    pub fn add_peer(self: *Node, peer: NodeId) !void {
        try self.routing_table.add_node(peer, self.id);
    }

    pub fn find_k_closest(self: *Node, target: NodeId, k: usize) []const NodeId {
        return self.routing_table.get_k_closest_nodes(target, k);
    }
};

test "node can add peer" {
    var prng = std.Random.DefaultPrng.init(42);
    const rand = prng.random();

    const local_id = NodeId.random(rand);
    var node = try Node.init(local_id);

    const peer_id = NodeId.random(rand);
    try node.add_peer(peer_id);

    const closest = node.find_k_closest(peer_id, 1);
    try std.testing.expect(std.mem.eql(u8, &closest[0].id, &peer_id.id));
}
