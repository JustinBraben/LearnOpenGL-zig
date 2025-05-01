const std = @import("std");
const math = std.math;
const glfw = @import("zglfw");
const zopengl = @import("zopengl");
const zstbi = @import("zstbi");
const zm = @import("zmath");
const gl = zopengl.bindings;
const Shader = @import("Shader");
const Camera = @import("Camera");

pub const ConfigOptions = struct {
    width: i32 = 1280,
    height: i32 = 720,
    gl_major: i32 = 4,
    gl_minor: i32 = 1,
};

// Camera
const camera_pos = zm.loadArr3(.{ 0.0, 0.0, 3.0 });
var lastX: f64 = 0.0;
var lastY: f64 = 0.0;
var first_mouse = true;
var camera = Camera.init(camera_pos);

// Timing
var delta_time: f32 = 0.0;
var last_frame: f32 = 0.0;

// lighting
var light_position = [_]f32{ 4.2, 2.0, 4.0 };

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var arena_allocator_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_allocator_state.deinit();
    const arena = arena_allocator_state.allocator();

    const config: ConfigOptions = .{};

    try glfw.init();
    defer glfw.terminate();

    glfw.windowHint(.context_version_major, config.gl_major);
    glfw.windowHint(.context_version_minor, config.gl_minor);
    glfw.windowHint(.opengl_profile, .opengl_core_profile);
    glfw.windowHint(.opengl_forward_compat, true);
    glfw.windowHint(.client_api, .opengl_api);
    glfw.windowHint(.doublebuffer, true);

    var window = glfw.Window.create(config.width, config.height, "LearnOpenGL", null) catch |e| {
        std.io.getStdErr().writer().print("Failed to create GLFW window\n", .{}) catch {};
        return e;
    };
    defer window.destroy();

    glfw.makeContextCurrent(window);
    _ = window.setFramebufferSizeCallback(framebuffer_size_callback);
    _ = window.setCursorPosCallback(mouse_callback);
    _ = window.setScrollCallback(scroll_callback);
    try window.setInputMode(.cursor, glfw.Cursor.Mode.disabled);
    try zopengl.loadCoreProfile(glfw.getProcAddress, @intCast(config.gl_major), @intCast(config.gl_minor));

    glfw.swapInterval(1);

    // configure global opengl state
    // -----------------------------
    gl.enable(gl.DEPTH_TEST);

    // build and compile shaders
    // -------------------------
    var shader: Shader = try Shader.create(arena, "src/4.advanced_opengl/5.2.framebuffers_exercise1/5.2.framebuffers.vs", "src/4.advanced_opengl/5.2.framebuffers_exercise1/5.2.framebuffers.fs");
    var screenShader: Shader = try Shader.create(arena, "src/4.advanced_opengl/5.2.framebuffers_exercise1/5.2.framebuffers_screen.vs", "src/4.advanced_opengl/5.2.framebuffers_exercise1/5.2.framebuffers_screen.fs");

    // set up vertex data (and buffer(s)) and configure vertex attributes
    // ------------------------------------------------------------------
    const vertices = [_]gl.Float{
        // positions          // texture Coords
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

    const planeVertices = [_]gl.Float{
        // positions       // texture Coords
        5.0,  -0.5, 5.0,  2.0, 0.0,
        -5.0, -0.5, 5.0,  0.0, 0.0,
        -5.0, -0.5, -5.0, 0.0, 2.0,

        5.0,  -0.5, 5.0,  2.0, 0.0,
        -5.0, -0.5, -5.0, 0.0, 2.0,
        5.0,  -0.5, -5.0, 2.0, 2.0,
    };

    // vertex attributes for a quad that fills the entire screen in Normalized Device Coordinates.
    // NOTE that this plane is now much smaller and at the top of the screen
    const quadVertices = [_]gl.Float{
        // positions   // texCoords
        -0.3, 1.0, 0.0, 1.0,
        -0.3, 0.7, 0.0, 0.0,
        0.3,  0.7, 1.0, 0.0,

        -0.3, 1.0, 0.0, 1.0,
        0.3,  0.7, 1.0, 0.0,
        0.3,  1.0, 1.0, 1.0,
    };

    // cube VAO
    var cubeVAO: gl.Uint = undefined;
    var cubeVBO: gl.Uint = undefined;
    gl.genVertexArrays(1, &cubeVAO);
    defer gl.deleteVertexArrays(1, &cubeVAO);
    gl.genBuffers(1, &cubeVBO);
    defer gl.deleteBuffers(1, &cubeVBO);
    gl.bindBuffer(gl.ARRAY_BUFFER, cubeVBO);
    gl.bufferData(gl.ARRAY_BUFFER, @sizeOf(gl.Float) * vertices.len, &vertices, gl.STATIC_DRAW);
    gl.bindVertexArray(cubeVAO);
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 5 * @sizeOf(gl.Float), null);
    gl.enableVertexAttribArray(1);
    const texture_coords_offset: [*c]c_uint = (3 * @sizeOf(gl.Float));
    gl.vertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 5 * @sizeOf(gl.Float), texture_coords_offset);
    // plane VAO
    var planeVAO: gl.Uint = undefined;
    var planeVBO: gl.Uint = undefined;
    gl.genVertexArrays(1, &planeVAO);
    defer gl.deleteVertexArrays(1, &planeVAO);
    gl.genBuffers(1, &planeVBO);
    defer gl.deleteBuffers(1, &planeVBO);
    gl.bindVertexArray(planeVAO);
    gl.bindBuffer(gl.ARRAY_BUFFER, planeVBO);
    gl.bufferData(gl.ARRAY_BUFFER, @sizeOf(gl.Float) * planeVertices.len, &planeVertices, gl.STATIC_DRAW);
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 5 * @sizeOf(gl.Float), null);
    gl.enableVertexAttribArray(1);
    gl.vertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 5 * @sizeOf(gl.Float), texture_coords_offset);
    // screen quad VAO
    var quadVAO: gl.Uint = undefined;
    var quadVBO: gl.Uint = undefined;
    gl.genVertexArrays(1, &quadVAO);
    defer gl.deleteVertexArrays(1, &quadVAO);
    gl.genBuffers(1, &quadVBO);
    defer gl.deleteBuffers(1, &quadVBO);
    gl.bindVertexArray(quadVAO);
    gl.bindBuffer(gl.ARRAY_BUFFER, quadVBO);
    gl.bufferData(gl.ARRAY_BUFFER, @sizeOf(gl.Float) * quadVertices.len, &quadVertices, gl.STATIC_DRAW);
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 4 * @sizeOf(gl.Float), null);
    gl.enableVertexAttribArray(1);
    const quad_texture_coords_offset: [*c]c_uint = (2 * @sizeOf(gl.Float));
    gl.vertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 4 * @sizeOf(gl.Float), quad_texture_coords_offset);

    // zstbi: loading an image.
    zstbi.init(allocator);
    defer zstbi.deinit();

    // load textures (we now use a utility function to keep the code more organized)
    // -----------------------------------------------------------------------------
    const container_path = "resources/textures/container.jpg";
    const metal_path = "resources/textures/metal.png";
    var cube_texture: gl.Uint = undefined;
    var floor_texture: gl.Uint = undefined;
    try loadTexture(container_path, &cube_texture);
    try loadTexture(metal_path, &floor_texture);

    // shader configuration
    // --------------------
    shader.use();
    shader.setInt("texture1", 0);

    screenShader.use();
    screenShader.setInt("screenTexture", 0);

    // framebuffer configuration
    // -------------------------
    var framebuffer: gl.Uint = undefined;
    gl.genFramebuffers(1, &framebuffer);
    defer gl.deleteRenderbuffers(1, &framebuffer);
    gl.bindFramebuffer(gl.FRAMEBUFFER, framebuffer);
    // create a color attachment texture
    var textureColorbuffer: gl.Uint = undefined;
    gl.genTextures(1, &textureColorbuffer);
    gl.bindTexture(gl.TEXTURE_2D, textureColorbuffer);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGB, config.width, config.height, 0, gl.RGB, gl.UNSIGNED_BYTE, null);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, textureColorbuffer, 0);
    // create a renderbuffer object for depth and stencil attachment (we won't be sampling these)
    var rbo: gl.Uint = undefined;
    gl.genRenderbuffers(1, &rbo);
    defer gl.deleteRenderbuffers(1, &rbo);
    gl.bindRenderbuffer(gl.RENDERBUFFER, rbo);
    gl.renderbufferStorage(gl.RENDERBUFFER, gl.DEPTH24_STENCIL8, config.width, config.height); // use a single renderbuffer object for both a depth AND stencil buffer.
    gl.framebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_STENCIL_ATTACHMENT, gl.RENDERBUFFER, rbo); // now actually attach it
    // now that we actually created the framebuffer and added all attachments we want to check if it is actually complete now
    if (gl.checkFramebufferStatus(gl.FRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE)
        std.debug.print("ERROR::FRAMEBUFFER:: Framebuffer is not complete!\n", .{});
    gl.bindFramebuffer(gl.FRAMEBUFFER, 0);

    // draw as wireframe
    // gl.polygonMode(gl.FRONT_AND_BACK, gl.LINE);

    // Buffer to store Model matrix
    var model: [16]f32 = undefined;

    // View matrix
    var view: [16]f32 = undefined;

    // // Rear view matrix
    // var rear_view: [16]f32 = undefined;

    // Buffer to store Ortho-projection matrix (in render loop)
    var projection: [16]f32 = undefined;

    // render loop
    // -----------
    while (!window.shouldClose()) {
        // per-frame time logic
        // --------------------
        const current_frame: f32 = @floatCast(glfw.getTime());
        delta_time = current_frame - last_frame;
        last_frame = current_frame;

        // input
        // -----
        processInput(window, delta_time);

        // Store the original camera state
        const original_yaw = camera.yaw;

        // first render pass: mirror texture.
        // bind to framebuffer and draw to color texture as we normally
        // would, but with the view camera reversed.
        // bind to framebuffer and draw scene as we normally would to color texture
        // ------------------------------------------------------------------------
        gl.bindFramebuffer(gl.FRAMEBUFFER, framebuffer);
        gl.enable(gl.DEPTH_TEST); // enable depth testing (is disabled for rendering screen-space quad)

        // make sure we clear the framebuffer's content
        gl.clearColor(0.1, 0.1, 0.1, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        shader.use();

        // TODO: Rotate camera's yaw 180 degrees for rear view framebuffer
        camera.yaw = original_yaw + 180.0;
        camera.updateCameraVectors();
        const mirror_view = camera.getViewMatrix();
        zm.storeMat(&view, mirror_view);
        camera.yaw = original_yaw;
        camera.updateCameraVectors();

        const window_size = window.getSize();
        const aspect_ratio: f32 = @as(f32, @floatFromInt(window_size[0])) / @as(f32, @floatFromInt(window_size[1]));
        const projectionM = zm.perspectiveFovRhGl(math.degreesToRadians(camera.zoom), aspect_ratio, 0.1, 100.0);
        zm.storeMat(&projection, projectionM);

        // Set matrices in shader
        shader.setMat4f("view", view);
        shader.setMat4f("projection", projection);

        // cubes
        gl.bindVertexArray(cubeVAO);
        gl.activeTexture(gl.TEXTURE0);
        gl.bindTexture(gl.TEXTURE_2D, cube_texture);
        zm.storeMat(&model, zm.mul(zm.identity(), zm.translation(-1.0, 0.0, -1.0)));
        shader.setMat4f("model", model);
        gl.drawArrays(gl.TRIANGLES, 0, 36);
        zm.storeMat(&model, zm.mul(zm.identity(), zm.translation(2.0, 0.0, 0.0)));
        shader.setMat4f("model", model);
        gl.drawArrays(gl.TRIANGLES, 0, 36);
        // floor
        gl.bindVertexArray(planeVAO);
        gl.bindTexture(gl.TEXTURE_2D, floor_texture);
        zm.storeMat(&model, zm.identity());
        shader.setMat4f("model", model);
        gl.drawArrays(gl.TRIANGLES, 0, 6);
        gl.bindVertexArray(0);

        // second render pass: draw as normal
        // ----------------------------------
        gl.bindFramebuffer(gl.FRAMEBUFFER, 0);

        gl.clearColor(0.1, 0.1, 0.1, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        const normal_view = camera.getViewMatrix();
        zm.storeMat(&view, normal_view);
        shader.setMat4f("view", view);

        // cubes
        gl.bindVertexArray(cubeVAO);
        gl.activeTexture(gl.TEXTURE0);
        gl.bindTexture(gl.TEXTURE_2D, cube_texture);
        zm.storeMat(&model, zm.mul(zm.identity(), zm.translation(-1.0, 0.0, -1.0)));
        shader.setMat4f("model", model);
        gl.drawArrays(gl.TRIANGLES, 0, 36);
        zm.storeMat(&model, zm.mul(zm.identity(), zm.translation(2.0, 0.0, 0.0)));
        shader.setMat4f("model", model);
        gl.drawArrays(gl.TRIANGLES, 0, 36);
        // floor
        gl.bindVertexArray(planeVAO);
        gl.bindTexture(gl.TEXTURE_2D, floor_texture);
        zm.storeMat(&model, zm.identity());
        shader.setMat4f("model", model);
        gl.drawArrays(gl.TRIANGLES, 0, 6);
        gl.bindVertexArray(0);

        // now draw the mirror quad with screen texture
        // --------------------------------------------
        gl.disable(gl.DEPTH_TEST); // disable depth test so screen-space quad isn't discarded due to depth test.

        screenShader.use();
        gl.bindVertexArray(quadVAO);
        // use the color attachment texture as the texture of the quad plane
        gl.bindTexture(gl.TEXTURE_2D, textureColorbuffer);
        gl.drawArrays(gl.TRIANGLES, 0, 6);

        // glfw: swap buffers and poll IO events (keys pressed/released, mouse moved etc.)
        // -------------------------------------------------------------------------------
        window.swapBuffers();
        glfw.pollEvents();
    }
}

fn framebuffer_size_callback(window: *glfw.Window, width: i32, height: i32) callconv(.C) void {
    _ = &window;
    gl.viewport(0, 0, width, height);
}

fn processInput(window: *glfw.Window, deltaTime: f32) void {
    if (window.getKey(.escape) == .press) {
        window.setShouldClose(true);
    }

    camera.speed_modifier = if (window.getKey(.left_shift) == .press) 3.0 else 1.0;

    if (window.getKey(.w) == .press) {
        camera.processKeyboard(.FORWARD, deltaTime);
    }
    if (window.getKey(.a) == .press) {
        camera.processKeyboard(.LEFT, deltaTime);
    }
    if (window.getKey(.s) == .press) {
        camera.processKeyboard(.BACKWARD, deltaTime);
    }
    if (window.getKey(.d) == .press) {
        camera.processKeyboard(.RIGHT, deltaTime);
    }
}

fn mouse_callback(window: *glfw.Window, xposIn: f64, yposIn: f64) callconv(.C) void {
    _ = &window;
    const xpos: f32 = @floatCast(@trunc(xposIn));
    const ypos: f32 = @floatCast(@trunc(yposIn));

    if (first_mouse) {
        lastX = xpos;
        lastY = ypos;
        first_mouse = false;
    }

    const xoffset = xpos - lastX;
    const yoffset = lastY - ypos; // reversed since y-coordinates go from bottom to top
    lastX = xpos;
    lastY = ypos;

    camera.processMouseMovement(xoffset, yoffset, true);
}

fn scroll_callback(window: *glfw.Window, xoffset: f64, yoffset: f64) callconv(.C) void {
    _ = &window;
    _ = xoffset;

    camera.processMouseScroll(yoffset);
}

fn loadTexture(path: [:0]const u8, textureID: *c_uint) !void {
    // var textureID: gl.Uint = undefined;
    gl.genTextures(1, textureID);

    var texture_image = try zstbi.Image.loadFromFile(path, 0);
    defer texture_image.deinit();

    const format: gl.Enum = switch (texture_image.num_components) {
        1 => gl.RED,
        3 => gl.RGB,
        4 => gl.RGBA,
        else => unreachable,
    };

    std.debug.print("{s} is {}\n", .{ path, format });

    gl.bindTexture(gl.TEXTURE_2D, textureID.*);
    // Generate the textureID
    gl.texImage2D(gl.TEXTURE_2D, 0, format, @as(c_int, @intCast(texture_image.width)), @as(c_int, @intCast(texture_image.height)), 0, format, gl.UNSIGNED_BYTE, @ptrCast(texture_image.data));
    gl.generateMipmap(gl.TEXTURE_2D);

    // set the texture1 wrapping parameters
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT); // set texture wrapping to GL_REPEAT (default wrapping method)
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
    // set textureID filtering parameters
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
}

/// loads a cubemap texture from 6 individual texture faces
/// order:
/// +X (right)
/// -X (left)
/// +Y (top)
/// -Y (bottom)
/// +Z (front)
/// -Z (back)
fn loadCubemap(faces: []const [:0]const u8, textureID: *c_uint) !void {
    // var textureID: gl.Uint = undefined;
    gl.genTextures(1, textureID);
    gl.bindTexture(gl.TEXTURE_CUBE_MAP, textureID.*);

    for (faces, 0..) |face, i| {
        var texture_image = try zstbi.Image.loadFromFile(face, 0);
        defer texture_image.deinit();

        const format: gl.Enum = switch (texture_image.num_components) {
            1 => gl.RED,
            3 => gl.RGB,
            4 => gl.RGBA,
            else => unreachable,
        };

        // Generate the textureID
        gl.texImage2D(gl.TEXTURE_CUBE_MAP_POSITIVE_X + @as(c_uint, @intCast(i)), 0, format, @as(c_int, @intCast(texture_image.width)), @as(c_int, @intCast(texture_image.height)), 0, format, gl.UNSIGNED_BYTE, @ptrCast(texture_image.data));
        gl.generateMipmap(gl.TEXTURE_2D);
    }

    // std.debug.print("{s} is {}\n", .{path, format});

    // set the texture1 wrapping parameters

    gl.texParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_WRAP_R, gl.CLAMP_TO_EDGE);
}
