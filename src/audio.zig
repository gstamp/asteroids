const std = @import("std");
const rl = @import("raylib");
const common = @import("common.zig");

const sample_rate = common.sample_rate;

const SoundPool = struct {
    allocator: std.mem.Allocator,
    buffers: [4][]i16,
    sounds: [4]rl.Sound,
    next: usize,

    fn init(
        allocator: std.mem.Allocator,
        seconds: f32,
        generator: *const fn ([]i16, f32, usize) void,
    ) !SoundPool {
        var pool: SoundPool = undefined;
        pool.allocator = allocator;
        pool.next = 0;

        const frame_count = @as(usize, @intFromFloat(seconds * @as(f32, @floatFromInt(sample_rate))));
        for (0..pool.buffers.len) |i| {
            const samples = try allocator.alloc(i16, frame_count);
            generator(samples, @as(f32, @floatFromInt(sample_rate)), i);
            const wave = rl.Wave{
                .frameCount = @as(c_uint, @intCast(frame_count)),
                .sampleRate = @as(c_uint, sample_rate),
                .sampleSize = 16,
                .channels = 1,
                .data = @ptrCast(samples.ptr),
            };
            pool.buffers[i] = samples;
            pool.sounds[i] = rl.loadSoundFromWave(wave);
        }
        return pool;
    }

    fn deinit(self: *SoundPool) void {
        for (0..self.sounds.len) |i| {
            self.sounds[i].unload();
            self.allocator.free(self.buffers[i]);
        }
    }

    fn play(self: *SoundPool, volume: f32, pitch: f32) void {
        const index = self.next;
        self.next = (self.next + 1) % self.sounds.len;
        rl.setSoundVolume(self.sounds[index], volume);
        rl.setSoundPitch(self.sounds[index], pitch);
        rl.playSound(self.sounds[index]);
    }
};

pub const AudioBank = struct {
    shoot: SoundPool,
    thrust: SoundPool,
    bang_large: SoundPool,
    bang_medium: SoundPool,
    bang_small: SoundPool,
    beat_high: SoundPool,
    beat_low: SoundPool,
    saucer_fire: SoundPool,
    saucer_hum: SoundPool,
    death: SoundPool,
    hyperspace: SoundPool,
    extra_life: SoundPool,
    powerup: SoundPool,

    pub fn init(allocator: std.mem.Allocator) !AudioBank {
        rl.initAudioDevice();
        rl.setMasterVolume(0.9);

        return .{
            .shoot = try SoundPool.init(allocator, 0.12, synthShoot),
            .thrust = try SoundPool.init(allocator, 0.17, synthThrust),
            .bang_large = try SoundPool.init(allocator, 0.58, synthBangLarge),
            .bang_medium = try SoundPool.init(allocator, 0.42, synthBangMedium),
            .bang_small = try SoundPool.init(allocator, 0.26, synthBangSmall),
            .beat_high = try SoundPool.init(allocator, 0.14, synthBeatHigh),
            .beat_low = try SoundPool.init(allocator, 0.16, synthBeatLow),
            .saucer_fire = try SoundPool.init(allocator, 0.20, synthSaucerFire),
            .saucer_hum = try SoundPool.init(allocator, 0.24, synthSaucerHum),
            .death = try SoundPool.init(allocator, 0.75, synthDeath),
            .hyperspace = try SoundPool.init(allocator, 0.36, synthHyperspace),
            .extra_life = try SoundPool.init(allocator, 0.35, synthExtraLife),
            .powerup = try SoundPool.init(allocator, 0.32, synthPowerup),
        };
    }

    pub fn deinit(self: *AudioBank) void {
        self.shoot.deinit();
        self.thrust.deinit();
        self.bang_large.deinit();
        self.bang_medium.deinit();
        self.bang_small.deinit();
        self.beat_high.deinit();
        self.beat_low.deinit();
        self.saucer_fire.deinit();
        self.saucer_hum.deinit();
        self.death.deinit();
        self.hyperspace.deinit();
        self.extra_life.deinit();
        self.powerup.deinit();
        rl.closeAudioDevice();
    }
};

pub fn playShoot(self: *AudioBank, volume: f32, pitch: f32) void {
    self.shoot.play(volume, pitch);
}

pub fn playThrust(self: *AudioBank, volume: f32, pitch: f32) void {
    self.thrust.play(volume, pitch);
}

pub fn playBangLarge(self: *AudioBank, volume: f32, pitch: f32) void {
    self.bang_large.play(volume, pitch);
}

pub fn playBangMedium(self: *AudioBank, volume: f32, pitch: f32) void {
    self.bang_medium.play(volume, pitch);
}

pub fn playBangSmall(self: *AudioBank, volume: f32, pitch: f32) void {
    self.bang_small.play(volume, pitch);
}

pub fn playBeatHigh(self: *AudioBank, volume: f32, pitch: f32) void {
    self.beat_high.play(volume, pitch);
}

pub fn playBeatLow(self: *AudioBank, volume: f32, pitch: f32) void {
    self.beat_low.play(volume, pitch);
}

pub fn playSaucerFire(self: *AudioBank, volume: f32, pitch: f32) void {
    self.saucer_fire.play(volume, pitch);
}

pub fn playSaucerHum(self: *AudioBank, volume: f32, pitch: f32) void {
    self.saucer_hum.play(volume, pitch);
}

pub fn playDeath(self: *AudioBank, volume: f32, pitch: f32) void {
    self.death.play(volume, pitch);
}

pub fn playHyperspace(self: *AudioBank, volume: f32, pitch: f32) void {
    self.hyperspace.play(volume, pitch);
}

pub fn playExtraLife(self: *AudioBank, volume: f32, pitch: f32) void {
    self.extra_life.play(volume, pitch);
}

pub fn playPowerup(self: *AudioBank, volume: f32, pitch: f32) void {
    self.powerup.play(volume, pitch);
}

fn synthShoot(samples: []i16, sr: f32, variant: usize) void {
    var phase: f32 = 0.0;
    for (samples, 0..) |*sample, i| {
        const t = @as(f32, @floatFromInt(i)) / sr;
        const freq = common.lerp(980.0 + @as(f32, @floatFromInt(variant)) * 40.0, 260.0, t / 0.12);
        phase += freq / sr;
        const env = std.math.exp(-t * 22.0);
        const tone = common.triangleSample(phase) * 0.8 + @sin(phase * common.tau * 0.5) * 0.18;
        common.writeSynthSample(sample, tone * env * 0.48);
    }
}

fn synthThrust(samples: []i16, sr: f32, variant: usize) void {
    const variant_f = @as(f32, @floatFromInt(variant));
    var sub_phase: f32 = 0.0;
    var body_phase: f32 = 0.0;
    var grit_phase: f32 = 0.0;
    var filtered_noise: f32 = 0.0;
    for (samples, 0..) |*sample, i| {
        const t = @as(f32, @floatFromInt(i)) / sr;
        const sweep = 1.0 - std.math.clamp(t / 0.17, 0.0, 1.0);
        const base = 64.0 + variant_f * 3.5 + @sin(t * 8.0 + variant_f) * 5.0;
        sub_phase += (base - sweep * 10.0) / sr;
        body_phase += (base * 1.85 + @sin(t * 23.0) * 6.0) / sr;
        grit_phase += (base * 3.7 + 18.0) / sr;

        const attack = std.math.clamp(t / 0.012, 0.0, 1.0);
        const decay = 0.22 + sweep * 0.78;
        const pulse = 0.84 + 0.16 * @sin(t * 15.0 + variant_f * 0.9);
        const raw_noise = common.hashNoise(i * 5, variant);
        filtered_noise += (raw_noise - filtered_noise) * 0.12;

        const sub = @sin(sub_phase * common.tau) * 0.55;
        const body = common.triangleSample(body_phase) * 0.24;
        const growl = @sin(grit_phase * common.tau) * 0.12;
        const exhaust = filtered_noise * (0.16 + sweep * 0.12);
        const flutter = @sin(t * 34.0 + variant_f * 0.7) * 0.05;
        const tone = (sub + body + growl + exhaust) * pulse + flutter;

        common.writeSynthSample(sample, tone * attack * decay * 0.46);
    }
}

fn synthBangLarge(samples: []i16, sr: f32, variant: usize) void {
    var phase: f32 = 0.0;
    for (samples, 0..) |*sample, i| {
        const t = @as(f32, @floatFromInt(i)) / sr;
        const freq = common.lerp(110.0 + @as(f32, @floatFromInt(variant)) * 8.0, 38.0, t / 0.58);
        phase += freq / sr;
        const env = std.math.exp(-t * 5.2);
        const boom = @sin(phase * common.tau) * 0.55;
        const crackle = common.hashNoise(i * 3, variant) * 0.35;
        common.writeSynthSample(sample, (boom + crackle) * env * 0.62);
    }
}

fn synthBangMedium(samples: []i16, sr: f32, variant: usize) void {
    var phase: f32 = 0.0;
    for (samples, 0..) |*sample, i| {
        const t = @as(f32, @floatFromInt(i)) / sr;
        const freq = common.lerp(180.0 + @as(f32, @floatFromInt(variant)) * 12.0, 56.0, t / 0.42);
        phase += freq / sr;
        const env = std.math.exp(-t * 8.6);
        const noise = common.hashNoise(i * 5, variant) * 0.30;
        common.writeSynthSample(sample, (@sin(phase * common.tau) * 0.55 + noise) * env * 0.55);
    }
}

fn synthBangSmall(samples: []i16, sr: f32, variant: usize) void {
    var phase: f32 = 0.0;
    for (samples, 0..) |*sample, i| {
        const t = @as(f32, @floatFromInt(i)) / sr;
        const freq = common.lerp(260.0 + @as(f32, @floatFromInt(variant)) * 18.0, 80.0, t / 0.26);
        phase += freq / sr;
        const env = std.math.exp(-t * 14.0);
        const noise = common.hashNoise(i * 7, variant) * 0.28;
        common.writeSynthSample(sample, (@sin(phase * common.tau) * 0.45 + noise) * env * 0.48);
    }
}

fn synthBeatHigh(samples: []i16, sr: f32, variant: usize) void {
    const variant_f = @as(f32, @floatFromInt(variant));
    var phase: f32 = 0.0;
    var click_lp: f32 = 0.0;
    for (samples, 0..) |*sample, i| {
        const t = @as(f32, @floatFromInt(i)) / sr;
        const progress = std.math.clamp(t / 0.14, 0.0, 1.0);
        const freq = common.lerp(132.0 + variant_f * 4.0, 74.0, progress);
        phase += freq / sr;

        const raw_click = common.hashNoise(i * 3, variant);
        click_lp += (raw_click - click_lp) * 0.22;
        const click = (raw_click - click_lp) * std.math.exp(-t * 46.0) * 0.22;
        const env = std.math.exp(-t * 20.0);
        const sub = @sin(phase * common.tau) * 0.44;
        const body = common.triangleSample(phase * 1.04) * 0.12;

        common.writeSynthSample(sample, (sub + body + click) * env * 0.56);
    }
}

fn synthBeatLow(samples: []i16, sr: f32, variant: usize) void {
    const variant_f = @as(f32, @floatFromInt(variant));
    var phase: f32 = 0.0;
    var noise_lp: f32 = 0.0;
    for (samples, 0..) |*sample, i| {
        const t = @as(f32, @floatFromInt(i)) / sr;
        const progress = std.math.clamp(t / 0.16, 0.0, 1.0);
        const freq = common.lerp(90.0 + variant_f * 3.0, 44.0, progress);
        phase += freq / sr;

        const raw_noise = common.hashNoise(i * 5, variant);
        noise_lp += (raw_noise - noise_lp) * 0.14;
        const thump = (raw_noise - noise_lp) * std.math.exp(-t * 38.0) * 0.18;
        const env = std.math.exp(-t * 15.0);
        const sub = @sin(phase * common.tau) * 0.62;
        const body = common.triangleSample(phase * 0.98) * 0.14;
        const tail = @sin(phase * common.tau * 0.5) * 0.10;

        common.writeSynthSample(sample, (sub + body + tail + thump) * env * 0.64);
    }
}

fn synthSaucerFire(samples: []i16, sr: f32, variant: usize) void {
    var phase: f32 = 0.0;
    for (samples, 0..) |*sample, i| {
        const t = @as(f32, @floatFromInt(i)) / sr;
        const freq = 540.0 + @sin(t * 40.0) * 120.0 + @as(f32, @floatFromInt(variant)) * 20.0;
        phase += freq / sr;
        const env = std.math.exp(-t * 14.0);
        common.writeSynthSample(sample, (common.triangleSample(phase) * 0.55 + @sin(phase * common.tau * 2.1) * 0.18) * env * 0.45);
    }
}

fn synthSaucerHum(samples: []i16, sr: f32, variant: usize) void {
    var phase_a: f32 = 0.0;
    var phase_b: f32 = 0.0;
    for (samples, 0..) |*sample, i| {
        const t = @as(f32, @floatFromInt(i)) / sr;
        const base = 160.0 + @as(f32, @floatFromInt(variant)) * 6.0;
        phase_a += (base + @sin(t * 19.0) * 18.0) / sr;
        phase_b += (base * 0.5 + 3.0) / sr;
        const env = 0.55 + 0.1 * @sin(t * 17.0);
        common.writeSynthSample(sample, (@sin(phase_a * common.tau) * 0.35 + @sin(phase_b * common.tau) * 0.22) * env * 0.33);
    }
}

fn synthDeath(samples: []i16, sr: f32, variant: usize) void {
    var phase: f32 = 0.0;
    for (samples, 0..) |*sample, i| {
        const t = @as(f32, @floatFromInt(i)) / sr;
        const freq = common.lerp(420.0 + @as(f32, @floatFromInt(variant)) * 18.0, 40.0, t / 0.75);
        phase += freq / sr;
        const env = std.math.exp(-t * 3.8);
        const noise = common.hashNoise(i * 11, variant) * 0.33;
        common.writeSynthSample(sample, (@sin(phase * common.tau) * 0.38 + noise) * env * 0.62);
    }
}

fn synthHyperspace(samples: []i16, sr: f32, variant: usize) void {
    var phase: f32 = 0.0;
    for (samples, 0..) |*sample, i| {
        const t = @as(f32, @floatFromInt(i)) / sr;
        const freq = common.lerp(220.0, 1220.0 + @as(f32, @floatFromInt(variant)) * 40.0, std.math.clamp(t / 0.36, 0.0, 1.0));
        phase += freq / sr;
        const env = std.math.exp(-t * 7.5);
        common.writeSynthSample(sample, (common.triangleSample(phase) * 0.4 + @sin(phase * common.tau * 1.8) * 0.22) * env * 0.50);
    }
}

fn synthExtraLife(samples: []i16, sr: f32, variant: usize) void {
    _ = variant;
    var phase: f32 = 0.0;
    for (samples, 0..) |*sample, i| {
        const t = @as(f32, @floatFromInt(i)) / sr;
        const note: f32 = if (t < 0.10)
            660.0
        else if (t < 0.20)
            830.0
        else
            990.0;
        phase += note / sr;
        const env = std.math.exp(-t * 4.2);
        common.writeSynthSample(sample, @sin(phase * common.tau) * env * 0.34);
    }
}

fn synthPowerup(samples: []i16, sr: f32, variant: usize) void {
    const variant_f = @as(f32, @floatFromInt(variant));
    var phase_a: f32 = 0.0;
    var phase_b: f32 = 0.0;
    for (samples, 0..) |*sample, i| {
        const t = @as(f32, @floatFromInt(i)) / sr;
        const progress = std.math.clamp(t / 0.32, 0.0, 1.0);
        const lead = common.lerp(460.0 + variant_f * 18.0, 980.0 + variant_f * 22.0, progress);
        const shimmer = common.lerp(720.0, 1520.0, progress);
        phase_a += lead / sr;
        phase_b += shimmer / sr;
        const env = std.math.exp(-t * 5.2);
        const sparkle = common.hashNoise(i * 9, variant) * 0.08;
        const tone = common.triangleSample(phase_a) * 0.26 + @sin(phase_b * common.tau) * 0.18 + sparkle;
        common.writeSynthSample(sample, tone * env * 0.46);
    }
}
