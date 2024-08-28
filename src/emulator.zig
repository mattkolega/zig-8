const Chip8Context = struct {
    memory: [4096]u8,
    display: [32][64]bool,
    stack: [16]u16,
    sp: u8,
    pc: u16,
    index: u16,
    delayTimer: u8,
    soundTimer: u8,
    v: [16]u8,
    keyState: [16]bool,
    previousKeyState: [16]bool,
};

pub fn init(context: *Chip8Context) void {}

fn loadRom(context: *Chip8Context) void {}

fn loadFontData(context: *Chip8Context) void {}

pub fn tick(context: *Chip8Context) void {}
