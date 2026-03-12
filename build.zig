const std = @import("std");

pub fn build(b: *std.Build) void {
    // These helpers expose the standard `-Dtarget` and `-Doptimize` flags so
    // `zig build`, `zig build run`, and release builds all share the same setup.
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    if (target.result.os.tag != .windows) {
        @panic("asteroids is configured for Windows-only builds");
    }

    // Pull in raylib-zig as a dependency and build it for the same target and
    // optimization mode as the game. We request GLES2 because the app boots the
    // ANGLE runtime in `src/angle_runtime.zig`, which translates GLES calls to
    // Direct3D on Windows.
    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
        .opengl_version = .gles_2,
    });
    const raylib = raylib_dep.module("raylib");
    const raylib_artifact = raylib_dep.artifact("raylib");

    // `core` is a reusable module for the game's shared code. Tests can target
    // this module directly without going through the executable entry point.
    const core = b.addModule("asteroids", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "raylib", .module = raylib },
        },
    });

    // Build the actual executable from `src/main.zig`, importing both the core
    // game module above and the third-party raylib module.
    const exe = b.addExecutable(.{
        .name = "asteroids",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "asteroids", .module = core },
                .{ .name = "raylib", .module = raylib },
            },
        }),
    });
    // raylib is provided as a compiled library artifact, so the executable and
    // test binaries must link against it explicitly. libc is also required by
    // raylib and parts of the runtime code.
    exe.root_module.linkLibrary(raylib_artifact);
    exe.root_module.link_libc = true;

    // `zig build` installs the executable into `zig-out/bin`.
    b.installArtifact(exe);

    // `zig build run` first performs the install step, then launches the built
    // executable. Any extra CLI args after `--` are forwarded to the program.
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the game");
    run_step.dependOn(&run_cmd.step);

    // There are two test entry points:
    // - core tests cover the reusable game module
    // - exe tests cover the main executable module graph
    const core_tests = b.addTest(.{
        .root_module = core,
    });
    core_tests.root_module.linkLibrary(raylib_artifact);
    core_tests.root_module.link_libc = true;

    const run_core_tests = b.addRunArtifact(core_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });
    exe_tests.root_module.linkLibrary(raylib_artifact);
    exe_tests.root_module.link_libc = true;

    const run_exe_tests = b.addRunArtifact(exe_tests);

    // `zig build test` runs both test binaries.
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_core_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}
