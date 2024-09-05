const std = @import("std");

const sokol = @import("sokol");
const slog = sokol.log;
const sgfx = sokol.gfx;
const sgl = sokol.gl;
const sapp = sokol.app;
const sglue = sokol.glue;

const emu = @import("emulator.zig");
const log = @import("logger.zig");

// Constants
const WINDOW_TITLE = "ZIG-8";
const SCREEN_SCALE_FACTOR = 20;
const SCREEN_WIDTH = 64;
const SCREEN_HEIGHT = 32;
const FPS = 60;
const CYCLES_PER_FRAME = 500 / FPS;

// Global variables
var prng: std.rand.DefaultPrng = undefined;
var rand: std.Random = undefined;

var arena: std.heap.ArenaAllocator = undefined;
var allocator: std.mem.Allocator = undefined;

var chip8Context: emu.Chip8Context = undefined;

var quitRequested = false;

var passAction: sgfx.PassAction = .{};
var framebuffer: [SCREEN_HEIGHT][SCREEN_WIDTH]u32 = undefined;
var framebufferImage: sgfx.Image = undefined;
var sampler: sgfx.Sampler = undefined;

export fn init() void {
    sgfx.setup(.{
        .environment = sglue.environment(),
        .logger = .{ .func = slog.func },
    });

    sgl.setup(.{
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
            quitRequested = true;
            return;
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
            quitRequested = true;
            return;
        },
        else => {},
    }

    // Setup image
    framebufferImage = sgfx.makeImage(.{
        .width = SCREEN_WIDTH,
        .height = SCREEN_HEIGHT,
        .pixel_format = sgfx.PixelFormat.RGBA8,
        .usage = sgfx.Usage.STREAM,
    });

    // Setup texture sampler
    sampler = sgfx.makeSampler(.{
        .min_filter = sgfx.Filter.NEAREST,
        .mag_filter = sgfx.Filter.NEAREST,
    });
}

export fn frame() void {
    if (quitRequested) return;  // Block application from running if sapp.quit() has been called

    const frameDeadline: u64 = @intCast(std.time.nanoTimestamp() + (std.time.ns_per_s / FPS));

    for (0..CYCLES_PER_FRAME) |_| {
        emu.tick(&chip8Context, rand);
    }

    if (chip8Context.delayTimer > 0) {
        chip8Context.delayTimer -= 1;
    }

    if (chip8Context.soundTimer > 0) {
        chip8Context.soundTimer -= 1;
    }

    updateFramebuffer();
    render();

    const endTime: u64 = @intCast(std.time.nanoTimestamp());

    if (frameDeadline > endTime) std.time.sleep(frameDeadline - endTime);
}

fn updateFramebuffer() void {
    for (0.., chip8Context.display) |i, row| {
        for (0.., row) |j, item| {
            if (item == true) {
                framebuffer[i][j] = 0xFFFFFFFF;
            } else {
                framebuffer[i][j] = 0xFF000000;
            }
        }
    }
}

fn render() void {
    var imgData: sgfx.ImageData = .{};
    imgData.subimage[0][0] = sgfx.asRange(&framebuffer);
    sgfx.updateImage(framebufferImage, imgData);

    sgl.defaults();

    sgl.enableTexture();
    sgl.texture(framebufferImage, sampler);

    sgl.beginQuads();
    sgl.v2fT2f(-1.0, 1.0, 0, 0);
    sgl.v2fT2f(1.0, 1.0, 1, 0);
    sgl.v2fT2f(1.0, -1.0, 1, 1);
    sgl.v2fT2f(-1.0, -1.0, 0, 1);
    sgl.end();

    sgfx.beginPass(.{ .action = passAction, .swapchain = sglue.swapchain() });
    sgl.draw();
    sgfx.endPass();
    sgfx.commit();
}

export fn cleanup() void {
    arena.deinit();
    sgl.shutdown();
    sgfx.shutdown();
}

export fn event() void {}

pub fn run() void {
    sapp.run(.{
        .window_title = WINDOW_TITLE,
        .width = SCREEN_WIDTH * SCREEN_SCALE_FACTOR,
        .height = SCREEN_HEIGHT * SCREEN_SCALE_FACTOR,
        .init_cb = init,
        .frame_cb = frame,
        .cleanup_cb = cleanup,
        .logger = .{ .func = slog.func },
    });
}
