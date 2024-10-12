const std = @import("std");

const nfd = @import("nfd");

const opcodes = @import("instructions.zig");
const log = @import("logger.zig");
const utils = @import("utils.zig");

pub const InterpreterType = enum {
    chip8,   // CHIP-8
    schip,   // SUPER-CHIP 1.1
    xochip,  // XO-CHIP
};

pub const DisplayMode = enum {
    lores,  // 64x32
    hires,  // 128x64
};

pub const Chip8Context = struct {
    type: InterpreterType,                 // Variant which is being emulated
    memory: [4096]u8,                      // 4KB of RAM
    display: [64][128]u2,                  // Display is 128 pixels wide and 64 pixels high
    currentBitPlane: u2 = 0b11,
    res: DisplayMode = DisplayMode.lores,  // Dictates what resolution to render at. Doesn't change in CHIP-8 mode
    stack: [16]u16,
    sp: u8,                                // Stack pointer - points to first available stack location
    pc: u16 = 512,                         // Program counter
    index: u16,                            // Index register
    delayTimer: u8,
    soundTimer: u8,
    v: [16]u8,                             // Variable registers
    keyState: [16]bool,                    // Tracks whether keys corresponding to hex chars are pressed or not
    previousKeyState: [16]bool,            // Used to track key press and release for FX0A
    rplFlags: [16]u8,                      // RPL user flags found in HP-48. Not used in CHIP-8 mode
};

/// Creates a CHIP-8 context struct to store emulator state
pub fn createContext(interpreter: InterpreterType, allocator: std.mem.Allocator) !Chip8Context {
    var context: Chip8Context = std.mem.zeroInit(Chip8Context, .{ .type = interpreter });
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

/// Loads font sprites into memory
/// Will also load large font sprites if interpreter type is set to a value other than chip8
fn loadFontData(context: *Chip8Context) void {
    const fontData = [80]u8{
        0xF0, 0x90, 0x90, 0x90, 0xF0,  // 0
        0x20, 0x60, 0x20, 0x20, 0x70,  // 1
        0xF0, 0x10, 0xF0, 0x80, 0xF0,  // 2
        0xF0, 0x10, 0xF0, 0x10, 0xF0,  // 3
        0x90, 0x90, 0xF0, 0x10, 0x10,  // 4
        0xF0, 0x80, 0xF0, 0x10, 0xF0,  // 5
        0xF0, 0x80, 0xF0, 0x90, 0xF0,  // 6
        0xF0, 0x10, 0x20, 0x40, 0x40,  // 7
        0xF0, 0x90, 0xF0, 0x90, 0xF0,  // 8
        0xF0, 0x90, 0xF0, 0x10, 0xF0,  // 9
        0xF0, 0x90, 0xF0, 0x90, 0x90,  // A
        0xE0, 0x90, 0xE0, 0x90, 0xE0,  // B
        0xF0, 0x80, 0x80, 0x80, 0xF0,  // C
        0xE0, 0x90, 0x90, 0x90, 0xE0,  // D
        0xF0, 0x80, 0xF0, 0x80, 0xF0,  // E
        0xF0, 0x80, 0xF0, 0x80, 0x80,  // F
    };

    var fontIndex: usize = 0x050;  // Font data is loaded at address 0x050

    for (fontData) |elem| {
        context.memory[fontIndex] = elem;
        fontIndex += 1;
    }

    if (context.type == InterpreterType.chip8) return;  // Finish loading font data for CHIP-8

    // Proceed to load large font sprites if interpreter type is anything other than CHIP-8
    const largeFontData = [100]u8 {
        0x3C, 0x7E, 0xE7, 0xC3, 0xC3, 0xC3, 0xC3, 0xE7, 0x7E, 0x3C,  // 0
        0x18, 0x38, 0x58, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x3C,  // 1
        0x3E, 0x7F, 0xC3, 0x06, 0x0C, 0x18, 0x30, 0x60, 0xFF, 0xFF,  // 2
        0x3C, 0x7E, 0xC3, 0x03, 0x0E, 0x0E, 0x03, 0xC3, 0x7E, 0x3C,  // 3
        0x06, 0x0E, 0x1E, 0x36, 0x66, 0xC6, 0xFF, 0xFF, 0x06, 0x06,  // 4
        0xFF, 0xFF, 0xC0, 0xC0, 0xFC, 0xFE, 0x03, 0xC3, 0x7E, 0x3C,  // 5
        0x3E, 0x7C, 0xE0, 0xC0, 0xFC, 0xFE, 0xC3, 0xC3, 0x7E, 0x3C,  // 6
        0xFF, 0xFF, 0x03, 0x06, 0x0C, 0x18, 0x30, 0x60, 0x60, 0x60,  // 7
        0x3C, 0x7E, 0xC3, 0xC3, 0x7E, 0x7E, 0xC3, 0xC3, 0x7E, 0x3C,  // 8
        0x3C, 0x7E, 0xC3, 0xC3, 0x7F, 0x3F, 0x03, 0x03, 0x3E, 0x7C,  // 9
    };

    for (largeFontData) |elem| {
        context.memory[fontIndex] = elem;
        fontIndex += 1;
    }
}

pub fn tick(context: *Chip8Context, rand: std.Random) void {
    // Fetch instruction
    const instruction = utils.getNextWord(&context.memory, context.pc);
    context.pc += 2;

    // Decode and execute
    switch (utils.getFirstNibble(instruction)) {
        0x0 => switch (utils.getThirdNibble(instruction)) {
            0xC  => opcodes.op_00CN(context, instruction),
            0xD  => opcodes.op_00DN(context, instruction),
            0xE  => switch (utils.getFourthNibble(instruction)) {
                0x0  => opcodes.op_00E0(context),
                0xE  => opcodes.op_00EE(context),
                else => logUnknownInstruct(instruction),
            },
            0xF  => switch (utils.getFourthNibble(instruction)) {
                0xB  => opcodes.op_00FB(context, instruction),
                0xC  => opcodes.op_00FC(context, instruction),
                0xD  => opcodes.op_00FD(context, instruction),
                0xE  => opcodes.op_00FE(context, instruction),
                0xF  => opcodes.op_00FF(context, instruction),
                else => logUnknownInstruct(instruction)
            },
            else => opcodes.op_0NNN(context, instruction),
        },
        0x1 => opcodes.op_1NNN(context, instruction),
        0x2 => opcodes.op_2NNN(context, instruction),
        0x3 => opcodes.op_3XNN(context, instruction),
        0x4 => opcodes.op_4XNN(context, instruction),
        0x5 => opcodes.op_5XY0(context, instruction),
        0x6 => opcodes.op_6XNN(context, instruction),
        0x7 => opcodes.op_7XNN(context, instruction),
        0x8 => switch (utils.getFourthNibble(instruction)) {
            0x0  => opcodes.op_8XY0(context, instruction),
            0x1  => opcodes.op_8XY1(context, instruction),
            0x2  => opcodes.op_8XY2(context, instruction),
            0x3  => opcodes.op_8XY3(context, instruction),
            0x4  => opcodes.op_8XY4(context, instruction),
            0x5  => opcodes.op_8XY5(context, instruction),
            0x6  => opcodes.op_8XY6(context, instruction),
            0x7  => opcodes.op_8XY7(context, instruction),
            0xE  => opcodes.op_8XYE(context, instruction),
            else => logUnknownInstruct(instruction),
        },
        0x9 => opcodes.op_9XY0(context, instruction),
        0xA => opcodes.op_ANNN(context, instruction),
        0xB => if (context.type == InterpreterType.schip) {
            opcodes.op_BXNN(context, instruction);
        } else {
            opcodes.op_BNNN(context, instruction);
        },
        0xC => opcodes.op_CXNN(context, instruction, rand),
        0xD => switch (utils.getFourthNibble(instruction)) {
            0x0  => opcodes.op_DXY0(context, instruction),
            else => opcodes.op_DXYN(context, instruction),
        },
        0xE => switch (utils.getLastHalfInstruct(instruction)) {
            0x9E => opcodes.op_EX9E(context, instruction),
            0xA1 => opcodes.op_EXA1(context, instruction),
            else => logUnknownInstruct(instruction),
        },
        0xF => switch (utils.getThirdNibble(instruction)) {
            0x0  => switch (utils.getFourthNibble(instruction)) {
                0x0  => opcodes.op_F000(context),
                0x7  => opcodes.op_FX07(context, instruction),
                0xA  => opcodes.op_FX0A(context, instruction),
                else => logUnknownInstruct(instruction),
            },
            0x1  => switch(utils.getFourthNibble(instruction)) {
                0x5  => opcodes.op_FX15(context, instruction),
                0x8  => opcodes.op_FX18(context, instruction),
                0xE  => opcodes.op_FX1E(context, instruction),
                else => logUnknownInstruct(instruction),
            },
            0x2  => opcodes.op_FX29(context, instruction),
            0x3  => switch (utils.getFourthNibble(instruction)) {
                0x0  => opcodes.op_FX30(context, instruction),
                0x3  => opcodes.op_FX33(context, instruction),
                else => logUnknownInstruct(instruction)
            },
            0x5  => opcodes.op_FX55(context, instruction),
            0x6  => opcodes.op_FX65(context, instruction),
            0x7  => opcodes.op_FX75(context, instruction),
            0x8  => opcodes.op_FX85(context, instruction),
            else => logUnknownInstruct(instruction),
        },
        else => logUnknownInstruct(instruction),
    }
}

/// Used to print a warning when an unknown instruction is encountered
fn logUnknownInstruct(instruction: u16) void {
    log.warn("{s}: ${X:0>4}", .{"Encountered unknown instruction", instruction});
}
