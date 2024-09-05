//! All opcode functions are stored here.

const std = @import("std");
const Chip8Context = @import("emulator.zig").Chip8Context;
const utils = @import("utils.zig");


/// Clears the display
pub fn op_00E0(context: *Chip8Context) void {
    for (&(context.display)) |*row| {
        @memset(row, false);
    }
}

/// Returns from subroutine
pub fn op_00EE(context: *Chip8Context) void {
    context.sp -= 1;
    context.pc = context.stack[context.sp];
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
    context.v[0xF] = 0;
}

/// Sets VX to result of binary AND of VX and VY
pub fn op_8XY2(context: *Chip8Context, instruction: u16) void {
    const xRegisterIndex = utils.getSecondNibble(instruction);
    const yRegisterIndex = utils.getThirdNibble(instruction);

    context.v[xRegisterIndex] &= context.v[yRegisterIndex];
    context.v[0xF] = 0;
}

/// Sets VX to result of binary XOR of VX and VY
pub fn op_8XY3(context: *Chip8Context, instruction: u16) void {
    const xRegisterIndex = utils.getSecondNibble(instruction);
    const yRegisterIndex = utils.getThirdNibble(instruction);

    context.v[xRegisterIndex] ^= context.v[yRegisterIndex];
    context.v[0xF] = 0;
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

    context.v[xRegisterIndex] = context.v[yRegisterIndex];
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

    context.v[xRegisterIndex] = context.v[yRegisterIndex];
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
pub fn op_BNNN(context: *Chip8Context, instruction: u16) void {
    const address = utils.getLastThreeNibbles(instruction);
    context.pc = address + context.v[0];
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
    const xRegisterIndex = utils.getSecondNibble(instruction);
    const yRegisterIndex = utils.getThirdNibble(instruction);

    const xCoord = context.v[xRegisterIndex] % 64;  // Make starting xCoord wrap around
    const yCoord = context.v[yRegisterIndex] % 32;  // Make starting yCoord wrap around

    const spriteRows = utils.getFourthNibble(instruction);  // Get number of rows to draw for sprite

    context.v[0xF] = 0;  // Set VF register to 0

    for (0..spriteRows) |n| {
        const currentYCoord = yCoord + n;  // Increment yCoord for each row
        if (currentYCoord > 31) break;
        const spriteByte = context.memory[context.index + n];
        var bitmask: u8 = 0b10000000;
        var bitshiftAmount: usize = 7;

        for (0..8) |i| {
            const currentXCoord = xCoord + i;  // Increment xCoord for each column
            if (currentXCoord > 63) break;
            const spriteBit: u8 = (spriteByte & bitmask) >> @intCast(bitshiftAmount);
            bitmask >>= 1;
            if (bitshiftAmount >= 1) bitshiftAmount -= 1;  // Avoid overflow by only decrementing when 1 or above

            if (spriteBit ^ @intFromBool(context.display[currentYCoord][currentXCoord]) == 1) {  // Binary XOR to check if pixel should be on
                context.display[currentYCoord][currentXCoord] = true;
            } else if (spriteBit & @intFromBool(context.display[currentYCoord][currentXCoord]) == 1) {  // Binary AND to check if pixel should be off
                context.display[currentYCoord][currentXCoord] = false;
                context.v[0xF] = 1;
            }
        }
    }
}

/// Skips one instruction if key equal to VX value is pressed
pub fn op_EX9E(context: *Chip8Context, instruction: u16) void {
    const xRegisterIndex = utils.getSecondNibble(instruction);
    if (context.keyState[context.v[xRegisterIndex]] == true) {
        context.pc += 2;
    }
}

/// Skips one instruction if key equal to VX value is not pressed
pub fn op_EXA1(context: *Chip8Context, instruction: u16) void {
    const xRegisterIndex = utils.getSecondNibble(instruction);
    if (context.keyState[context.v[xRegisterIndex]] == false) {
        context.pc += 2;
    }
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

/// Sets index register to address corresponding to a hexadecimal character
pub fn op_FX29(context: *Chip8Context, instruction: u16) void {
    const xRegisterIndex = utils.getSecondNibble(instruction);
    context.index = 0x50 + (context.v[xRegisterIndex] * 5);  // Font data begins at memory address 0x50
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

/// Writes registers to memory
pub fn op_FX55(context: *Chip8Context, instruction: u16) void {
    const xRegisterIndex = utils.getSecondNibble(instruction);

    for (0..xRegisterIndex+1) |i| {
        context.memory[context.index + i] = context.v[i];
    }
    context.index += xRegisterIndex + 1;
}

/// Loads registers from memory
pub fn op_FX65(context: *Chip8Context, instruction: u16) void {
    const xRegisterIndex = utils.getSecondNibble(instruction);

    for (0..xRegisterIndex+1) |i| {
        context.v[i] = context.memory[context.index + i];
    }
    context.index += xRegisterIndex + 1;
}
