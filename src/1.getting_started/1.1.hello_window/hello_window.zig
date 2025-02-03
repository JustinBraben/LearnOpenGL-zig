const std = @import("std");
const glfw = @import("zglfw");
const zopengl = @import("zopengl");

pub fn main() !void {
    try glfw.init();
    defer glfw.terminate();

    const gl_major = 4;
    const gl_minor = 1;
    glfw.windowHintTyped(.context_version_major, gl_major);
    glfw.windowHintTyped(.context_version_minor, gl_minor);
    glfw.windowHintTyped(.opengl_profile, .opengl_core_profile);
    glfw.windowHintTyped(.opengl_forward_compat, true);
    glfw.windowHintTyped(.client_api, .opengl_api);
    glfw.windowHintTyped(.doublebuffer, true);

    const window = glfw.Window.create(800, 600, "LearnOpenGL", null) catch |e| {
        std.io.getStdErr().writer().print("Failed to create GLFW window\n", .{}) catch {};
        return e;
    };
    defer window.destroy();

    glfw.makeContextCurrent(window);
    try zopengl.loadCoreProfile(glfw.getProcAddress, gl_major, gl_minor);

    glfw.swapInterval(1);

    while (!window.shouldClose()) {
        if (window.getKey(.escape) == .press) window.setShouldClose(true);

        window.swapBuffers();
        glfw.pollEvents();
    }
}

// test "simple test" {
//     const stdout_file = std.io.getStdOut().writer();
//     var bw = std.io.bufferedWriter(stdout_file);
//     const stdout = bw.writer();
//     try stdout.print("Run `zig build test` to run the tests.\n", .{});
//     try bw.flush(); // don't forget to flush!
// }
