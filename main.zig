const std = @import("std");
const Io = std.Io;
const mem = std.mem;

fn fileReader(in: *Io.Reader, out: *Io.Writer, buffer: []u8) !usize {
    var copied: usize = 0;
    while (true) {
        const n = try in.readSliceShort(buffer);
        if (n == 0) return copied;
        try out.writeAll(buffer[0..n]);
        copied += n;
    }
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    var arena_allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    const args = try init.minimal.args.toSlice(arena);
    const paths = args[1..];

    var stdout_buf: [64 * 1024]u8 = undefined;
    var stdout_writer = Io.File.stdout().writerStreaming(io, &stdout_buf);
    var out = &stdout_writer.interface;

    var copy_buf: [64 * 1024]u8 = undefined;

    var processed_any = false;
    const cwd = Io.Dir.cwd();

    if (paths.len == 0) {
        var stdin_reader = Io.File.stdin().readerStreaming(io, &.{});
        _ = try fileReader(&stdin_reader.interface, out, &copy_buf);
    } else {
        for (paths) |path| {
            if (mem.eql(u8, path, "-")) {
                var stdin_reader = Io.File.stdin().readerStreaming(io, &.{});
                _ = try fileReader(&stdin_reader.interface, out, &copy_buf);
                try out.flush();
                processed_any = true;
                continue;
            }

            const file = cwd.openFile(io, path, .{}) catch |err| {
                std.log.err("owl - {s}: {s}", .{ path, @errorName(err) });
                continue;
            };
            defer file.close(io);
            processed_any = true;

            var file_reader = file.readerStreaming(io, &.{});
            _ = try fileReader(&file_reader.interface, out, &copy_buf);
            try out.flush();
        }
    }
    try out.flush();

    if (paths.len > 0 and !processed_any) {
        std.process.exit(1);
    }
}
