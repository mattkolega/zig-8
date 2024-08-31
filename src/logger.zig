const std = @import("std");
const builtin = @import("builtin");

const dbg = builtin.mode == std.builtin.OptimizeMode.Debug;

/// Outputs log message to stderr
fn log(comptime prefix: []const u8, comptime fmt: []const u8, args: anytype) void {
    std.debug.assert(dbg); // Only log messages if build mode is set to debug

    std.debug.lockStdErr();
    defer std.debug.unlockStdErr();
    const stderr = std.io.getStdErr().writer();
    stderr.print(prefix ++ fmt ++ "\n", args) catch return; // Silently return from function if error occurs
}

/// Logs a message which is useful for debugging and isn't
/// relevant to the user
pub fn debug(comptime fmt: []const u8, args: anytype) void {
    log("[DEBUG]: ", fmt, args);
}

/// Logs a general message which informs the user about the
/// state of the program
pub fn info(comptime fmt: []const u8, args: anytype) void {
    log("[INFO]: ", fmt, args);
}

/// Logs a warning message which indicates that something
/// may have gone wrong but isn't necessarily an error
pub fn warn(comptime fmt: []const u8, args: anytype) void {
    log("[WARN]: ", fmt, args);
}

/// Logs an error message which indicates that something
/// has gone wrong during program execution. May or may not
/// lead to program exit.
pub fn err(comptime fmt: []const u8, args: anytype) void {
    log("[ERROR]: ", fmt, args);
}
