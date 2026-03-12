const std = @import("std");
const rl = @import("raylib");
const audio = @import("audio.zig");
const common = @import("common.zig");
const game_mod = @import("game.zig");
const angle_runtime = @import("angle_runtime.zig");
const renderer_mod = @import("renderer.zig");
const windowing = @import("windowing.zig");

pub fn main() !void {
    try angle_runtime.ensureReady();
    windowing.initWindow();
    defer rl.closeWindow();

    const screen_w = rl.getScreenWidth();
    const screen_h = rl.getScreenHeight();
    var renderer = try renderer_mod.Renderer.init(screen_w, screen_h);
    defer renderer.deinit();

    var audioBank = try audio.AudioBank.init(std.heap.c_allocator);
    defer audioBank.deinit();

    const seed = @as(u64, @intCast(std.time.nanoTimestamp()));
    var game = game_mod.Game.init(seed);
    var accumulator: f32 = 0.0;

    while (!rl.windowShouldClose()) {
        if (rl.isKeyPressed(.escape)) break;

        tickGame(&game, &audioBank, &accumulator);
        renderer.drawFrame(&game);
    }
}

fn tickGame(game: *game_mod.Game, audio_bank: *audio.AudioBank, accumulator: *f32) void {
    var frame_dt = rl.getFrameTime();

    // clamp to prevent a huge lag spike from causing the simulation to jump forward too far
    if (frame_dt > 0.1) frame_dt = 0.1;

    // accumulate time until there is enough to run a simulation step
    accumulator.* += frame_dt;

    while (accumulator.* >= common.fixed_dt) {
        game.update(common.fixed_dt, audio_bank);
        accumulator.* -= common.fixed_dt;
    }
}
