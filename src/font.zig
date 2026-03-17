const std = @import("std");
const common = @import("common.zig");
const rl = @import("raylib");

pub const Align = enum {
    left,
    center,
    right,
};

pub const Segment = struct {
    ax: f32,
    ay: f32,
    bx: f32,
    by: f32,
};

pub fn drawText(text: []const u8, pos: common.Vec2, size: f32, tracking: f32, thickness: f32, text_align: Align, color: rl.Color) void {
    var x = pos.x;
    const width = measureText(text, size, tracking);
    switch (text_align) {
        .left => {},
        .center => x -= width * 0.5,
        .right => x -= width,
    }

    for (text) |raw| {
        const ch = std.ascii.toUpper(raw);
        if (ch == ' ') {
            x += size * 0.55 + tracking;
            continue;
        }
        const advance = glyphAdvance(ch);
        for (glyphSegments(ch)) |segment| {
            const a = common.vec2(x + segment.ax * size, pos.y + segment.ay * size);
            const b = common.vec2(x + segment.bx * size, pos.y + segment.by * size);
            drawStroke(a, b, thickness, color);
        }
        x += advance * size + tracking;
    }
}

pub fn measureText(text: []const u8, size: f32, tracking: f32) f32 {
    if (text.len == 0) return 0.0;
    var width: f32 = 0.0;
    for (text, 0..) |raw, i| {
        width += glyphAdvance(std.ascii.toUpper(raw)) * size;
        if (i + 1 < text.len) width += tracking;
    }
    return width;
}

pub fn glyphAdvance(ch: u8) f32 {
    return switch (ch) {
        'I', '1' => 0.42,
        'M', 'W' => 1.05,
        ' ' => 0.55,
        else => 0.95,
    };
}

pub fn glyphSegments(ch: u8) []const Segment {
    return switch (ch) {
        '0' => glyph_0[0..],
        '1' => glyph_1[0..],
        '2' => glyph_2[0..],
        '3' => glyph_3[0..],
        '4' => glyph_4[0..],
        '5' => glyph_5[0..],
        '6' => glyph_6[0..],
        '7' => glyph_7[0..],
        '8' => glyph_8[0..],
        '9' => glyph_9[0..],
        'A' => glyph_A[0..],
        'C' => glyph_C[0..],
        'D' => glyph_D[0..],
        'E' => glyph_E[0..],
        'F' => glyph_F[0..],
        'G' => glyph_G[0..],
        'I' => glyph_I[0..],
        'L' => glyph_L[0..],
        'M' => glyph_M[0..],
        'N' => glyph_N[0..],
        'O' => glyph_O[0..],
        'P' => glyph_P[0..],
        'R' => glyph_R[0..],
        'S' => glyph_S[0..],
        'T' => glyph_T[0..],
        'U' => glyph_U[0..],
        'V' => glyph_V[0..],
        'W' => glyph_W[0..],
        'Y' => glyph_Y[0..],
        else => &.{},
    };
}

const glyph_0 = [_]Segment{ seg(0.18, 0.00, 0.78, 0.00), seg(0.78, 0.00, 0.98, 0.20), seg(0.98, 0.20, 0.98, 0.80), seg(0.98, 0.80, 0.78, 1.00), seg(0.78, 1.00, 0.18, 1.00), seg(0.18, 1.00, 0.00, 0.80), seg(0.00, 0.80, 0.00, 0.20), seg(0.00, 0.20, 0.18, 0.00) };
const glyph_1 = [_]Segment{ seg(0.45, 0.00, 0.45, 1.00), seg(0.22, 0.22, 0.45, 0.00), seg(0.20, 1.00, 0.70, 1.00) };
const glyph_2 = [_]Segment{ seg(0.06, 0.20, 0.22, 0.00), seg(0.22, 0.00, 0.78, 0.00), seg(0.78, 0.00, 0.96, 0.20), seg(0.96, 0.20, 0.10, 1.00), seg(0.10, 1.00, 0.96, 1.00) };
const glyph_3 = [_]Segment{ seg(0.08, 0.00, 0.86, 0.00), seg(0.86, 0.00, 0.86, 1.00), seg(0.08, 0.50, 0.70, 0.50), seg(0.08, 1.00, 0.86, 1.00) };
const glyph_4 = [_]Segment{ seg(0.82, 0.00, 0.82, 1.00), seg(0.08, 0.56, 0.82, 0.56), seg(0.08, 0.56, 0.54, 0.00) };
const glyph_5 = [_]Segment{ seg(0.96, 0.00, 0.16, 0.00), seg(0.16, 0.00, 0.12, 0.48), seg(0.12, 0.48, 0.78, 0.48), seg(0.78, 0.48, 0.96, 0.68), seg(0.96, 0.68, 0.78, 1.00), seg(0.78, 1.00, 0.08, 1.00) };
const glyph_6 = [_]Segment{ seg(0.84, 0.02, 0.18, 0.18), seg(0.18, 0.18, 0.08, 0.58), seg(0.08, 0.58, 0.22, 1.00), seg(0.22, 1.00, 0.80, 1.00), seg(0.80, 1.00, 0.96, 0.76), seg(0.96, 0.76, 0.82, 0.50), seg(0.82, 0.50, 0.14, 0.50) };
const glyph_7 = [_]Segment{ seg(0.06, 0.00, 0.96, 0.00), seg(0.96, 0.00, 0.40, 1.00) };
const glyph_8 = [_]Segment{ seg(0.18, 0.00, 0.78, 0.00), seg(0.18, 0.50, 0.78, 0.50), seg(0.18, 1.00, 0.78, 1.00), seg(0.00, 0.18, 0.00, 0.82), seg(0.98, 0.18, 0.98, 0.82) };
const glyph_9 = [_]Segment{ seg(0.90, 0.82, 0.76, 0.00), seg(0.76, 0.00, 0.20, 0.00), seg(0.20, 0.00, 0.04, 0.22), seg(0.04, 0.22, 0.18, 0.50), seg(0.18, 0.50, 0.86, 0.50), seg(0.86, 0.50, 0.96, 0.18), seg(0.96, 0.18, 0.96, 1.00) };
const glyph_A = [_]Segment{ seg(0.00, 1.00, 0.28, 0.00), seg(0.28, 0.00, 0.56, 0.00), seg(0.56, 0.00, 0.96, 1.00), seg(0.16, 0.56, 0.78, 0.56) };
const glyph_C = [_]Segment{ seg(0.92, 0.08, 0.72, 0.00), seg(0.72, 0.00, 0.20, 0.00), seg(0.20, 0.00, 0.00, 0.22), seg(0.00, 0.22, 0.00, 0.80), seg(0.00, 0.80, 0.20, 1.00), seg(0.20, 1.00, 0.72, 1.00), seg(0.72, 1.00, 0.92, 0.92) };
const glyph_D = [_]Segment{ seg(0.00, 0.00, 0.00, 1.00), seg(0.00, 0.00, 0.56, 0.00), seg(0.56, 0.00, 0.94, 0.28), seg(0.94, 0.28, 0.94, 0.72), seg(0.94, 0.72, 0.56, 1.00), seg(0.56, 1.00, 0.00, 1.00) };
const glyph_E = [_]Segment{ seg(0.00, 0.00, 0.00, 1.00), seg(0.00, 0.00, 0.88, 0.00), seg(0.00, 0.50, 0.70, 0.50), seg(0.00, 1.00, 0.88, 1.00) };
const glyph_F = [_]Segment{ seg(0.00, 0.00, 0.00, 1.00), seg(0.00, 0.00, 0.88, 0.00), seg(0.00, 0.50, 0.70, 0.50) };
const glyph_G = [_]Segment{ seg(0.92, 0.10, 0.72, 0.00), seg(0.72, 0.00, 0.20, 0.00), seg(0.20, 0.00, 0.00, 0.22), seg(0.00, 0.22, 0.00, 0.80), seg(0.00, 0.80, 0.20, 1.00), seg(0.20, 1.00, 0.76, 1.00), seg(0.76, 1.00, 0.96, 0.80), seg(0.96, 0.80, 0.96, 0.58), seg(0.96, 0.58, 0.56, 0.58) };
const glyph_I = [_]Segment{ seg(0.12, 0.00, 0.78, 0.00), seg(0.45, 0.00, 0.45, 1.00), seg(0.12, 1.00, 0.78, 1.00) };
const glyph_L = [_]Segment{ seg(0.00, 0.00, 0.00, 1.00), seg(0.00, 1.00, 0.90, 1.00) };
const glyph_M = [_]Segment{ seg(0.00, 1.00, 0.00, 0.00), seg(0.00, 0.00, 0.48, 0.46), seg(0.48, 0.46, 0.96, 0.00), seg(0.96, 0.00, 0.96, 1.00) };
const glyph_N = [_]Segment{ seg(0.00, 1.00, 0.00, 0.00), seg(0.00, 0.00, 0.96, 1.00), seg(0.96, 1.00, 0.96, 0.00) };
const glyph_O = [_]Segment{ seg(0.20, 0.00, 0.76, 0.00), seg(0.76, 0.00, 0.96, 0.22), seg(0.96, 0.22, 0.96, 0.78), seg(0.96, 0.78, 0.76, 1.00), seg(0.76, 1.00, 0.20, 1.00), seg(0.20, 1.00, 0.00, 0.78), seg(0.00, 0.78, 0.00, 0.22), seg(0.00, 0.22, 0.20, 0.00) };
const glyph_P = [_]Segment{ seg(0.00, 1.00, 0.00, 0.00), seg(0.00, 0.00, 0.76, 0.00), seg(0.76, 0.00, 0.94, 0.18), seg(0.94, 0.18, 0.94, 0.42), seg(0.94, 0.42, 0.76, 0.58), seg(0.76, 0.58, 0.00, 0.58) };
const glyph_R = [_]Segment{ seg(0.00, 1.00, 0.00, 0.00), seg(0.00, 0.00, 0.76, 0.00), seg(0.76, 0.00, 0.94, 0.18), seg(0.94, 0.18, 0.94, 0.42), seg(0.94, 0.42, 0.76, 0.58), seg(0.76, 0.58, 0.00, 0.58), seg(0.32, 0.58, 0.96, 1.00) };
const glyph_S = [_]Segment{ seg(0.92, 0.08, 0.70, 0.00), seg(0.70, 0.00, 0.18, 0.00), seg(0.18, 0.00, 0.02, 0.18), seg(0.02, 0.18, 0.18, 0.50), seg(0.18, 0.50, 0.78, 0.50), seg(0.78, 0.50, 0.96, 0.74), seg(0.96, 0.74, 0.76, 1.00), seg(0.76, 1.00, 0.08, 1.00) };
const glyph_T = [_]Segment{ seg(0.04, 0.00, 0.96, 0.00), seg(0.50, 0.00, 0.50, 1.00) };
const glyph_U = [_]Segment{ seg(0.00, 0.00, 0.00, 0.78), seg(0.00, 0.78, 0.20, 1.00), seg(0.20, 1.00, 0.76, 1.00), seg(0.76, 1.00, 0.96, 0.78), seg(0.96, 0.78, 0.96, 0.00) };
const glyph_V = [_]Segment{ seg(0.00, 0.00, 0.48, 1.00), seg(0.48, 1.00, 0.96, 0.00) };
const glyph_W = [_]Segment{ seg(0.00, 0.00, 0.18, 1.00), seg(0.18, 1.00, 0.48, 0.46), seg(0.48, 0.46, 0.78, 1.00), seg(0.78, 1.00, 0.96, 0.00) };
const glyph_Y = [_]Segment{ seg(0.00, 0.00, 0.48, 0.48), seg(0.96, 0.00, 0.48, 0.48), seg(0.48, 0.48, 0.48, 1.00) };

fn seg(ax: f32, ay: f32, bx: f32, by: f32) Segment {
    return .{ .ax = ax, .ay = ay, .bx = bx, .by = by };
}

fn drawStroke(a: common.Vec2, b: common.Vec2, thickness: f32, color: rl.Color) void {
    common.drawGlowLine(a, b, thickness, color, 0.92);
}

test "measurement grows with more glyphs" {
    try std.testing.expect(measureText("WAVE", 12.0, 4.0) > measureText("WAV", 12.0, 4.0));
}

test "glyph F is defined" {
    try std.testing.expect(glyphSegments('F').len > 0);
}
