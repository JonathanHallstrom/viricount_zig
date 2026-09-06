const std = @import("std");

const HEADER_SIZE = 32;
const MOVE_SIZE = 4;
const TERMINATOR: [4]u8 = @splat(0);

fn count_games_slice_scalar(bytes: []const u8) usize {
    var count: usize = 0;

    var i: usize = 0;
    while (i + HEADER_SIZE + MOVE_SIZE <= bytes.len) {
        i += HEADER_SIZE;
        count += 1;

        while (i + MOVE_SIZE <= bytes.len) : (i += MOVE_SIZE) {
            if (std.mem.eql(u8, bytes[i..][0..4], &TERMINATOR))
                break;
        }
    }

    return count;
}

pub fn count_games_slice(bytes: []align(4) const u8) usize {
    var count: usize = 0;

    var i: usize = 0;
    while (i + HEADER_SIZE + MOVE_SIZE <= bytes.len) {
        i += HEADER_SIZE;
        count += 1;

        const move_slice: []const u32 = @ptrCast(@alignCast(bytes[i..]));
        const end_idx = std.mem.indexOfScalar(u32, move_slice, 0) orelse move_slice.len;

        i += MOVE_SIZE * end_idx;
    }

    if (std.debug.runtime_safety)
        std.debug.assert(count == count_games_slice_scalar(bytes));

    return count;
}

pub const ParsedFile = struct {
    games: u64,
    positions: u64,
    size: u64,
    time: std.Io.Duration,
};

pub fn parse_file(io: std.Io, f: std.Io.File) !ParsedFile {
    const len = try f.length(io);
    var map = try f.createMemoryMap(io, .{
        .len = len,
        .protection = .{ .read = true, .write = false },
    });
    defer map.destroy(io);
    try map.read(io);

    const start = std.Io.Timestamp.now(io, .real);
    const games = count_games_slice(map.memory);
    const time = start.untilNow(io, .real);

    const bytes = map.memory.len;

    return .{
        .games = games,
        .positions = (bytes - 36 * games) / 4,
        .size = bytes,
        .time = time,
    };
}
