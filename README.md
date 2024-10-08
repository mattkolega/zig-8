# ZIG-8
A rewrite of my CHIP-8 interpreter using Zig.

In 2023, I wrote a CHIP-8 interpreter in C. I recently had another look at the code and thought it would a cool exercise to rewrite it in a different language. Zig was chosen to be used because it's fairly similar to C and I thought this project would provide a good opportunity to learn it.

**CHIP-8** (COSMAC VIP) and **SCHIP** (SUPER-CHIP 1.1) behaviours are implemented.

Sokol is used for graphics and input, and miniaudio is used for audio.

## Build
Requires version 0.13 of the Zig compiler. Tested on macOS, but it should work on any OS supported by Zig.

```bash
# Clone the repo along with submodules
git clone --recursive https://github.com/mattkolega/zig-8.git

# Navigate to the repo directory
cd zig-8

# Build and run executable
# The executable will be located in the zig-out folder
zig build run
```

## Usage
Either run `zig build run` at the root directory, or navigate to the output directory (default is *zig-out*) and run `./zig-8`.

Launching the interpreter will open a file dialog to load `.ch8` ROM files.

### Program Arguments
Command line arguments can optionally be given to the interpreter to alter its execution.

```
-h, --help
        Display this help message and exit.

-c, --cycles <usize>
        Set the number of cycles per second for the interpreter.

-m, --machine <str>
        Set the interpreter type. Possible values: chip8 | schip
```

### Controls
Original CHIP-8 computers supported hexadecimal keypads for input. This emulator maps those keys to the left side of a QWERTY keyboard.
The keys needed to be pressed during execution depend on the ROM file.

```
1 2 3 C      1 2 3 4
4 5 6 D  ->  Q W E R
7 8 9 E      A S D F
A 0 B F      Z X C V
```

## Acknowledgements
- [Tobias V. Langhoff](https://tobiasvl.github.io/blog/write-a-chip-8-emulator/) for his overview and guide on implementing a CHIP-8 interpreter.
- [Timendus](https://github.com/Timendus/chip8-test-suite) for his test ROM collection, which greatly helped with getting all the opcodes working properly.
- [Gulrak's CHIP-8 Variant Opcode Table](https://chip8.gulrak.net/) for aiding with identifying quirks associated with different CHIP-8 implementations.
- [CHIP-8 Extensions](https://chip-8.github.io/extensions/) for providing valuable insight into the different CHIP-8 extension variations.
- John Earnest's [Octo](https://johnearnest.github.io/Octo/) IDE for serving as a reference which I could compare my interpreter's behaviour to.

## Licence
[MIT](LICENSE)