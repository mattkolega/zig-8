const std = @import("std");

const app = @import("application.zig");
const args = @import("args.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const interpreterParams = try args.processArgs(allocator);

    app.run(interpreterParams, allocator);
}
