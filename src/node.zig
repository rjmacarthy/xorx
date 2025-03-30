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
    routing_table: RoutingTable,

    pub fn init(id: NodeId) Node {
        var buffer: [1024]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buffer);
        const allocator = fba.allocator();
        const rt = try RoutingTable.init(allocator);
        return Node{
            .id = id,
            .routing_table = rt,
        };
    }

    pub fn add_peer(self: *Node, peer: NodeId) !void {
        try self.routing_table.add_node(peer, self.id);
    }

    pub fn find_k_closest(self: *Node, target: NodeId, k: usize) []const NodeId {
        return self.routing_table.get_k_closest_nodes(target, k);
    }
};
