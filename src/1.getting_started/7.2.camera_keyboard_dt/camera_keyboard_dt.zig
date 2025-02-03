const std = @import("std");
const math = std.math;
const glfw = @import("zglfw");
const zopengl = @import("zopengl");
const zstbi = @import("zstbi");
const zm = @import("zmath");
const gl = zopengl.bindings;
const Shader = @import("Shader");

const SRC_WIDTH = 800;
const SRC_HEIGHT = 600;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var arena_allocator_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_allocator_state.deinit();
    const arena = arena_allocator_state.allocator();

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

    const window = glfw.Window.create(SRC_WIDTH, SRC_HEIGHT, "LearnOpenGL", null) catch |e| {
        std.io.getStdErr().writer().print("Failed to create GLFW window\n", .{}) catch {};
        return e;
    };
    defer window.destroy();

    glfw.makeContextCurrent(window);
    try zopengl.loadCoreProfile(glfw.getProcAddress, gl_major, gl_minor);

    glfw.swapInterval(1);

    // Camera
    var cameraPos = zm.f32x4(0.0, 0.0, 3.0, 1.0);
    const cameraFront = zm.f32x4(0.0, 0.0, -1.0, 1.0);
    const cameraUp = zm.f32x4(0.0, 1.0, 0.0, 1.0);

    // create shader program
    var shader_program: Shader = Shader.create(arena, "src/1.getting_started/7.2.camera_keyboard_dt/7.2.camera.vs", "src/1.getting_started/7.2.camera_keyboard_dt/7.2.camera.fs");

    // set up vertex data (and buffer(s)) and configure vertex attributes
    // ------------------------------------------------------------------
    const vertices = [_]f32{
        -0.5, -0.5, -0.5, 0.0, 0.0,
        0.5,  -0.5, -0.5, 1.0, 0.0,
        0.5,  0.5,  -0.5, 1.0, 1.0,
        0.5,  0.5,  -0.5, 1.0, 1.0,
        -0.5, 0.5,  -0.5, 0.0, 1.0,
        -0.5, -0.5, -0.5, 0.0, 0.0,

        -0.5, -0.5, 0.5,  0.0, 0.0,
        0.5,  -0.5, 0.5,  1.0, 0.0,
        0.5,  0.5,  0.5,  1.0, 1.0,
        0.5,  0.5,  0.5,  1.0, 1.0,
        -0.5, 0.5,  0.5,  0.0, 1.0,
        -0.5, -0.5, 0.5,  0.0, 0.0,

        -0.5, 0.5,  0.5,  1.0, 0.0,
        -0.5, 0.5,  -0.5, 1.0, 1.0,
        -0.5, -0.5, -0.5, 0.0, 1.0,
        -0.5, -0.5, -0.5, 0.0, 1.0,
        -0.5, -0.5, 0.5,  0.0, 0.0,
        -0.5, 0.5,  0.5,  1.0, 0.0,

        0.5,  0.5,  0.5,  1.0, 0.0,
        0.5,  0.5,  -0.5, 1.0, 1.0,
        0.5,  -0.5, -0.5, 0.0, 1.0,
        0.5,  -0.5, -0.5, 0.0, 1.0,
        0.5,  -0.5, 0.5,  0.0, 0.0,
        0.5,  0.5,  0.5,  1.0, 0.0,

        -0.5, -0.5, -0.5, 0.0, 1.0,
        0.5,  -0.5, -0.5, 1.0, 1.0,
        0.5,  -0.5, 0.5,  1.0, 0.0,
        0.5,  -0.5, 0.5,  1.0, 0.0,
        -0.5, -0.5, 0.5,  0.0, 0.0,
        -0.5, -0.5, -0.5, 0.0, 1.0,

        -0.5, 0.5,  -0.5, 0.0, 1.0,
        0.5,  0.5,  -0.5, 1.0, 1.0,
        0.5,  0.5,  0.5,  1.0, 0.0,
        0.5,  0.5,  0.5,  1.0, 0.0,
        -0.5, 0.5,  0.5,  0.0, 0.0,
        -0.5, 0.5,  -0.5, 0.0, 1.0,
    };

    // Comment lines to view where each are in the view!
    const cube_positions = [_][3]f32{
        .{ 0.0, 0.0, 0.0 },
        .{ 2.0, 5.0, -15.0 },
        .{ -1.5, -2.2, -2.5 },
        .{ -3.8, -2.0, -12.3 },
        .{ 2.4, -0.4, -3.5 },
        .{ -1.7, 3.0, -7.5 },
        .{ 1.3, -2.0, -2.5 },
        .{ 1.5, 2.0, -2.5 },
        .{ 1.5, 0.2, -1.5 },
        .{ -1.3, 1.0, -1.5 },
    };

    var VBO: gl.Uint = undefined;
    var VAO: gl.Uint = undefined;


    gl.genVertexArrays(1, &VAO);
    defer gl.deleteVertexArrays(1, &VAO);

    gl.genBuffers(1, &VBO);
    defer gl.deleteBuffers(1, &VBO);

    // bind the Vertex Array Object first, then bind and set vertex buffer(s), and then configure vertex attributes(s).
    gl.bindVertexArray(VAO);
    gl.bindBuffer(gl.ARRAY_BUFFER, VBO);
    gl.bufferData(gl.ARRAY_BUFFER, @sizeOf(f32) * vertices.len, &vertices, gl.STATIC_DRAW);

    // Specify and link our vertext attribute description
    // position attribute
    gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 5 * @sizeOf(f32), null);
    gl.enableVertexAttribArray(0);
    // texture coord attribute
    const texture_offset: [*c]c_uint = (3 * @sizeOf(f32));
    gl.vertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 5 * @sizeOf(f32), texture_offset);
    gl.enableVertexAttribArray(1);

    // zstbi: loading an image.
    zstbi.init(allocator);
    defer zstbi.deinit();
    zstbi.setFlipVerticallyOnLoad(true);

    const image1_path: [:0]const u8 = "resources/textures/container.jpg";
    var image1 = try zstbi.Image.loadFromFile(image1_path, 0);
    defer image1.deinit();

    const image2_path: [:0]const u8 = "resources/textures/awesomeface.png";
    var image2 = try zstbi.Image.loadFromFile(image2_path, 0);
    defer image2.deinit();

    // Create and bind texture1 resource
    var texture1: gl.Uint = undefined;

    gl.genTextures(1, &texture1);
    gl.bindTexture(gl.TEXTURE_2D, texture1);

    // set the texture1 wrapping parameters
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT); // set texture wrapping to GL_REPEAT (default wrapping method)
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
    // set texture1 filtering parameters
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);

    // Generate the texture1
    gl.texImage2D(
        gl.TEXTURE_2D, 
        0, 
        gl.RGB, 
        @as(c_int, @intCast(image1.width)), 
        @as(c_int, @intCast(image1.height)), 
        0, 
        gl.RGB, 
        gl.UNSIGNED_BYTE, 
        @ptrCast(image1.data));
    gl.generateMipmap(gl.TEXTURE_2D);

    // Create and bind texture1 resource
    var texture2: gl.Uint = undefined;

    gl.genTextures(1, &texture2);
    gl.bindTexture(gl.TEXTURE_2D, texture2);

    // set the texture1 wrapping parameters
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT); // set texture wrapping to GL_REPEAT (default wrapping method)
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
    // set texture1 filtering parameters
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);

    // Generate the texture1
    gl.texImage2D(
        gl.TEXTURE_2D, 
        0, 
        gl.RGBA, 
        @as(c_int, @intCast(image2.width)), 
        @as(c_int, @intCast(image2.height)), 
        0, 
        gl.RGBA, 
        gl.UNSIGNED_BYTE, 
        @ptrCast(image2.data));
    gl.generateMipmap(gl.TEXTURE_2D);

    gl.enable(gl.DEPTH_TEST);

    shader_program.use();
    shader_program.setInt("texture1", 0);
    shader_program.setInt("texture2", 1);

    // Buffer to store Model matrix
    var model: [16]f32 = undefined;

    // View matrix
    var view: [16]f32 = undefined;

    // Buffer to store Orojection matrix (in render loop)
    var projection: [16]f32 = undefined;

    // create transformations
    const window_size = window.getSize();
    const aspect_ratio: f32 = @as(f32, @floatFromInt(window_size[0])) / @as(f32, @floatFromInt(window_size[1]));
    const projectionM = zm.perspectiveFovRhGl(math.degreesToRadians(45.0), aspect_ratio, 0.1, 100.0);
    zm.storeMat(&projection, projectionM);
    shader_program.setMat4f("projection", projection);

    var delta_time: f32 = 0.0;
    var last_frame: f32 = 0.0;

    while (!window.shouldClose()) {
        // Time per frame
        const current_frame: f32 = @floatCast(glfw.getTime());
        delta_time = current_frame - last_frame;
        last_frame = current_frame;

        processInput(window, delta_time, &cameraPos, cameraFront, cameraUp);

        // Set the whole screen to a color
        gl.clearColor(0.2, 0.3, 0.3, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT); // also clear the depth buffer now!

        // bind textures on corresponding texture units
        gl.activeTexture(gl.TEXTURE0);
        gl.bindTexture(gl.TEXTURE_2D, texture1);
        gl.activeTexture(gl.TEXTURE1);
        gl.bindTexture(gl.TEXTURE_2D, texture2);
        gl.bindVertexArray(VAO);

        shader_program.use();

        const viewM = zm.lookAtRh(cameraPos, cameraPos + cameraFront, cameraUp);
        zm.storeMat(&view, viewM);
        shader_program.setMat4f("view", view);

        for (cube_positions) |cube_position| {
            const cube_trans = zm.translation(cube_position[0], cube_position[1], cube_position[2]);
            const modelM = zm.mul(zm.identity(), cube_trans);
            zm.storeMat(&model, modelM);
            shader_program.setMat4f("model", model);

            gl.drawArrays(gl.TRIANGLES, 0, 36);
        }

        window.swapBuffers();
        glfw.pollEvents();
    }
}

fn processInput(window: *glfw.Window, deltaTime: f32, cameraPos: *zm.F32x4, cameraFront: zm.F32x4, cameraUp: zm.F32x4) void {
    if (window.getKey(.escape) == .press) {
        window.setShouldClose(true);
    }

    const speedModifier: f32 = if (window.getKey(.left_control) == .press) 3.0 else 1.0;
    const cameraSpeed: f32 = 2.5 * deltaTime;
    const splatCameraSpeed: zm.F32x4 = @splat(cameraSpeed * speedModifier);

    if (window.getKey(.w) == .press) {
        cameraPos.* += splatCameraSpeed * cameraFront;
    }
    if (window.getKey(.a) == .press) {
        cameraPos.* -= zm.normalize3(zm.cross3(cameraFront, cameraUp)) * splatCameraSpeed;
    }
    if (window.getKey(.s) == .press) {
        cameraPos.* -= splatCameraSpeed * cameraFront;
    }
    if (window.getKey(.d) == .press) {
        cameraPos.* += zm.normalize3(zm.cross3(cameraFront, cameraUp)) * splatCameraSpeed;
    }
}