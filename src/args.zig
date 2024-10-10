//! A very basic command-line argument parser
//! Allows for basic configuration of the interpreter

const std = @import("std");

const clap = @import("clap");

const Parameters = @import("application.zig").Parameters;
const InterpreterType = @import("chip8.zig").InterpreterType;
const log = @import("logger.zig");

/// Processes command-line arguments
pub fn processArgs(allocator: std.mem.Allocator) !Parameters {
    const params = comptime clap.parseParamsComptime(
        \\-h, --help            Display this help message and exit.
        \\-c, --cycles <usize>  Set the number of cycles per second for the interpreter.
        \\-m, --machine <str>   Set the interpreter type.
        \\                      Possible values: chip8 | schip | xochip
    );

    // Setup parser
    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, clap.parsers.default, .{
        .diagnostic = &diag,
        .allocator = allocator,
    }) catch |err| {
        reportError(&diag, err) catch {};
        return err;
    };
    defer res.deinit();

    // Print help message if help arg is present
    if (res.args.help != 0) {
        try clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
        std.process.exit(0);
    }

    var interpreterParams = std.mem.zeroInit(Parameters, .{});

    if (res.args.cycles) |arg| {
        interpreterParams.cyclesPerSecond = arg;
    }
    if (res.args.machine) |arg| {
        interpreterParams.machineType = std.meta.stringToEnum(InterpreterType, arg) orelse {
            log.err("{s}", .{"Unknown machine type given as program argument. Use -h or --help to check valid arguments."});
            return error.InvalidMachineType;
        };
    }

    return interpreterParams;
}

/// Rewrite of default reporting function using custom logging
fn reportError(diag: *clap.Diagnostic, err: anyerror) !void {
    var longest = diag.name.longest();
        if (longest.kind == .positional)
            longest.name = diag.arg;

    switch (err) {
        clap.streaming.Error.DoesntTakeValue => log.err(
            "The argument '{s}{s}' does not take a value",
            .{ longest.kind.prefix(), longest.name },
        ),
        clap.streaming.Error.MissingValue => log.err(
            "The argument '{s}{s}' requires a value but none was supplied",
            .{ longest.kind.prefix(), longest.name },
        ),
        clap.streaming.Error.InvalidArgument => log.err(
            "Invalid argument '{s}{s}'",
            .{ longest.kind.prefix(), longest.name },
        ),
        else => log.err("Error while parsing arguments: {s}", .{@errorName(err)}),
    }
}
