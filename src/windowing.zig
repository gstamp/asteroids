const rl = @import("raylib");
const common = @import("common.zig");

pub fn initWindow() void {
    rl.setConfigFlags(.{
        .msaa_4x_hint = true,
        .vsync_hint = true,
    });
    rl.initWindow(common.world_width_i, common.world_height_i, "Asteroids Vector");
    rl.setExitKey(.null);
    rl.setTargetFPS(120);
    rl.toggleBorderlessWindowed();
}
