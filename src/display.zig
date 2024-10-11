//! Functions related to display and sprites

const Chip8Context = @import("chip8.zig").Chip8Context;
const utils = @import("utils.zig");

/// Draw to screen during low-resolution (64x32) mode
/// To be used by op_DXYN
pub fn drawLowRes (context: *Chip8Context, instruction: u16) void {
    const xRegisterIndex = utils.getSecondNibble(instruction);
    const yRegisterIndex = utils.getThirdNibble(instruction);

    // Multiply sprite by 2 in lores mode
    // This is to scale 64x32 up to 128x64
    const multiplicationFactor: usize = 2;

    const xCoord = (context.v[xRegisterIndex] * multiplicationFactor) % 128;  // Make starting xCoord wrap around
    const yCoord = (context.v[yRegisterIndex] * multiplicationFactor) % 64;  // Make starting yCoord wrap around

    const spriteRows = utils.getFourthNibble(instruction) * multiplicationFactor;  // Get number of rows to draw for sprite

    context.v[0xF] = 0;  // Set VF register to 0

    var spriteAddress = context.index;

    var i: usize = 0;
    while (i < spriteRows) : (i += 2) {
        const currentYCoord = yCoord + i;  // Increment yCoord for each row
        if (currentYCoord > 63) break;

        const spriteByte = context.memory[spriteAddress];
        spriteAddress += 1;
        const spriteRow: u16 = utils.byteToDoubleByte(spriteByte);

        // Used to get each bit in the u16
        var bitmask: u16 = 0b10000000_00000000;
        var bitshiftAmount: isize = 15;

        for (0..16) |j| {
            const currentXCoord = (xCoord + j);  // Increment xCoord for each column
            if (currentXCoord > 127) break;
            const spriteBit: u16 = (spriteRow & bitmask) >> @intCast(bitshiftAmount);
            bitmask >>= 1;
            bitshiftAmount -= 1;

            if (spriteBit == 1) {
                if ((context.display[currentYCoord][currentXCoord] & context.currentBitPlane) > 0) {  // Check if display pixel is on
                    // Turn off pixel
                    context.display[currentYCoord][currentXCoord] &= ~context.currentBitPlane;
                    context.display[currentYCoord+1][currentXCoord] &= ~context.currentBitPlane;  // Also turn on pixel in next row
                    context.v[0xF] = 1;
                } else {
                    // Turn on pixel
                    context.display[currentYCoord][currentXCoord] |= context.currentBitPlane;
                    context.display[currentYCoord+1][currentXCoord] |= context.currentBitPlane;  // Also turn on pixel in next row
                }
            }
        }
    }
}

/// Draw to screen during high-resolution (128x64) mode
/// To be used by op_DXYN
pub fn drawHighRes (context: *Chip8Context, instruction: u16) void {
    const xRegisterIndex = utils.getSecondNibble(instruction);
    const yRegisterIndex = utils.getThirdNibble(instruction);

    const xCoord = context.v[xRegisterIndex] % 128;  // Make starting xCoord wrap around
    const yCoord = context.v[yRegisterIndex] % 64;  // Make starting yCoord wrap around

    const spriteRows = utils.getFourthNibble(instruction);  // Get number of rows to draw for sprite

    context.v[0xF] = 0;  // Set VF register to 0

    const spriteAddress = context.index;

    for (0..spriteRows) |i| {
        const currentYCoord = yCoord + i;  // Increment yCoord for each row
        if (currentYCoord > 63) break;

        const spriteByte = context.memory[spriteAddress + i];

        // Used to get each bit in the u8
        var bitmask: u8 = 0b10000000;
        var bitshiftAmount: isize = 7;

        for (0..8) |j| {
            const currentXCoord = xCoord + j;  // Increment xCoord for each column
            if (currentXCoord > 127) break;
            const spriteBit: u8 = (spriteByte & bitmask) >> @intCast(bitshiftAmount);
            bitmask >>= 1;
            bitshiftAmount -= 1;

            if (spriteBit == 1) {
                if ((context.display[currentYCoord][currentXCoord] & context.currentBitPlane) > 0) {  // Check if display pixel is on
                    // Turn off pixel
                    context.display[currentYCoord][currentXCoord] &= ~context.currentBitPlane;
                    context.v[0xF] = 1;
                } else {
                    // Turn on pixel
                    context.display[currentYCoord][currentXCoord] |= context.currentBitPlane;
                }
            }
        }
    }
}

/// Draws 16x16 sprite to display
/// To be used by op_DXY0
pub fn drawBigSprite(context: *Chip8Context, instruction: u16) void {
    const xRegisterIndex = utils.getSecondNibble(instruction);
    const yRegisterIndex = utils.getThirdNibble(instruction);

    const xCoord = context.v[xRegisterIndex] % 128;  // Make starting xCoord wrap around
    const yCoord = context.v[yRegisterIndex] % 64;  // Make starting yCoord wrap around

    context.v[0xF] = 0;  // Set VF register to 0

    var spriteAddress = context.index;

    for (0..16) |i| {
        const currentYCoord = yCoord + i;
        if (currentYCoord > 63) break;

        const spriteByte = @as(u16, context.memory[spriteAddress]) << 8 | context.memory[spriteAddress + 1];
        spriteAddress += 2;

        var bitmask: u16 = 0b10000000_00000000;
        var bitshiftAmount: isize = 15;

        for (0..16) |j| {
            const currentXCoord = xCoord + j;  // Increment xCoord for each column
            if (currentXCoord > 127) break;

            const spriteBit: u16 = (spriteByte & bitmask) >> @intCast(bitshiftAmount);
            bitmask >>= 1;
            bitshiftAmount -= 1;

            if (spriteBit == 1) {
                if ((context.display[currentYCoord][currentXCoord] & context.currentBitPlane) > 0) {  // Check if display pixel is turned on
                    // Turn off pixel
                    context.display[currentYCoord][currentXCoord] &= ~context.currentBitPlane;
                    context.v[0xF] = 1;
                } else {
                    // Turn on pixel
                    context.display[currentYCoord][currentXCoord] |= context.currentBitPlane;
                }
            }
        }
    }
}
