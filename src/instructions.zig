//! All opcode functions are stored here.

const std = @import("std");

const Chip8Context = @import("chip8.zig").Chip8Context;
const DisplayMode = @import("chip8.zig").DisplayMode;
const InterpreterType = @import("chip8.zig").InterpreterType;
const display = @import("display.zig");
const log = @import("logger.zig");
const utils = @import("utils.zig");


/// Scrolls screen down by N pixels
/// Only used by: SCHIP, XO-CHIP
pub fn op_00CN(context: *Chip8Context, instruction: u16) void {
    if (context.type == InterpreterType.chip8) logUnexpectedInstruct(instruction, "Can't run in CHIP-8 mode");

    // Scroll by 2n if lores mode
    const multiplicationFactor: usize = if (context.res == DisplayMode.lores) 2 else 1;
    const scrollAmount = utils.getFourthNibble(instruction) * multiplicationFactor;

    for (0..64) |i| {
        const index = 63 - i;  // Work backwards
        if ((index + scrollAmount) > 63) {
            continue;
        } else {
            for (0..128) |j| {
                context.display[index+scrollAmount][j] = (context.display[index][j] & context.currentBitPlane);
                if (index < scrollAmount) context.display[index][j] &= ~context.currentBitPlane;
            }
        }
    }
}

/// Scrolls screen up by N pixels
/// Only used by: XO-CHIP
pub fn op_00DN(context: *Chip8Context, instruction: u16) void {
    if (context.type != InterpreterType.xochip) logUnexpectedInstruct(instruction, "Can only run in XO-CHIP mode");

    // Scroll by 2n if lores mode
    const multiplicationFactor: usize = if (context.res == DisplayMode.lores) 2 else 1;
    const scrollAmount = utils.getFourthNibble(instruction) * multiplicationFactor;

    for (0..64) |i| {
        const scrollDest = @subWithOverflow(i, scrollAmount);
        if (scrollDest[1] == 1) {  // Check for overflow
            continue;
        } else {
            for (0..128) |j| {
                context.display[i-scrollAmount][j] = (context.display[i][j] & context.currentBitPlane);
                if (i > (63 - scrollAmount)) context.display[i][j] &= ~context.currentBitPlane;
            }
        }
    }
}

/// Clears the display
pub fn op_00E0(context: *Chip8Context) void {
    for (&(context.display)) |*row| {
        @memset(row, 0b00 & ~context.currentBitPlane);
    }
}

/// Returns from subroutine
pub fn op_00EE(context: *Chip8Context) void {
    context.sp -= 1;
    context.pc = context.stack[context.sp];
}

/// Scrolls screen 4 pixels to the right
/// Only used by: SCHIP, XO-CHIP
pub fn op_00FB(context: *Chip8Context, instruction: u16) void {
    if (context.type == InterpreterType.chip8) logUnexpectedInstruct(instruction, "Can't run in CHIP-8 mode");

    // Scroll by 8 pixels if lores mode
    const multiplicationFactor: usize = if (context.res == DisplayMode.lores) 2 else 1;
    const scrollAmount = 4 * multiplicationFactor;

    for (0..128) |i| {
        const index = 127 - i;  // Work backwards
        if ((index + scrollAmount) > 127) {
            continue;
        } else {
            for (0..64) |j| {
                context.display[j][index+scrollAmount] = (context.display[j][index] & context.currentBitPlane);
                if (index < scrollAmount) context.display[j][index] &= ~context.currentBitPlane;
            }
        }
    }
}

/// Scrolls screen 4 pixels to the left
/// Only used by: SCHIP, XO-CHIP
pub fn op_00FC(context: *Chip8Context, instruction: u16) void {
    if (context.type == InterpreterType.chip8) logUnexpectedInstruct(instruction, "Can't run in CHIP-8 mode");

    // Scroll by 8 pixels if lores mode
    const multiplicationFactor: usize = if (context.res == DisplayMode.lores) 2 else 1;
    const scrollAmount = 4 * multiplicationFactor;

    for (0..128) |i| {
        const scrollDest = @subWithOverflow(i, scrollAmount);
        if (scrollDest[1] == 1) {  // Check for overflow
            continue;
        } else {
            for (0..64) |j| {
                context.display[j][i-scrollAmount] = (context.display[j][i] & context.currentBitPlane);
                if (i > (127 - scrollAmount)) context.display[j][i] &= ~context.currentBitPlane;
            }
        }
    }
}

/// Exits interpreter
/// Only used by: SCHIP
pub fn op_00FD(context: *Chip8Context, instruction: u16) void {
    if (context.type != InterpreterType.schip) logUnexpectedInstruct(instruction, "Can only run in SCHIP mode");

    std.process.exit(0);  // TODO: should exit from the interpreter more elegantly
}

/// Switches display to low-res mode (64x32)
/// Only used by: SCHIP, XO-CHIP
pub fn op_00FE(context: *Chip8Context, instruction: u16) void {
    if (context.type == InterpreterType.chip8) logUnexpectedInstruct(instruction, "Can't run in CHIP-8 mode");

    if (context.type == InterpreterType.xochip) op_00E0(context);  // Clear display if in XO-CHIP mode
    context.res = DisplayMode.lores;
}

/// Switches display to hi-res mode (128x64)
/// Only used by: SCHIP, XO-CHIP
pub fn op_00FF(context: *Chip8Context, instruction: u16) void {
    if (context.type == InterpreterType.chip8) logUnexpectedInstruct(instruction, "Can't run in CHIP-8 mode");

    if (context.type == InterpreterType.xochip) op_00E0(context);  // Clear display if in XO-CHIP mode
    context.res = DisplayMode.hires;
}

/// Jumps to native subroutine at address NNN
/// Only used by: CHIP-8
pub fn op_0NNN(context: *Chip8Context, instruction: u16) void {
    if (context.type != InterpreterType.chip8) logUnexpectedInstruct(instruction, "Can only run in CHIP-8 mode");

    return;
}

/// Sets program counter to address NNN
pub fn op_1NNN(context: *Chip8Context, instruction: u16) void {
    const address = utils.getLastThreeNibbles(instruction);
    context.pc = address;
}

/// Calls subroutine
pub fn op_2NNN(context: *Chip8Context, instruction: u16) void {
    context.stack[context.sp] = context.pc;
    context.sp += 1;
    const address = utils.getLastThreeNibbles(instruction);
    context.pc = address;
}

/// Skips instruction if VX and NN are equal
pub fn op_3XNN(context: *Chip8Context, instruction: u16) void {
    const xRegisterIndex = utils.getSecondNibble(instruction);
    const value = utils.getLastHalfInstruct(instruction);

    if (context.v[xRegisterIndex] == value) {
        context.pc += 2;
    }
}

/// Skips instruction if VX and NN aren't equal
pub fn op_4XNN(context: *Chip8Context, instruction: u16) void {
    const xRegisterIndex = utils.getSecondNibble(instruction);
    const value = utils.getLastHalfInstruct(instruction);

    if (context.v[xRegisterIndex] != value) {
        context.pc += 2;
    }
}

/// Skips instruction if VX and VY are equal
pub fn op_5XY0(context: *Chip8Context, instruction: u16) void {
    const xRegisterIndex = utils.getSecondNibble(instruction);
    const yRegisterIndex = utils.getThirdNibble(instruction);

    if (context.v[xRegisterIndex] == context.v[yRegisterIndex]) {
        context.pc += 2;
    }
}

/// Saves VX - VY inclusive from memory starting at I
/// Only used by: XO-CHIP
pub fn op_5XY2(context: *Chip8Context, instruction: u16) void {
    if (context.type != InterpreterType.xochip) logUnexpectedInstruct(instruction, "Can only run in XO-CHIP mode");

    const xRegisterIndex = utils.getSecondNibble(instruction);
    const yRegisterIndex = utils.getThirdNibble(instruction);

    if (xRegisterIndex < yRegisterIndex) {
        for(xRegisterIndex..yRegisterIndex+1) |i| {
            context.memory[context.index] = context.v[i];
            context.index += 1;
        }
    } else {
        for(yRegisterIndex..xRegisterIndex+1) |i| {
            context.memory[context.index] = context.v[i];
            context.index += 1;
        }
    }
}

/// Loads VX - VY inclusive from memory starting at I
/// Only used by: XO-CHIP
pub fn op_5XY3(context: *Chip8Context, instruction: u16) void {
    if (context.type != InterpreterType.xochip) logUnexpectedInstruct(instruction, "Can only run in XO-CHIP mode");

    const xRegisterIndex = utils.getSecondNibble(instruction);
    const yRegisterIndex = utils.getThirdNibble(instruction);

    if (xRegisterIndex < yRegisterIndex) {
        for(xRegisterIndex..yRegisterIndex+1) |i| {
            context.v[i] = context.memory[context.index];
            context.index += 1;
        }
    } else {
        for(yRegisterIndex..xRegisterIndex+1) |i| {
            context.v[i] = context.memory[context.index];
            context.index += 1;
        }
    }
}

/// Sets register VX to value NN
pub fn op_6XNN(context: *Chip8Context, instruction: u16) void {
    const xRegisterIndex = utils.getSecondNibble(instruction);
    const value = utils.getLastHalfInstruct(instruction);

    context.v[xRegisterIndex] = value;
}

/// Adds value NN to the value currently in register VX
pub fn op_7XNN(context: *Chip8Context, instruction: u16) void {
    const xRegisterIndex = utils.getSecondNibble(instruction);
    const value = utils.getLastHalfInstruct(instruction);

    context.v[xRegisterIndex] +%= value;  // The +%= operator adds with overflow
}

/// Sets VX to value of VY
pub fn op_8XY0(context: *Chip8Context, instruction: u16) void {
    const xRegisterIndex = utils.getSecondNibble(instruction);
    const yRegisterIndex = utils.getThirdNibble(instruction);

    context.v[xRegisterIndex] = context.v[yRegisterIndex];
}

/// Sets VX to result of binary OR of VX and VY
pub fn op_8XY1(context: *Chip8Context, instruction: u16) void {
    const xRegisterIndex = utils.getSecondNibble(instruction);
    const yRegisterIndex = utils.getThirdNibble(instruction);

    context.v[xRegisterIndex] |= context.v[yRegisterIndex];
    if (context.type == InterpreterType.chip8) context.v[0xF] = 0;  // COSMAC CHIP-8 will reset VF
}

/// Sets VX to result of binary AND of VX and VY
pub fn op_8XY2(context: *Chip8Context, instruction: u16) void {
    const xRegisterIndex = utils.getSecondNibble(instruction);
    const yRegisterIndex = utils.getThirdNibble(instruction);

    context.v[xRegisterIndex] &= context.v[yRegisterIndex];
    if (context.type == InterpreterType.chip8) context.v[0xF] = 0;  // COSMAC CHIP-8 will reset VF
}

/// Sets VX to result of binary XOR of VX and VY
pub fn op_8XY3(context: *Chip8Context, instruction: u16) void {
    const xRegisterIndex = utils.getSecondNibble(instruction);
    const yRegisterIndex = utils.getThirdNibble(instruction);

    context.v[xRegisterIndex] ^= context.v[yRegisterIndex];
    if (context.type == InterpreterType.chip8) context.v[0xF] = 0;  // COSMAC CHIP-8 will reset VF
}

/// Sets VX to sum of VX and VY
pub fn op_8XY4(context: *Chip8Context, instruction: u16) void {
    const xRegisterIndex = utils.getSecondNibble(instruction);
    const yRegisterIndex = utils.getThirdNibble(instruction);

    const sumResult = @addWithOverflow(context.v[xRegisterIndex], context.v[yRegisterIndex]);  // Store sum result and overflow bit in tuple
    context.v[xRegisterIndex] = sumResult[0];

    if (sumResult[1] != 0) { // Test for overflow
        context.v[0xF] = 1;
    } else {
        context.v[0xF] = 0;
    }
}

/// Sets VX to VX minus VY
pub fn op_8XY5(context: *Chip8Context, instruction: u16) void {
    const xRegisterIndex = utils.getSecondNibble(instruction);
    const yRegisterIndex = utils.getThirdNibble(instruction);

    var vF: u8 = undefined;

    if (context.v[xRegisterIndex] >= context.v[yRegisterIndex]) {
        vF = 1;
    } else {
        vF = 0;
    }

    context.v[xRegisterIndex] -%= context.v[yRegisterIndex];  // The -% operator allows integer underflow
    context.v[0xF] = vF;
}

/// Sets VX to VY and shifts VX 1 bit to the right
pub fn op_8XY6(context: *Chip8Context, instruction: u16) void {
    const xRegisterIndex = utils.getSecondNibble(instruction);
    const yRegisterIndex = utils.getThirdNibble(instruction);

    if (context.type != InterpreterType.schip) context.v[xRegisterIndex] = context.v[yRegisterIndex];  // SCHIP won't set VX to VY
    const vF = (context.v[xRegisterIndex] & 0b00000001);  // Set VF to value of bit to be shifted
    context.v[xRegisterIndex] >>= 1;
    context.v[0xF] = vF;
}

/// Sets VX to VY minus VX
pub fn op_8XY7(context: *Chip8Context, instruction: u16) void {
    const xRegisterIndex = utils.getSecondNibble(instruction);
    const yRegisterIndex = utils.getThirdNibble(instruction);

    var vF: u8 = undefined;

    if (context.v[yRegisterIndex] >= context.v[xRegisterIndex]) {
        vF = 1;
    } else {
        vF = 0;
    }

    context.v[xRegisterIndex] = context.v[yRegisterIndex] -% context.v[xRegisterIndex];  // The -% operator allows integer underflow
    context.v[0xF] = vF;
}

/// Sets VX to VY and shifts VX 1 bit to the left
pub fn op_8XYE(context: *Chip8Context, instruction: u16) void {
    const xRegisterIndex = utils.getSecondNibble(instruction);
    const yRegisterIndex = utils.getThirdNibble(instruction);

    if (context.type != InterpreterType.schip) context.v[xRegisterIndex] = context.v[yRegisterIndex];  // SCHIP won't set VX to VY
    const vF = (context.v[xRegisterIndex] & 0b10000000) >> 7;  // Set VF to value of bit to be shifted
    context.v[xRegisterIndex] <<= 1;
    context.v[0xF] = vF;
}

/// Skips instruction if VX and VY aren't equal
pub fn op_9XY0(context: *Chip8Context, instruction: u16) void {
    const xRegisterIndex = utils.getSecondNibble(instruction);
    const yRegisterIndex = utils.getThirdNibble(instruction);

    if (context.v[xRegisterIndex] != context.v[yRegisterIndex]) {
        context.pc += 2;
    }
}

/// Sets index register to address NN
pub fn op_ANNN(context: *Chip8Context, instruction: u16) void {
    const address = utils.getLastThreeNibbles(instruction);
    context.index = address;
}

/// Jumps to address NNN plus value in V0
/// Only used by: CHIP-8
pub fn op_BNNN(context: *Chip8Context, instruction: u16) void {
    if (context.type == InterpreterType.schip) logUnexpectedInstruct(instruction, "Can't run in SCHIP mode");

    const address = utils.getLastThreeNibbles(instruction);
    context.pc = address + context.v[0];
}

/// Jumps to address XNN plus value in VX
/// Only used by: SCHIP
pub fn op_BXNN(context: *Chip8Context, instruction: u16) void {
    if (context.type != InterpreterType.schip) logUnexpectedInstruct(instruction, "Can only run in SCHIP mode");

    const xRegisterIndex = utils.getSecondNibble(instruction);
    const address = utils.getLastThreeNibbles(instruction);
    context.pc = address + context.v[xRegisterIndex];
}

/// Generates random number
pub fn op_CXNN(context: *Chip8Context, instruction: u16, rand: std.Random) void {
    const xRegisterIndex = utils.getSecondNibble(instruction);
    const value = utils.getLastHalfInstruct(instruction);

    const randomNum = rand.int(u8);
    const result = randomNum & value;  // binary AND randomNum with NN value

    context.v[xRegisterIndex] = result;
}

/// Draws n-width sprite to display
pub fn op_DXYN(context: *Chip8Context, instruction: u16) void {
    if (context.res == DisplayMode.lores) {
        display.drawLowRes(context, instruction);
    } else {
        display.drawHighRes(context, instruction);
    }
}

/// Draws 16x16 sprite to display
/// Only used by: SCHIP
pub fn op_DXY0(context: *Chip8Context, instruction: u16) void {
    if (context.type != InterpreterType.schip) logUnexpectedInstruct(instruction, "Can only run in SCHIP mode");
    display.drawBigSprite(context, instruction);
}

/// Skips one instruction if key equal to VX value is pressed
pub fn op_EX9E(context: *Chip8Context, instruction: u16) void {
    const xRegisterIndex = utils.getSecondNibble(instruction);
    if (context.keyState[context.v[xRegisterIndex]] == true) {
        if (utils.getNextWord(&context.memory, context.pc) == 0xF000) {
            context.pc += 4;  // Increment PC by 4 since F000 is a 4 byte opcode
        } else {
            context.pc += 2;
        }
    }
}

/// Skips one instruction if key equal to VX value is not pressed
pub fn op_EXA1(context: *Chip8Context, instruction: u16) void {
    const xRegisterIndex = utils.getSecondNibble(instruction);
    if (context.keyState[context.v[xRegisterIndex]] == false) {
        if (utils.getNextWord(&context.memory, context.pc) == 0xF000) {
            context.pc += 4;  // Increment PC by 4 since F000 is a 4 byte opcode
        } else {
            context.pc += 2;
        }
    }
}

/// Sets I to NNNN
/// Only used by: XO-CHIP
pub fn op_F000(context: *Chip8Context, instruction: u16) void {
    if (context.type != InterpreterType.xochip) logUnexpectedInstruct(instruction, "Can only run in XO-CHIP mode");

    const address = utils.getNextWord(&context.memory, context.pc);
    context.pc += 2;

    context.index = address;
}

/// Selects bit plane to draw on
/// Only used by: XO-CHIP
pub fn op_FN01(context: *Chip8Context, instruction: u16) void {
    if (context.type != InterpreterType.xochip) logUnexpectedInstruct(instruction, "Can only run in XO-CHIP mode");

    const bitPlane = utils.getSecondNibble(instruction);
    if (bitPlane > 3) {
        logErrInInstruct(instruction, "N must be >= 0 and <= 3");
        return;
    }
    context.currentBitPlane = @truncate(bitPlane);
}

/// Loads audio pattern at I into audio buffer
/// Only used by: XO-CHIP
pub fn op_F002(context: *Chip8Context, instruction: u16) void {
    _ = context;
    _ = instruction;
    return;
}

/// Sets VX to delayTimer value
pub fn op_FX07(context: *Chip8Context, instruction: u16) void {
    const xRegisterIndex = utils.getSecondNibble(instruction);
    context.v[xRegisterIndex] = context.delayTimer;
}

/// Waits for key to be pressed and adds key value to VX
pub fn op_FX0A(context: *Chip8Context, instruction: u16) void {
    const xRegisterIndex = utils.getSecondNibble(instruction);

    // First check if any keys were previously pressed and are now released
    for (0..16) |i| {
        if (context.previousKeyState[i] == true) {
            if (context.keyState[i] == false) {
                context.v[xRegisterIndex] = @intCast(i);
                @memset(&(context.previousKeyState), false);  // Clear array
                return;
            }
        }
    }

    @memset(&(context.previousKeyState), false);  // Clear array

    // If no keys were released, check for pressed keys to add to previousKeyState to be checked next cycle
    for (0..16) |i| {
        if (context.keyState[i] == true) {
            context.previousKeyState[i] = true;
        }
    }

    context.pc -= 2;  // De-increment PC to block further instruction execution
}

/// Sets delayTimer to VX value
pub fn op_FX15(context: *Chip8Context, instruction: u16) void {
    const xRegisterIndex = utils.getSecondNibble(instruction);
    context.delayTimer = context.v[xRegisterIndex];
}

/// Sets soundTimer to VX value
pub fn op_FX18(context: *Chip8Context, instruction: u16) void {
    const xRegisterIndex = utils.getSecondNibble(instruction);
    context.soundTimer = context.v[xRegisterIndex];
}

/// Adds value in VX to index register
pub fn op_FX1E(context: *Chip8Context, instruction: u16) void {
    const xRegisterIndex = utils.getSecondNibble(instruction);
    context.index += context.v[xRegisterIndex];
}

/// Sets index register to address corresponding to a small hexadecimal character
pub fn op_FX29(context: *Chip8Context, instruction: u16) void {
    const xRegisterIndex = utils.getSecondNibble(instruction);
    context.index = 0x50 + (context.v[xRegisterIndex] * 5);  // Font data begins at memory address 0x50
}

/// Sets index register to address corresponding to a large hexadecimal character
/// Only used by: SCHIP, XO-CHIP
pub fn op_FX30(context: *Chip8Context, instruction: u16) void {
    if (context.type == InterpreterType.chip8) logUnexpectedInstruct(instruction, "Can't run in CHIP-8 mode");

    const xRegisterIndex = utils.getSecondNibble(instruction);
    context.index = 0xA0 + (context.v[xRegisterIndex] * 10);  // Large font data begins at memory address 0xA0
}

/// Converts VX value to binary-coded decimal and store result at address I, I+1, I+2
pub fn op_FX33(context: *Chip8Context, instruction: u16) void {
    const xRegisterIndex = utils.getSecondNibble(instruction);

    const number = context.v[xRegisterIndex];

    var numberDigits: [3]u8 = undefined;
    numberDigits[0] = (number / 100) % 10;
    numberDigits[1] = (number / 10) % 10;
    numberDigits[2] = number % 10;

    for (0..3) |i| {
        context.memory[context.index + i] = numberDigits[i];
    }
}

/// Sets audio pitch for audio playback
/// Only used by: XO-CHIP
pub fn op_FX3A(context: *Chip8Context, instruction: u16) void {
    _ = context;
    _ = instruction;
    return;
}

/// Writes registers to memory
pub fn op_FX55(context: *Chip8Context, instruction: u16) void {
    const xRegisterIndex = utils.getSecondNibble(instruction);

    for (0..xRegisterIndex+1) |i| {
        context.memory[context.index + i] = context.v[i];
    }
    if (context.type != InterpreterType.schip) context.index += xRegisterIndex + 1;  // SCHIP won't increment index register
}

/// Loads registers from memory
pub fn op_FX65(context: *Chip8Context, instruction: u16) void {
    const xRegisterIndex = utils.getSecondNibble(instruction);

    for (0..xRegisterIndex+1) |i| {
        context.v[i] = context.memory[context.index + i];
    }
    if (context.type != InterpreterType.schip) context.index += xRegisterIndex + 1;  // SCHIP won't increment index register
}

/// Stores contents of V0 to VX into rplFlags (X <= 7)
/// Only used for: SCHIP, XO-CHIP
pub fn op_FX75(context: *Chip8Context, instruction: u16) void {
    if (context.type == InterpreterType.chip8) logUnexpectedInstruct(instruction, "Can't run in CHIP-8 mode");

    const xRegisterIndex = utils.getSecondNibble(instruction);

    if (xRegisterIndex > 7 and context.type == InterpreterType.schip) {
        logErrInInstruct(instruction, "Second nibble must be <= 7 in SCHIP mode");
        return;
    }

    for (0..xRegisterIndex+1) |i| {
        context.rplFlags[i] = context.v[i];
    }
}

/// Loads contents of rplFlags into V0 to VX (X <= 7)
/// Only used for: SCHIP, XO-CHIP
pub fn op_FX85(context: *Chip8Context, instruction: u16) void {
    if (context.type == InterpreterType.chip8) logUnexpectedInstruct(instruction, "Can't run in CHIP-8 mode");

    const xRegisterIndex = utils.getSecondNibble(instruction);

    if (xRegisterIndex > 7 and context.type == InterpreterType.schip) {
        logErrInInstruct(instruction, "Second nibble must be <= 7 in SCHIP mode");
        return;
    }

    for (0..xRegisterIndex+1) |i| {
        context.v[i] = context.rplFlags[i];
    }
}

/// Logs an error which is encountered during instruction execution
fn logErrInInstruct(instruction: u16, errMessage: []const u8) void {
    log.err("{s}: ${X:0>4} - {s}", .{"Error in instruction", instruction, errMessage});
}

/// Prints a warning when an unexpected instruction is encountered
/// i.e. SCHIP instruction is encountered when running in CHIP-8 mode
fn logUnexpectedInstruct(instruction: u16, errMessage: []const u8) void {
    log.err("{s}: ${X:0>4} - {s}", .{"Unexpected instruction", instruction, errMessage});
}
