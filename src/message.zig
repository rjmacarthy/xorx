const std = @import("std");
const io = std.io;

const node = @import("node.zig");
const constants = @import("constants.zig");

const NodeId = node.NodeId;
const K = constants.k;

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

pub const FindNode = struct {
    from_id: NodeId,
    target_id: NodeId,

    pub fn encode(self: *FindNode, writer: anytype) !void {
        try writer.writeAll(&self.from_id.id);
        try writer.writeAll(&self.target_id.id);
    }

    pub fn decode(reader: anytype) !FindNode {
        var from_buf: [20]u8 = undefined;
        var target_buf: [20]u8 = undefined;

        try reader.readNoEof(&from_buf);
        try reader.readNoEof(&target_buf);

        return FindNode{
            .from_id = NodeId{ .id = from_buf },
            .target_id = NodeId{ .id = target_buf },
        };
    }
};

test "FindNode" {
    var buf: [40]u8 = [_]u8{0} ** 40;
    var find_node = FindNode{
        .from_id = NodeId.random(),
        .target_id = NodeId.random(),
    };
    var stream = std.io.fixedBufferStream(&buf);
    try find_node.encode(stream.writer());
    stream.reset();
    const decoded = try FindNode.decode(stream.reader());
    try std.testing.expectEqualSlices(u8, &find_node.from_id.id, &decoded.from_id.id);
    try std.testing.expectEqualSlices(u8, &find_node.target_id.id, &decoded.target_id.id);
}

pub const FindNodeResponse = struct {
    from_id: NodeId,
    count: u8,
    nodes: [K]NodeId,

    pub fn encode(self: *FindNodeResponse, writer: anytype) !void {
        try writer.writeAll(&self.from_id.id);
        try writer.writeByte(self.count);

        for (0..self.count) |i| {
            try writer.writeAll(&self.nodes[i].id);
        }
    }

    pub fn decode(reader: anytype) !FindNodeResponse {
        var from_id_buf: [20]u8 = undefined;
        try reader.readNoEof(&from_id_buf);

        const count = try reader.readByte();

        var nodes: [K]NodeId = undefined;

        for (0..count) |i| {
            var node_buf: [20]u8 = undefined;
            try reader.readNoEof(&node_buf);
            nodes[i] = NodeId{ .id = node_buf };
        }

        return FindNodeResponse{
            .from_id = NodeId{ .id = from_id_buf },
            .count = count,
            .nodes = nodes,
        };
    }
};

test "FindNodeResponse" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);

    const node1 = NodeId.random();
    const node2 = NodeId.random();

    var response = FindNodeResponse{
        .from_id = node1,
        .count = 2,
        .nodes = [_]NodeId{ node1, node2 } ++ [_]NodeId{undefined} ** (K - 2),
    };

    try response.encode(stream.writer());

    stream.reset();

    const decoded = try FindNodeResponse.decode(stream.reader());

    try std.testing.expectEqualSlices(u8, &node1.id, &decoded.from_id.id);
    try std.testing.expectEqualSlices(u8, &node2.id, &decoded.nodes[1].id);
}

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
