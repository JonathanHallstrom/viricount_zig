const std = @import("std");

const count = @import("count.zig");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    var args = try init.minimal.args.iterateAllocator(allocator);
    defer args.deinit();

    const io = init.io;

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

    const CountResult = @typeInfo(@TypeOf(count.count_file)).@"fn".return_type.?;

    var futures = std.array_list.Managed(std.Io.Future(CountResult)).init(allocator);
    defer futures.deinit();

    for (files.items) |file| {
        try futures.append(io.async(count.count_file, .{ io, file }));
    }

    var total_games: usize = 0;
    var total_positions: usize = 0;

    for (futures.items) |*future| {
        if (future.await(io)) |res| {
            total_games += res.games;
            total_positions += res.positions;
        } else |err| {
            std.log.err("{}", .{err});
        }
    }

    const stdout_file = std.Io.File.stdout();
    var stdout_buf: [4096]u8 = undefined;
    var stdout = stdout_file.writer(io, &stdout_buf);

    try stdout.interface.print(
        \\total games: {}
        \\total positions: {}
        \\
    , .{ total_games, total_positions });
    try stdout.flush();
}
