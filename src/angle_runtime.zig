const std = @import("std");

const angle_lib_egl = @embedFile("angle_runtime/libEGL.dll");
const angle_lib_gles = @embedFile("angle_runtime/libGLESv2.dll");
const angle_d3dcompiler = @embedFile("angle_runtime/d3dcompiler_47.dll");

pub fn ensureReady() !void {
    const allocator = std.heap.c_allocator;
    const local_app_data = try std.process.getEnvVarOwned(allocator, "LOCALAPPDATA");
    defer allocator.free(local_app_data);

    var local_dir = try std.fs.openDirAbsolute(local_app_data, .{});
    defer local_dir.close();
    try local_dir.makePath("asteroids\\angle-runtime");

    const runtime_dir = try std.fs.path.join(allocator, &.{ local_app_data, "asteroids", "angle-runtime" });
    defer allocator.free(runtime_dir);

    try writeEmbeddedRuntimeFile(runtime_dir, "d3dcompiler_47.dll", angle_d3dcompiler);
    try writeEmbeddedRuntimeFile(runtime_dir, "libGLESv2.dll", angle_lib_gles);
    try writeEmbeddedRuntimeFile(runtime_dir, "libEGL.dll", angle_lib_egl);

    try preloadRuntimeLibrary(allocator, runtime_dir, "d3dcompiler_47.dll");
    try preloadRuntimeLibrary(allocator, runtime_dir, "libGLESv2.dll");
    try preloadRuntimeLibrary(allocator, runtime_dir, "libEGL.dll");
}

fn writeEmbeddedRuntimeFile(dir_path: []const u8, file_name: []const u8, bytes: []const u8) !void {
    var dir = try std.fs.openDirAbsolute(dir_path, .{});
    defer dir.close();

    if (dir.statFile(file_name)) |stat| {
        // if the file exists and has the same size, assume it's already up to date
        if (stat.size == bytes.len) return;
    } else |_| {}

    var file = try dir.createFile(file_name, .{ .truncate = true });
    defer file.close();
    try file.writeAll(bytes);
}

fn preloadRuntimeLibrary(allocator: std.mem.Allocator, dir_path: []const u8, file_name: []const u8) !void {
    const dll_path = try std.fs.path.join(allocator, &.{ dir_path, file_name });
    defer allocator.free(dll_path);

    const dll_path_w = try std.unicode.wtf8ToWtf16LeAllocZ(allocator, dll_path);
    defer allocator.free(dll_path_w);

    _ = try std.os.windows.LoadLibraryExW(dll_path_w, .none);
}
