const std = @import("std");

const HEADER_SIZE = 32;
const MOVE_SIZE = 4;
const TERMINATOR: [4]u8 = @splat(0);

pub fn count_games_slice(bytes: []align(4) const u8) usize {
    var count: usize = 0;

    var i: usize = 0;
    while (i < bytes.len) {
        i += HEADER_SIZE;

        while (i < bytes.len) {
            i += MOVE_SIZE;
            if (std.mem.eql(u8, bytes[i..][0..4], &TERMINATOR))
                break;
        } else {
            break;
        }

        count += 1;
    }

    return count;
}

pub const Count = struct {
    games: usize,
    positions: usize,
};

pub fn count_file(io: std.Io, f: std.Io.File) !Count {
    const len = try f.length(io);
    var map = try f.createMemoryMap(io, .{
        .len = len,
        .protection = .{ .read = true, .write = false },
    });
    defer map.destroy(io);
    try map.read(io);

    const games = count_games_slice(map.memory);
    const bytes = map.memory.len;

    return .{
        .games = games,
        .positions = (bytes - 36 * games) / 4,
    };
}
