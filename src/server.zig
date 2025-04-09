const std = @import("std");
const socket = @import("socket.zig");
const message = @import("message.zig");

const Message = message.Message;
const MessageType = message.MessageType;

pub fn runServer() !void {
    var sock = try socket.Socket.init("127.0.0.1", 9000);
    try sock.bind();

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

        if (msg.type == MessageType.Ping) {
            std.debug.print("Received PING from client!\n", .{});

            var reply_buffer: [1024]u8 = undefined;
            const reply = Message{
                .type = MessageType.Pong,
                .payload_length = 4,
                .payload = [_]u8{ 'P', 'o', 'n', 'g' } ++ [_]u8{0} ** (1024 - 4),
            };
            const reply_len = try reply.encode(reply_buffer[0..]);

            _ = try std.posix.sendto(
                sock.socket,
                reply_buffer[0..reply_len],
                0,
                &src_address,
                address_length,
            );
        }
    }
}
