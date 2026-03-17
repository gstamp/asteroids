const std = @import("std");
const rl = @import("raylib");

pub const world_width = 1600.0;
pub const world_height = 900.0;
pub const world_width_i = 1600;
pub const world_height_i = 900;
pub const fixed_dt = 1.0 / 120.0;
pub const sample_rate: u32 = 44_100;
pub const max_asteroids = 64;
pub const max_bullets = 24;
pub const max_particles = 1800;
pub const max_stars = 96;
pub const max_player_bullets = 4;
pub const pi = std.math.pi;
pub const tau = std.math.tau;

pub const Vec2 = rl.Vector2;
pub const AxisOffsets = struct {
    values: [3]f32 = [_]f32{0.0} ** 3,
    len: usize = 1,
};

/// Builds a vector from x and y components.
pub fn vec2(x: f32, y: f32) Vec2 {
    return .{ .x = x, .y = y };
}

/// Returns the zero vector.
pub fn zero() Vec2 {
    return vec2(0.0, 0.0);
}

/// Builds a rectangle from position and size values.
pub fn rect(x: f32, y: f32, width: f32, height: f32) rl.Rectangle {
    return .{ .x = x, .y = y, .width = width, .height = height };
}

/// Adds two vectors component-wise.
pub fn add(a: Vec2, b: Vec2) Vec2 {
    return vec2(a.x + b.x, a.y + b.y);
}

/// Subtracts one vector from another component-wise.
pub fn sub(a: Vec2, b: Vec2) Vec2 {
    return vec2(a.x - b.x, a.y - b.y);
}

/// Multiplies a vector by a scalar.
pub fn scale(a: Vec2, amount: f32) Vec2 {
    return vec2(a.x * amount, a.y * amount);
}

/// Returns the squared length of a vector.
pub fn lengthSq(a: Vec2) f32 {
    return a.x * a.x + a.y * a.y;
}

/// Squares a scalar value.
pub fn sqr(v: f32) f32 {
    return v * v;
}

/// Creates a vector from an angle and magnitude.
pub fn fromAngle(angle: f32, amount: f32) Vec2 {
    return vec2(@cos(angle) * amount, @sin(angle) * amount);
}

/// Rotates a vector around the origin.
pub fn rotate(v: Vec2, angle: f32) Vec2 {
    const c = @cos(angle);
    const s = @sin(angle);
    return vec2(v.x * c - v.y * s, v.x * s + v.y * c);
}

/// Normalizes a vector to the requested scale, or uses a fallback when it is too small.
pub fn normalizeOr(v: Vec2, fallback: Vec2, scale_to: f32) Vec2 {
    const len_sq = lengthSq(v);
    if (len_sq <= 0.0001) return scale(fallback, scale_to);
    const inv = scale_to / @sqrt(len_sq);
    return scale(v, inv);
}

/// Wraps a scalar coordinate into the range `[0, max)`.
pub fn wrapAxis(value: f32, max: f32) f32 {
    var result = value;
    while (result < 0.0) result += max;
    while (result >= max) result -= max;
    return result;
}

/// Wraps a point around the world bounds.
pub fn wrapPoint(pos: Vec2) Vec2 {
    return vec2(wrapAxis(pos.x, world_width), wrapAxis(pos.y, world_height));
}

/// Returns the shortest wrapped delta from one point to another on the torus.
pub fn torusDelta(a: Vec2, b: Vec2) Vec2 {
    var dx = b.x - a.x;
    var dy = b.y - a.y;
    if (dx > world_width * 0.5) dx -= world_width;
    if (dx < -world_width * 0.5) dx += world_width;
    if (dy > world_height * 0.5) dy -= world_height;
    if (dy < -world_height * 0.5) dy += world_height;
    return vec2(dx, dy);
}

/// Returns the squared wrapped distance between two points on the torus.
pub fn torusDistanceSq(a: Vec2, b: Vec2) f32 {
    return lengthSq(torusDelta(a, b));
}

/// Linearly interpolates between two scalars with clamped progress.
pub fn lerp(a: f32, b: f32, t: f32) f32 {
    return a + (b - a) * std.math.clamp(t, 0.0, 1.0);
}

/// Moves a value toward a target by at most `delta`.
pub fn approach(value: f32, target: f32, delta: f32) f32 {
    if (value < target) return @min(value + delta, target);
    if (value > target) return @max(value - delta, target);
    return value;
}

/// Builds a color from RGBA channels.
pub fn rgba(r: u8, g: u8, b: u8, a: u8) rl.Color {
    return .{ .r = r, .g = g, .b = b, .a = a };
}

/// Returns a copy of a color with a replaced alpha channel.
pub fn withAlpha(color: rl.Color, alpha: u8) rl.Color {
    return rgba(color.r, color.g, color.b, alpha);
}

fn alphaByte(value: f32) u8 {
    return @as(u8, @intFromFloat(std.math.clamp(value, 0.0, 255.0)));
}

/// Draws a soft glowing dot using layered circles.
pub fn drawGlowDot(pos: Vec2, radius: f32, color: rl.Color, intensity: f32) void {
    const outer = withAlpha(color, alphaByte(42.0 * intensity));
    const mid = withAlpha(color, alphaByte(95.0 * intensity));
    const core = withAlpha(color, alphaByte(230.0 * intensity));
    rl.drawCircleV(pos, radius * 3.2, outer);
    rl.drawCircleV(pos, radius * 1.8, mid);
    rl.drawCircleV(pos, @max(radius, 1.0), core);
}

/// Draws a soft glowing line with a brighter beam core and hotter endpoints.
pub fn drawGlowLine(a: Vec2, b: Vec2, thickness: f32, color: rl.Color, intensity: f32) void {
    const delta = sub(b, a);
    const len_sq = lengthSq(delta);
    if (len_sq <= 0.01) {
        drawGlowDot(a, @max(thickness * 0.75, 1.0), color, intensity);
        return;
    }

    const length = @sqrt(len_sq);
    const segment_count_i = std.math.clamp(@as(i32, @intFromFloat(@ceil(length / 18.0))), 1, 24);
    const segment_count: usize = @intCast(segment_count_i);
    const wide_halo = withAlpha(color, alphaByte(12.0 * intensity));
    rl.drawLineEx(a, b, thickness * 5.4, wide_halo);

    for (0..segment_count) |i| {
        const t0 = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(segment_count));
        const t1 = @as(f32, @floatFromInt(i + 1)) / @as(f32, @floatFromInt(segment_count));
        const tm = (t0 + t1) * 0.5;
        const beam_profile = 0.7 + 0.3 * @sin(tm * pi);
        const segment_intensity = intensity * beam_profile;
        const segment_a = add(a, scale(delta, t0));
        const segment_b = add(a, scale(delta, t1));
        const outer = withAlpha(color, alphaByte(28.0 * segment_intensity));
        const middle = withAlpha(color, alphaByte(80.0 * segment_intensity));
        const core = withAlpha(color, alphaByte(228.0 * segment_intensity));
        rl.drawLineEx(segment_a, segment_b, thickness * 4.1, outer);
        rl.drawLineEx(segment_a, segment_b, thickness * 2.3, middle);
        rl.drawLineEx(segment_a, segment_b, thickness, core);
    }

    const endpoint_glow = intensity * (0.32 + 0.22 * std.math.clamp(length / 90.0, 0.0, 1.0));
    drawGlowDot(a, @max(thickness * 0.7, 1.0), color, endpoint_glow);
    drawGlowDot(b, @max(thickness * 0.7, 1.0), color, endpoint_glow);
}

/// Draws a glowing dot and its wrapped copies when it crosses the world edge.
pub fn drawWrappedDot(pos: Vec2, radius: f32, color: rl.Color, intensity: f32) void {
    const x_offsets = wrapOffsets(pos.x, radius, world_width);
    const y_offsets = wrapOffsets(pos.y, radius, world_height);
    for (x_offsets.values[0..x_offsets.len]) |ox| {
        for (y_offsets.values[0..y_offsets.len]) |oy| {
            drawGlowDot(vec2(pos.x + ox, pos.y + oy), radius, color, intensity);
        }
    }
}

/// Returns the axis offsets needed to draw wrapped copies near an edge.
pub fn wrapOffsets(value: f32, radius: f32, max: f32) AxisOffsets {
    var offsets = AxisOffsets{};
    if (value - radius <= 0.0) {
        offsets.values[offsets.len] = max;
        offsets.len += 1;
    }
    if (value + radius >= max) {
        offsets.values[offsets.len] = -max;
        offsets.len += 1;
    }
    return offsets;
}

/// Draws a render texture into a destination rectangle with no tint.
pub fn drawRenderTexture(texture: rl.Texture2D, source: rl.Rectangle, dest: rl.Rectangle) void {
    rl.drawTexturePro(texture, source, dest, zero(), 0.0, .white);
}

/// Draws a tinted render texture into a destination rectangle.
pub fn drawRenderTextureTint(texture: rl.Texture2D, source: rl.Rectangle, dest: rl.Rectangle, tint: rl.Color) void {
    rl.drawTexturePro(texture, source, dest, zero(), 0.0, tint);
}

/// Generates deterministic noise in the range `[-1, 1)` from an index and variant.
pub fn hashNoise(index: usize, variant: usize) f32 {
    const base: u64 = @as(u64, index) *% 9781 +% @as(u64, variant) *% 6271 +% 0x68BC21EB;
    var x: u32 = @truncate(base);
    x = (x << 13) ^ x;
    const mixed = x *% (x *% x *% 15731 +% 789221) +% 1376312589;
    const normalized = @as(f32, @floatFromInt(mixed & 0x7fffffff)) / 1073741824.0;
    return normalized - 1.0;
}

/// Samples a triangle wave for the given phase.
pub fn triangleSample(phase: f32) f32 {
    return 2.0 * @abs(2.0 * (phase - @floor(phase + 0.5))) - 1.0;
}

/// Writes a clamped floating-point sample into a 16-bit PCM output slot.
pub fn writeSynthSample(out: *i16, value: f32) void {
    out.* = @as(i16, @intFromFloat(std.math.clamp(value * 32767.0, -32767.0, 32767.0)));
}
