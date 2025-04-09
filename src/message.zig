const std = @import("std");

pub const MessageType = enum(u8) {
    Ping = 0,
    Pong = 1,
    FindNode = 2,
};

pub const Message = struct {
    type: MessageType,
    payload_length: u16,
    payload: [1024]u8,

    pub fn encode(self: *const Message, buf: []u8) !usize {
        if (buf.len < 3 + self.payload_length) return error.BufferTooSmall;
        buf[0] = @intFromEnum(self.type);
        std.mem.writeInt(u16, buf[1..3], self.payload_length, .little);
        std.mem.copyForwards(u8, buf[3 .. 3 + self.payload_length], self.payload[0..self.payload_length]);
        return 3 + self.payload_length;
    }

    pub fn decode(buf: []const u8) !Message {
        if (buf.len < 3) return error.InvalidMessage;
        const msg_type = try std.meta.intToEnum(MessageType, buf[0]);
        const payload_len = std.mem.readInt(u16, buf[1..3], .little);
        if (buf.len < 3 + payload_len) return error.InvalidMessage;
        var payload_buf: [1024]u8 = undefined;
        std.mem.copyForwards(u8, payload_buf[0..payload_len], buf[3 .. 3 + payload_len]);
        return Message{
            .type = msg_type,
            .payload_length = payload_len,
            .payload = payload_buf,
        };
    }
};

test "message decoder" {
    const buffer = [_]u8{} ++ [_]u8{ 0, 10 } ** (1024);
    const decoded = try Message.decode(buffer[0..buffer.len]);
    try std.testing.expectEqual(decoded.type, MessageType.Ping);
    try std.testing.expectEqual(decoded.payload_length, @as(u16, 10));
    try std.testing.expectEqual(decoded.payload.len, @as(u16, 1024));
}

test "message encoder" {
    const payload = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };
    var message = Message{ .payload = [_]u8{} ++ [_]u8{0} ** (1024), .payload_length = 10, .type = MessageType.Pong };
    std.mem.copyForwards(u8, message.payload[0..payload.len], &payload);
    var buffer: [1024]u8 = undefined;
    const encoded = try message.encode(&buffer);
    try std.testing.expectEqual(@as(usize, 13), encoded);
    try std.testing.expectEqual(@as(u8, 1), buffer[0]); // pong
    try std.testing.expectEqual(@as(u16, 10), std.mem.readInt(u16, buffer[1..3], .little));
    try std.testing.expectEqualSlices(u8, payload[0..], buffer[3..13]);
}
