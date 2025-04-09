const std = @import("std");

const os = std.os;

pub const Socket = struct {
    address: std.net.Address,
    socket: std.posix.socket_t,

    pub fn init(ip: []const u8, port: u16) !Socket {
        const address = try std.net.Address.parseIp4(ip, port);
        const sock = try std.posix.socket(std.posix.AF.INET, std.posix.SOCK.DGRAM, 0);
        errdefer std.posix.close(sock);
        errdefer os.closeSocket(sock);
        return Socket{ .address = address, .socket = sock };
    }

    pub fn bind(self: *Socket) !void {
        try std.posix.bind(self.socket, &self.address.any, self.address.getOsSockLen());
    }

    pub fn listen(self: *Socket) !void {
        var buffer: [1024]u8 = undefined;
        var src_address: std.posix.sockaddr = undefined;
        var address_length: std.posix.socklen_t = @sizeOf(std.posix.sockaddr);

        while (true) {
            const received = try std.posix.recvfrom(self.socket, buffer[0..], 0, &src_address, &address_length);
            std.debug.print("Received {d} bytes: {s}\n", .{ received, buffer[0..received] });
        }
    }
};
