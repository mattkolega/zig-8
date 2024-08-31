const std = @import("std");
const nfd = @import("nfd");

const opcodes = @import("instructions.zig");
const log = @import("logger.zig");
const utils = @import("utils.zig");

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

pub fn tick(context: *Chip8Context, rand: std.Random) void {
    // Fetch instruction
    const byteOne = context.memory[context.pc];
    const byteTwo = context.memory[context.pc + 1];
    const instruction = byteOne << 8 | byteTwo;
    context.pc += 2;

    // Decode and execute
    switch (utils.getFirstNibble(instruction)) {
        0x0 => switch (utils.getLastHalfInstruct(instruction)) {
            0xE0 => opcodes.op_00E0(context),
            0xEE => opcodes.op_00EE(context),
        },
        0x1 => opcodes.op_1NNN(context, instruction),
        0x2 => opcodes.op_2NNN(context, instruction),
        0x3 => opcodes.op_3XNN(context, instruction),
        0x4 => opcodes.op_4XNN(context, instruction),
        0x5 => opcodes.op_5XY0(context, instruction),
        0x6 => opcodes.op_6XNN(context, instruction),
        0x7 => opcodes.op_7XNN(context, instruction),
        0x8 => switch (utils.getFourthNibble(instruction)) {
            0x0 => opcodes.op_8XY0(context, instruction),
            0x1 => opcodes.op_8XY1(context, instruction),
            0x2 => opcodes.op_8XY2(context, instruction),
            0x3 => opcodes.op_8XY3(context, instruction),
            0x4 => opcodes.op_8XY4(context, instruction),
            0x5 => opcodes.op_8XY5(context, instruction),
            0x6 => opcodes.op_8XY6(context, instruction),
            0x7 => opcodes.op_8XY7(context, instruction),
            0xE => opcodes.op_8XYE(context, instruction),
        },
        0x9 => opcodes.op_9XY0(context, instruction),
        0xA => opcodes.op_ANNN(context, instruction),
        0xB => opcodes.op_BNNN(context, instruction),
        0xC => opcodes.op_CXNN(context, instruction, rand),
        0xD => opcodes.op_DXYN(context, instruction),
        0xE => switch (utils.getLastHalfInstruct(instruction)) {
            0x9E => opcodes.op_EX9E(context, instruction),
            0xA1 => opcodes.op_EXA1(context, instruction),
        },
        0xF => switch (utils.getThirdNibble(instruction)) {
            0x0 => switch (utils.getFourthNibble(instruction)) {
                0x7 => opcodes.op_FX07(context, instruction),
                0xA => opcodes.op_FX0A(context, instruction),
            },
            0x1 => switch(utils.getFourthNibble(instruction)) {
                0x5 => opcodes.op_FX15(context, instruction),
                0x8 => opcodes.op_FX18(context, instruction),
                0xE => opcodes.op_FX1E(context, instruction),
            },
            0x2 => opcodes.op_FX29(context, instruction),
            0x3 => opcodes.op_FX33(context, instruction),
            0x5 => opcodes.op_FX55(context, instruction),
            0x6 => opcodes.op_FX65(context, instruction),
        },
    }
}
