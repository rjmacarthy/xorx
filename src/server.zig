const std = @import("std");
const socket = @import("socket.zig");
const constants = @import("constants.zig");
const message = @import("message.zig");
const node_mod = @import("node.zig");

const Node = node_mod.Node;
const NodeId = node_mod.NodeId;
const Message = message.Message;
const MessageType = message.MessageType;
const FindNode = message.FindNode;
const FindNodeResponse = message.FindNodeResponse;
const K = constants.k;

pub fn runServer() !void {
    var sock = try socket.Socket.init("127.0.0.1", 9000);
    try sock.bind();

    const my_id = NodeId.random();
    var my_node = try Node.init(my_id);

    var buffer: [1024]u8 = undefined;
    var src_address: std.posix.sockaddr = undefined;
    var address_length: std.posix.socklen_t = @sizeOf(std.posix.sockaddr);

    while (true) {
        const received = try std.posix.recvfrom(
            sock.socket,
            &buffer,
            0,
            &src_address,
            &address_length,
        );

        const msg = try Message.decode(buffer[0..received]);

        switch (msg.type) {
            MessageType.FindNode => {
                std.debug.print("Received FindNode from client\n", .{});

                var stream = std.io.fixedBufferStream(&msg.payload);
                const req = try FindNode.decode(stream.reader());

                const closest = my_node.getKClosest(req.target_id, 8);

                var payload_buf: [1024]u8 = undefined;
                var out_stream = std.io.fixedBufferStream(&payload_buf);

                var response = FindNodeResponse{
                    .from_id = my_node.id,
                    .count = @intCast(closest.len),
                    .nodes = blk: {
                        var temp: [K]NodeId = undefined;
                        for (closest, 0..) |id, i| temp[i] = id;
                        break :blk temp;
                    },
                };

                try response.encode(out_stream.writer());

                const response_msg = Message{
                    .type = MessageType.FindNode,
                    .payload_length = @intCast(out_stream.pos),
                    .payload = payload_buf,
                };

                var send_buf: [1024]u8 = undefined;
                const send_len = try response_msg.encode(&send_buf);

                _ = try std.posix.sendto(
                    sock.socket,
                    send_buf[0..send_len],
                    0,
                    &src_address,
                    address_length,
                );
            },

            MessageType.Ping => {
                std.debug.print("Received Ping from client\n", .{});

                var reply_payload: [1024]u8 = undefined;
                std.mem.copyForwards(u8, reply_payload[0..4], "Pong");

                const reply = Message{
                    .type = MessageType.Pong,
                    .payload_length = 4,
                    .payload = reply_payload,
                };

                var send_buf: [1024]u8 = undefined;
                const reply_len = try reply.encode(&send_buf);

                _ = try std.posix.sendto(
                    sock.socket,
                    send_buf[0..reply_len],
                    0,
                    &src_address,
                    address_length,
                );
            },

            else => {
                std.debug.print("Unhandled message type\n", .{});
            },
        }
    }
}
