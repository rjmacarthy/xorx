const std = @import("std");

const message = @import("message.zig");

const Message = message.Message;
const MessageType = message.MessageType;

pub fn run_client() !void {
    const server = try std.net.Address.parseIp4("127.0.0.1", 9000);
    const sock = try std.posix.socket(std.posix.AF.INET, std.posix.SOCK.DGRAM, 0);
    errdefer std.posix.close(sock);

    var buffer: [1024]u8 = undefined;
    const ping = Message{
        .type = MessageType.Ping,
        .payload_len = 3,
        .payload = [_]u8{} ++ [_]u8{0} ** (1024),
    };
    const len = try ping.encode(buffer[0..]);

    _ = try std.posix.sendto(sock, buffer[0..len], 0, &server.any, server.getOsSockLen());

    var recv_buf: [1024]u8 = undefined;
    var src_addr: std.posix.sockaddr = undefined;
    var addr_len: std.posix.socklen_t = @sizeOf(std.posix.sockaddr);

    const recv_len = try std.posix.recvfrom(sock, &recv_buf, 0, &src_addr, &addr_len);
    const response = try Message.decode(recv_buf[0..recv_len]);

    std.debug.print("Client received message: {s}\n", .{response.payload[0..response.payload_len]});
}
