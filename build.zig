const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const depSokol = b.dependency("sokol", .{
        .target = target,
        .optimize = optimize,
    });

    const depNfd = b.dependency("nfd", .{
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "zig-8",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("sokol", depSokol.module("sokol"));
    exe.root_module.addImport("nfd", depNfd.module("nfd"));

    const cDebugFlags = [_][]const u8{};
    const cReleaseFlags = [_][]const u8{"-g", "-O2"};
    const flags = if (optimize == .Debug) &cDebugFlags else &cReleaseFlags;

    exe.addIncludePath(b.path("lib/miniaudio"));
    exe.addCSourceFile(.{
        .file = b.path("lib/miniaudio_impl.c"),
        .flags = flags,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| { // Allow for program args when running using `zig build run` command
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
