// Instruction Decode Helpers
// A 'nibble' is a half-byte (4 bits) component of an instruction

/// Gets first 4 bits of an instruction
pub fn getFirstNibble(instruction: u16) u8 {
   return @truncate((instruction >> 12) & 0x0F);
}

/// Gets second 4 bits of an instruction
pub fn getSecondNibble(instruction: u16) u8 {
    return @truncate((instruction >> 8) & 0x0F);
}

/// Gets third 4 bits of an instruction
pub fn getThirdNibble(instruction: u16) u8 {
    return @truncate((instruction >> 4) & 0x0F);
}

/// Gets last 4 bits of an instruction
pub fn getFourthNibble(instruction: u16) u8 {
    return @truncate(instruction & 0x000F);
}

/// Gets last 8 bits of an instruction
pub fn getLastHalfInstruct(instruction: u16) u8 {
    return @truncate(instruction & 0x00FF);
}

/// Gets last 12 bits of an instruction
pub fn getLastThreeNibbles(instruction: u16) u16 {
    return instruction & 0x0FFF;
}
