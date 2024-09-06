//! This file contains all audio-related functions and types.
//! Required for the implementation of the basic beeper for CHIP-8

const Allocator = @import("std").mem.Allocator;
const assert    = @import("std").debug.assert;

const c = @cImport({
    @cInclude("miniaudio.h");
});

const log = @import("logger.zig");

// Constants
const DEVICE_FORMAT      = c.ma_format_f32;
const DEVICE_CHANNELS    = 2;
const DEVICE_SAMPLE_RATE = 44100;
const WAVEFORM_AMPLITUDE = 0.2;
const WAVEFORM_FREQUENCY = 200;

pub const AudioContext = struct {
    device: *c.ma_device,
    squareWave: *c.ma_waveform,
};

/// Callback function which delivers audio data to the playback device
export fn dataCallback(pDevice: ?*c.ma_device, pOutput: ?*anyopaque, pInput: ?*const anyopaque, frameCount: c.ma_uint32) void {
    assert(pDevice.?.playback.channels == DEVICE_CHANNELS);  // Panic if there is channel num mismatch

    const pSquareWave: ?*c.ma_waveform = @ptrCast(@alignCast(pDevice.?.pUserData));
    assert(pSquareWave != null);  // Panic if waveform isn't passed in properly
    _ = c.ma_waveform_read_pcm_frames(pSquareWave.?, pOutput, frameCount, null);  // Assign to _ to ignore returned value

    _ = pInput;  // Avoid unused variable error
}

pub fn createContext(allocator: Allocator) !AudioContext {
    var audioContext: AudioContext = undefined;
    var deviceConfig: c.ma_device_config = undefined;
    var squareWaveConfig: c.ma_waveform_config = undefined;

    audioContext.device = try allocator.create(c.ma_device);
    audioContext.squareWave = try allocator.create(c.ma_waveform);

    // Setup audio device
    deviceConfig = c.ma_device_config_init(c.ma_device_type_playback);
    deviceConfig.playback.format   = DEVICE_FORMAT;
    deviceConfig.playback.channels = DEVICE_CHANNELS;
    deviceConfig.sampleRate        = DEVICE_SAMPLE_RATE;
    deviceConfig.dataCallback      = dataCallback;
    deviceConfig.pUserData         = audioContext.squareWave;

    if (c.ma_device_init(null, &deviceConfig, audioContext.device) != c.MA_SUCCESS) {
        log.err("{s}", .{"Failed to open audio playback device."});
        return error.AudioSetupFail;
    }

    log.info("Audio Device Name: {s}", .{audioContext.device.playback.name});

    // Setup audio waveform
    squareWaveConfig = c.ma_waveform_config_init(audioContext.device.playback.format, audioContext.device.playback.channels, audioContext.device.sampleRate, c.ma_waveform_type_square, WAVEFORM_AMPLITUDE, WAVEFORM_FREQUENCY);
    _ = c.ma_waveform_init(&squareWaveConfig, audioContext.squareWave);

    return audioContext;
}

/// Starts/resumes audio playback
pub fn startPlayback(context: *AudioContext) !void {
    if (c.ma_device_start(context.device) != c.MA_SUCCESS) {
        log.err("{s}", .{"Failed to start audio playback device."});
        return error.AudioStartFail;
    }
}

/// Stops/pauses audio playback
pub fn stopPlayback(context: *AudioContext) !void {
    if (c.ma_device_stop(context.device) != c.MA_SUCCESS) {
        log.err("{s}", .{"Failed to stop audio playback device."});
        return error.AudioStopFail;
    }
}

pub fn destroyContext(context: *AudioContext) void {
    c.ma_device_uninit(context.device);
}
