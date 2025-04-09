const std = @import("std");

const message = @import("message.zig");

const Message = message.Message;
const MessageType = message.MessageType;

pub fn runClient() !void {
    const server = try std.net.Address.parseIp4("127.0.0.1", 9000);
    const sock = try std.posix.socket(std.posix.AF.INET, std.posix.SOCK.DGRAM, 0);
    errdefer std.posix.close(sock);

    var buffer: [1024]u8 = undefined;
    const ping = Message{
        .type = MessageType.Ping,
        .payload_length = 3,
        .payload = [_]u8{} ++ [_]u8{0} ** (1024),
    };
    const len = try ping.encode(buffer[0..]);

    _ = try std.posix.sendto(sock, buffer[0..len], 0, &server.any, server.getOsSockLen());

    var receive_buffer: [1024]u8 = undefined;
    var src_address: std.posix.sockaddr = undefined;
    var address_length: std.posix.socklen_t = @sizeOf(std.posix.sockaddr);

    const recv_len = try std.posix.recvfrom(sock, &receive_buffer, 0, &src_address, &address_length);
    const response = try Message.decode(receive_buffer[0..recv_len]);

    std.debug.print("Client received message: {s}\n", .{response.payload[0..response.payload_length]});
}
