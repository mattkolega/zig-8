const std = @import("std");
const nfd = @import("nfd");

const log = @import("logger.zig");

pub const Chip8Context = struct {
    memory: [4096]u8,            // 4KB of RAM
    display: [32][64]bool,       // Display is 64 pixels wide and 32 pixels high
    stack: [16]u16,
    sp: u8,                      // Stack pointer - points to first available stack location
    pc: u16 = 512,               // Program counter
    index: u16,                  // Index register
    delayTimer: u8,
    soundTimer: u8,
    v: [16]u8,                   // Variable registers
    keyState: [16]bool,          // Tracks whether keys corresponding to hex chars are pressed or not
    previousKeyState: [16]bool,  // Used to track key press and release for FX0A
};

/// Creates a CHIP-8 context struct to store emulator state
pub fn createContext(allocator: std.mem.Allocator) !Chip8Context {
    var context: Chip8Context = std.mem.zeroInit(Chip8Context, .{});
    try loadRom(&context, allocator);
    loadFontData(&context);

    return context;
}

/// Reads .ch8 ROM file and loads contents into memory
fn loadRom(context: *Chip8Context, allocator: std.mem.Allocator) !void {
    const filePath = try nfd.openFileDialog("ch8", null);

    if (filePath) |path| {
        defer nfd.freePath(path);

        const file = try std.fs.openFileAbsolute(path, .{});
        defer file.close();

        var buffered = std.io.bufferedReader(file.reader());
        var reader = buffered.reader();

        const bytes = reader.readAllAlloc(allocator, 4096) catch |err| switch (err) {
            error.StreamTooLong => {
                log.err("{s}", .{"ROM filesize is too large to fit in CHIP-8 memory."});
                return error.FileTooBig;
            },
            else => return err,
        };

        for (0.., bytes) |i, elem| {
            context.memory[512 + i] = elem;
        }
    } else {
        log.info("{s}", .{"File dialog was closed by user. Exiting program."});
        return error.FileOpenCancel;
    }
}

/// Loads font sprites in memory locations 0x50 to 0x9F
fn loadFontData(context: *Chip8Context) void {
    const fontData = [80]u8{
        0xF0, 0x90, 0x90, 0x90, 0xF0, // 0
        0x20, 0x60, 0x20, 0x20, 0x70, // 1
        0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2
        0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3
        0x90, 0x90, 0xF0, 0x10, 0x10, // 4
        0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5
        0xF0, 0x80, 0xF0, 0x90, 0xF0, // 6
        0xF0, 0x10, 0x20, 0x40, 0x40, // 7
        0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
        0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
        0xF0, 0x90, 0xF0, 0x90, 0x90, // A
        0xE0, 0x90, 0xE0, 0x90, 0xE0, // B
        0xF0, 0x80, 0x80, 0x80, 0xF0, // C
        0xE0, 0x90, 0x90, 0x90, 0xE0, // D
        0xF0, 0x80, 0xF0, 0x80, 0xF0, // E
        0xF0, 0x80, 0xF0, 0x80, 0x80, // F
    };

    for (0.., fontData) |i, elem| {
        context.memory[0x050 + i] = elem;
    }
}

// pub fn tick(context: *Chip8Context) void {}
