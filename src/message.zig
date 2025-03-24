const std = @import("std");

pub const MessageType = enum(u8) {
    Ping = 0,
    Pong = 1,
    FindNode = 2,
};

pub const Message = struct {
    type: MessageType,
    payload_len: u16,
    payload: [1024]u8,

    pub fn encode(self: *const Message, buf: []u8) !usize {
        if (buf.len < 3 + self.payload_len) return error.BufferTooSmall;
        buf[0] = @intFromEnum(self.type);
        std.mem.writeInt(u16, buf[1..3], self.payload_len, .little);
        std.mem.copyForwards(u8, buf[3 .. 3 + self.payload_len], self.payload[0..self.payload_len]);
        return 3 + self.payload_len;
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
            .payload_len = payload_len,
            .payload = payload_buf,
        };
    }
};
