const std = @import("std");
const rl = @import("raylib");
const common = @import("common.zig");
const game_mod = @import("game.zig");

const max_internal_width = 3200;
const max_internal_height = 1800;

// Gaussian blur fragment shader for the Windows-only GLES 2.0 renderer running
// through ANGLE, so it uses GLSL 100 syntax.
const blur_shader_source_gles2: [:0]const u8 =
    \\#version 100
    \\precision mediump float;
    \\varying vec2 fragTexCoord;
    \\varying vec4 fragColor;
    \\uniform sampler2D texture0;
    \\uniform vec2 texelSize;
    \\uniform vec2 direction;
    \\void main() {
    \\    vec2 offset1 = direction * texelSize * 1.3846153846;
    \\    vec2 offset2 = direction * texelSize * 3.2307692308;
    \\    vec4 result = texture2D(texture0, fragTexCoord) * 0.2270270270;
    \\    result += texture2D(texture0, fragTexCoord + offset1) * 0.3162162162;
    \\    result += texture2D(texture0, fragTexCoord - offset1) * 0.3162162162;
    \\    result += texture2D(texture0, fragTexCoord + offset2) * 0.0702702703;
    \\    result += texture2D(texture0, fragTexCoord - offset2) * 0.0702702703;
    \\    gl_FragColor = result * fragColor;
    \\}
;

pub const Renderer = struct {
    screen_w: i32,
    screen_h: i32,
    screen_wf: f32,
    screen_hf: f32,
    render_w: i32,
    render_h: i32,
    render_wf: f32,
    render_hf: f32,
    render_rect: rl.Rectangle,
    source_rect: rl.Rectangle,
    screen_rect: rl.Rectangle,
    camera: rl.Camera2D,
    scene_target: rl.RenderTexture,
    bloom_horizontal_target: rl.RenderTexture,
    bloom_vertical_target: rl.RenderTexture,
    blur_shader: rl.Shader,
    direction_loc: i32,

    pub fn init(screen_w: i32, screen_h: i32) !Renderer {
        const screen_wf = @as(f32, @floatFromInt(screen_w));
        const screen_hf = @as(f32, @floatFromInt(screen_h));
        const supersample = computeSupersampleScale(screen_w, screen_h);
        const render_w = @min(max_internal_width, @as(i32, @intFromFloat(@ceil(screen_wf * supersample))));
        const render_h = @min(max_internal_height, @as(i32, @intFromFloat(@ceil(screen_hf * supersample))));
        const render_wf = @as(f32, @floatFromInt(render_w));
        const render_hf = @as(f32, @floatFromInt(render_h));

        var renderer = Renderer{
            .screen_w = screen_w,
            .screen_h = screen_h,
            .screen_wf = screen_wf,
            .screen_hf = screen_hf,
            .render_w = render_w,
            .render_h = render_h,
            .render_wf = render_wf,
            .render_hf = render_hf,
            .render_rect = common.rect(0.0, 0.0, render_wf, render_hf),
            .source_rect = common.rect(0.0, 0.0, render_wf, -render_hf),
            .screen_rect = common.rect(0.0, 0.0, screen_wf, screen_hf),
            .camera = rl.Camera2D{
                .offset = common.vec2(render_wf * 0.5, render_hf * 0.5),
                .target = common.vec2(common.world_width * 0.5, common.world_height * 0.5),
                .rotation = 0.0,
                .zoom = @max(render_wf / common.world_width, render_hf / common.world_height),
            },
            .scene_target = try rl.RenderTexture.init(render_w, render_h),
            .bloom_horizontal_target = try rl.RenderTexture.init(render_w, render_h),
            .bloom_vertical_target = try rl.RenderTexture.init(render_w, render_h),
            .blur_shader = try rl.loadShaderFromMemory(null, blur_shader_source_gles2),
            .direction_loc = undefined,
        };

        renderer.direction_loc = rl.getShaderLocation(renderer.blur_shader, "direction");
        const texel_loc = rl.getShaderLocation(renderer.blur_shader, "texelSize");
        var texel_size = [2]f32{ 1.0 / render_wf, 1.0 / render_hf };
        rl.setShaderValue(renderer.blur_shader, texel_loc, &texel_size, .vec2);

        setBloomTextureOptions(renderer.scene_target.texture);
        setBloomTextureOptions(renderer.bloom_horizontal_target.texture);
        setBloomTextureOptions(renderer.bloom_vertical_target.texture);

        return renderer;
    }

    pub fn deinit(self: *Renderer) void {
        rl.unloadShader(self.blur_shader);
        self.bloom_vertical_target.unload();
        self.bloom_horizontal_target.unload();
        self.scene_target.unload();
    }

    pub fn drawFrame(self: *const Renderer, game: *const game_mod.Game) void {
        renderScene(self, game);
        applyBlurPass(self, self.scene_target.texture, self.bloom_horizontal_target, [2]f32{ 1.0, 0.0 });
        applyBlurPass(self, self.bloom_horizontal_target.texture, self.bloom_vertical_target, [2]f32{ 0.0, 1.0 });
        drawComposite(self, game);
    }
};

fn renderScene(renderer: *const Renderer, game: *const game_mod.Game) void {
    renderer.scene_target.begin();
    defer renderer.scene_target.end();

    rl.clearBackground(common.rgba(2, 4, 8, 255));
    rl.drawRectangleGradientV(0, 0, renderer.render_w, renderer.render_h, common.rgba(5, 10, 18, 255), common.rgba(1, 2, 5, 255));
    renderer.camera.begin();
    game.drawWorld();
    renderer.camera.end();

    if (game.explosion_flash_intensity > 0.001) {
        const alpha = @as(u8, @intFromFloat(std.math.clamp(game.explosion_flash_intensity * 110.0, 0.0, 255.0)));
        rl.drawRectangle(0, 0, renderer.render_w, renderer.render_h, common.rgba(255, 250, 240, alpha));
    }
}

fn applyBlurPass(renderer: *const Renderer, source: rl.Texture2D, target: rl.RenderTexture, direction: [2]f32) void {
    target.begin();
    defer target.end();

    rl.clearBackground(.black);
    rl.beginShaderMode(renderer.blur_shader);
    defer rl.endShaderMode();

    var direction_value = direction;
    rl.setShaderValue(renderer.blur_shader, renderer.direction_loc, &direction_value, .vec2);
    common.drawRenderTexture(source, renderer.source_rect, renderer.render_rect);
}

fn drawComposite(renderer: *const Renderer, game: *const game_mod.Game) void {
    rl.beginDrawing();
    defer rl.endDrawing();

    rl.clearBackground(common.rgba(1, 3, 6, 255));
    rl.drawRectangleGradientV(0, 0, renderer.screen_w, renderer.screen_h, common.rgba(5, 10, 18, 255), common.rgba(1, 2, 5, 255));

    rl.beginBlendMode(.additive);
    const bloom_alpha = @as(u8, @intFromFloat(170.0 + 22.0 * @sin(game.display_phase * 37.0)));
    common.drawRenderTextureTint(
        renderer.bloom_vertical_target.texture,
        renderer.source_rect,
        renderer.screen_rect,
        common.rgba(150, 200, 255, bloom_alpha),
    );
    rl.endBlendMode();

    common.drawRenderTexture(renderer.scene_target.texture, renderer.source_rect, renderer.screen_rect);
    game.drawOverlay(renderer.screen_wf, renderer.screen_hf);
}

fn setBloomTextureOptions(texture: rl.Texture2D) void {
    rl.setTextureFilter(texture, .bilinear);
    rl.setTextureWrap(texture, .clamp);
}

fn computeSupersampleScale(screen_w: i32, screen_h: i32) f32 {
    const pixels = @as(i64, screen_w) * @as(i64, screen_h);
    if (pixels <= 1920 * 1080) return 1.5;
    if (pixels <= 2560 * 1440) return 1.35;
    return 1.2;
}
