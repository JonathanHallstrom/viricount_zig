const std = @import("std");

const viriformat_parsing = @import("count.zig");

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    const program_start = std.Io.Timestamp.now(io, .real);

    const allocator = init.gpa;
    var args = try init.minimal.args.iterateAllocator(allocator);
    defer args.deinit();

    var files = std.array_list.Managed(std.Io.File).init(allocator);
    defer files.deinit();

    const own_name = args.next().?;
    _ = own_name;

    while (args.next()) |filename| {
        try files.append(try std.Io.Dir.cwd().openFile(io, filename, .{ .mode = .read_only }));
    }
    defer {
        for (files.items) |file| {
            file.close(io);
        }
    }

    const CountResult = @typeInfo(@TypeOf(viriformat_parsing.parse_file)).@"fn".return_type.?;

    var futures = std.array_list.Managed(std.Io.Future(CountResult)).init(allocator);
    defer futures.deinit();

    for (files.items) |file| {
        try futures.append(io.async(viriformat_parsing.parse_file, .{ io, file }));
    }

    var total_games: u64 = 0;
    var total_positions: u64 = 0;
    var parsing_time = std.Io.Duration.zero;
    var total_size: u64 = 0;

    for (futures.items) |*future| {
        if (future.await(io)) |res| {
            total_games += res.games;
            total_positions += res.positions;
            parsing_time.nanoseconds += res.time.nanoseconds;
            total_size += res.size;
        } else |err| {
            std.log.err("{}", .{err});
        }
    }

    const elapsed_ns: u96 = @intCast(parsing_time.toNanoseconds());

    const stdout_file = std.Io.File.stdout();
    var stdout_buf: [4096]u8 = undefined;
    var stdout = stdout_file.writer(io, &stdout_buf);

    const total_time = program_start.untilNow(io, .real);

    try stdout.interface.print(
        \\total games:     {}
        \\total positions: {}
        \\parsing time:    {f}
        \\total time       {f}
        \\speed:           {Bi:.2}/s
        \\
    , .{
        total_games,
        total_positions,
        parsing_time,
        total_time,
        @as(u64, @intCast(@as(u128, total_size) * std.time.ns_per_s / elapsed_ns)),
    });
    try stdout.flush();
}
