const std = @import("std");

const sokol = @import("sokol");
const slog = sokol.log;
const sgfx = sokol.gfx;
const sapp = sokol.app;
const sglue = sokol.glue;

const emu = @import("emulator.zig");
const log = @import("logger.zig");

// Constants
const WINDOW_TITLE = "ZIG-8";
const SCREEN_MULTI_FACTOR = 20;
const SCREEN_WIDTH = 64 * SCREEN_MULTI_FACTOR;
const SCREEN_HEIGHT = 32 * SCREEN_MULTI_FACTOR;

// Global variables
var prng: std.rand.DefaultPrng = undefined;
var rand: std.Random = undefined;

var arena: std.heap.ArenaAllocator = undefined;
var allocator: std.mem.Allocator = undefined;

var chip8Context: emu.Chip8Context = undefined;

var passAction: sgfx.PassAction = .{};

export fn init() void {
    sgfx.setup(.{
        .environment = sglue.environment(),
        .logger = .{ .func = slog.func },
    });
    passAction.colors[0] = .{
        .load_action = .CLEAR,
        .clear_value = .{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 1.0 },
    };

    log.info("Backend: {}", .{sgfx.queryBackend()});

    // Setup random number generation
    prng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        std.posix.getrandom(std.mem.asBytes(&seed)) catch {
            log.err("{s}", .{"Failed to initialise random number generator."});
            sapp.quit();
        };
        break :blk seed;
    });
    rand = prng.random();

    // Setup allocator
    arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    allocator = arena.allocator();

    // Keep running createContext until it either succeeds or file dialog is closed
    while (emu.createContext(allocator)) |value| {
        chip8Context = value;
        break;
    } else |err| switch (err) {
        error.FileOpenCancel => {
            sapp.quit();
        },
        else => {},
    }
}

export fn frame() void {
    sgfx.beginPass(.{ .action = passAction, .swapchain = sglue.swapchain() });
    sgfx.endPass();
    sgfx.commit();
}

export fn cleanup() void {
    arena.deinit();
    sgfx.shutdown();
}

export fn event() void {}

pub fn run() void {
    sapp.run(.{
        .window_title = WINDOW_TITLE,
        .width = SCREEN_WIDTH,
        .height = SCREEN_HEIGHT,
        .init_cb = init,
        .frame_cb = frame,
        .cleanup_cb = cleanup,
        .logger = .{ .func = slog.func },
    });
}
