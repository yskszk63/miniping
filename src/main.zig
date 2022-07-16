const std = @import("std");
const os = std.os;
const IPV4 = std.x.os.IPv4;
const FixedBufferAllocator = std.heap.FixedBufferAllocator;

const Errors = error{
    NeedIpv4InArgs,
    Timeout,
    UnexpectedPacketLength,
};

fn ipFromArgs() !?IPV4 {
    var buf: [8192]u8 = undefined;
    const alloc = FixedBufferAllocator.init(buf[0..]).allocator();
    var args = try std.process.argsWithAllocator(alloc);
    defer args.deinit();
    _ = args.skip();
    while (args.next(alloc)) |arg| {
        const a = try arg;
        return try IPV4.parse(a);
    }
    return null;
}

pub fn main() !void {
    const ip = (try ipFromArgs()) orelse return Errors.NeedIpv4InArgs;

    const sock = try os.socket(os.AF.INET, os.SOCK.DGRAM | os.SOCK.CLOEXEC | os.SOCK.NONBLOCK, os.IPPROTO.ICMP);
    defer os.closeSocket(sock);

    const wbuf = [_]u8{
        0x08, // type icmp echo
        0x00, // code
        0x00, 0x00, // checksum
        0x00, 0x00, // id
        0x00, 0x01, // sequence
    };
    var rbuf: [8]u8 = undefined;
    const addr = os.sockaddr{
        .family = os.AF.INET,
        .data = [14]u8{
            0x00, 0x07, // port
            ip.octets[0], ip.octets[1], ip.octets[2], ip.octets[3], // addr
            0, 0, 0, 0, 0, 0, 0, 0, // zero
        },
    };

    var fds = [_]os.pollfd{
        // event for read
        os.pollfd{
            .fd = sock,
            .events = os.POLL.IN,
            .revents = 0,
        },
        // event for write
        os.pollfd{
            .fd = sock,
            .events = os.POLL.OUT,
            .revents = 0,
        },
    };
    const rev = &fds[0];
    const wev = &fds[1];
    var ntimeout: u32 = 0;
    while (rev.events != 0 or wev.events != 0) {
        if ((try os.poll(fds[0..], 100)) < 1) {
            ntimeout += 1;
            if (ntimeout > 10) {
                return Errors.Timeout;
            }
            continue;
        }

        if (rev.revents != 0) {
            const n = try os.recvfrom(sock, rbuf[0..], 0, null, null);
            if (n != 8) {
                return Errors.UnexpectedPacketLength;
            }
            rev.events = 0;
        }

        if (wev.revents != 0) {
            const n = try os.sendto(sock, wbuf[0..], 0, &addr, 16);
            if (n != 8) {
                return Errors.UnexpectedPacketLength;
            }
            wev.events = 0;
        }
    }
}
