const std = @import("std");

const message = @import("message.zig");
const node = @import("node.zig");

const Message = message.Message;
const MessageType = message.MessageType;
const NodeId = node.NodeId;
const FindNode = message.FindNode;
const FindNodeResponse = message.FindNodeResponse;

fn sendMessage(to: std.net.Address, msg: Message) !Message {
    const sock = try std.posix.socket(std.posix.AF.INET, std.posix.SOCK.DGRAM, 0);
    errdefer std.posix.close(sock);

    var send_buf: [1024]u8 = undefined;
    const msg_len = try msg.encode(&send_buf);
    _ = try std.posix.sendto(sock, send_buf[0..msg_len], 0, &to.any, to.getOsSockLen());

    var recv_buf: [1024]u8 = undefined;
    var src_addr: std.posix.sockaddr = undefined;
    var addr_len: std.posix.socklen_t = @sizeOf(std.posix.sockaddr);

    const recv_len = try std.posix.recvfrom(sock, &recv_buf, 0, &src_addr, &addr_len);
    return try Message.decode(recv_buf[0..recv_len]);
}

pub fn runClient() !void {
    const server = try std.net.Address.parseIp4("127.0.0.1", 9000);

    const msg = Message{
        .type = MessageType.Ping,
        .payload_length = 4,
        .payload = [_]u8{ 'P', 'i', 'n', 'g' } ++ [_]u8{0} ** (1024 - 4),
    };

    const response = try sendMessage(server, msg);
    std.debug.print("Client received message: {s}\n", .{response.payload[0..response.payload_length]});
}

pub fn findNode(peer_addr: std.net.Address, self_id: NodeId, target: NodeId) ![]NodeId {
    var payload_buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&payload_buf);
    const find_node = FindNode{
        .from_id = self_id,
        .target_id = target,
    };

    try find_node.encode(stream.writer());

    const payload_len = stream.pos;

    const msg = Message{
        .type = MessageType.FindNode,
        .payload_length = @intCast(payload_len),
        .payload = payload_buf,
    };

    const response_msg = try sendMessage(peer_addr, msg);

    var reader = std.io.fixedBufferStream(&response_msg.payload);
    const response = try FindNodeResponse.decode(reader.reader());

    return response.nodes[0..response.count];
}
