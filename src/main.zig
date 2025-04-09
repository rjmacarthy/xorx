const std = @import("std");
const node = @import("node.zig");
const routing_table = @import("routing_table.zig");
const dht = @import("dht.zig");
const utils = @import("utils.zig");
const server = @import("server.zig");
const client = @import("client.zig");
const message = @import("message.zig");

const Node = node.Node;
const NodeId = node.NodeId;
const RndGen = std.Random.DefaultPrng;
const os = std.os;

pub fn main() !void {
    var net = try dht.DHTNetwork.init();

    const target = try Node.init(NodeId.random());
    const closest = net.lookup(0, target.id);

    try closest.print("Final closest");
    try target.id.print("Target");

    try net.print();

    const args = try std.process.argsAlloc(std.heap.page_allocator);
    if (args.len < 1) return error.MissingArgument;

    if (std.mem.eql(u8, args[1], "server")) {
        try server.runServer();
    } else if (std.mem.eql(u8, args[1], "client")) {
        try client.runClient();
    } else {
        std.debug.print("Usage: zig run -- server|client\n", .{});
    }
}
