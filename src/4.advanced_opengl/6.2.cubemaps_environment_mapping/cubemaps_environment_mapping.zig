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
const camera_pos = zm.loadArr3(.{ 0.0, 0.0, 5.0 });
var lastX: f64 = 0.0;
var lastY: f64 = 0.0;
var first_mouse = true;
var camera = Camera.init(camera_pos);

// Timing
var delta_time: f32 = 0.0;
var last_frame: f32 = 0.0;

// lighting
var light_position = [_]f32{4.2, 2.0, 4.0};

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
    _ = window.setCursorPosCallback(mouse_callback);
    _ = window.setScrollCallback(scroll_callback);
    _ = window.setFramebufferSizeCallback(framebuffer_size_callback);
    try window.setInputMode(.cursor, glfw.Cursor.Mode.disabled);
    try zopengl.loadCoreProfile(glfw.getProcAddress, @intCast(config.gl_major), @intCast(config.gl_minor));

    glfw.swapInterval(1);

    // configure global opengl state
    // -----------------------------
    gl.enable(gl.DEPTH_TEST);

    // create shader program
    var shader: Shader = Shader.create(arena, "src/4.advanced_opengl/6.2.cubemaps_environment_mapping/6.2.cubemaps.vs", "src/4.advanced_opengl/6.2.cubemaps_environment_mapping/6.2.cubemaps.fs");
    var skybox_shader: Shader = Shader.create(arena, "src/4.advanced_opengl/6.2.cubemaps_environment_mapping/6.2.skybox.vs", "src/4.advanced_opengl/6.2.cubemaps_environment_mapping/6.2.skybox.fs");

    const cubeVertices = [_]gl.Float{
        // positions       // normals
        -0.5, -0.5, -0.5,  0.0,  0.0, -1.0,
         0.5, -0.5, -0.5,  0.0,  0.0, -1.0,
         0.5,  0.5, -0.5,  0.0,  0.0, -1.0,
         0.5,  0.5, -0.5,  0.0,  0.0, -1.0,
        -0.5,  0.5, -0.5,  0.0,  0.0, -1.0,
        -0.5, -0.5, -0.5,  0.0,  0.0, -1.0,

        -0.5, -0.5,  0.5,  0.0,  0.0, 1.0,
         0.5, -0.5,  0.5,  0.0,  0.0, 1.0,
         0.5,  0.5,  0.5,  0.0,  0.0, 1.0,
         0.5,  0.5,  0.5,  0.0,  0.0, 1.0,
        -0.5,  0.5,  0.5,  0.0,  0.0, 1.0,
        -0.5, -0.5,  0.5,  0.0,  0.0, 1.0,

        -0.5,  0.5,  0.5, -1.0,  0.0,  0.0,
        -0.5,  0.5, -0.5, -1.0,  0.0,  0.0,
        -0.5, -0.5, -0.5, -1.0,  0.0,  0.0,
        -0.5, -0.5, -0.5, -1.0,  0.0,  0.0,
        -0.5, -0.5,  0.5, -1.0,  0.0,  0.0,
        -0.5,  0.5,  0.5, -1.0,  0.0,  0.0,

         0.5,  0.5,  0.5,  1.0,  0.0,  0.0,
         0.5,  0.5, -0.5,  1.0,  0.0,  0.0,
         0.5, -0.5, -0.5,  1.0,  0.0,  0.0,
         0.5, -0.5, -0.5,  1.0,  0.0,  0.0,
         0.5, -0.5,  0.5,  1.0,  0.0,  0.0,
         0.5,  0.5,  0.5,  1.0,  0.0,  0.0,

        -0.5, -0.5, -0.5,  0.0, -1.0,  0.0,
         0.5, -0.5, -0.5,  0.0, -1.0,  0.0,
         0.5, -0.5,  0.5,  0.0, -1.0,  0.0,
         0.5, -0.5,  0.5,  0.0, -1.0,  0.0,
        -0.5, -0.5,  0.5,  0.0, -1.0,  0.0,
        -0.5, -0.5, -0.5,  0.0, -1.0,  0.0,

        -0.5,  0.5, -0.5,  0.0,  1.0,  0.0,
         0.5,  0.5, -0.5,  0.0,  1.0,  0.0,
         0.5,  0.5,  0.5,  0.0,  1.0,  0.0,
         0.5,  0.5,  0.5,  0.0,  1.0,  0.0,
        -0.5,  0.5,  0.5,  0.0,  1.0,  0.0,
        -0.5,  0.5, -0.5,  0.0,  1.0,  0.0
    };

    const skyboxVertices = [_]gl.Float{
        // positions          
        -1.0,  1.0, -1.0,
        -1.0, -1.0, -1.0,
         1.0, -1.0, -1.0,
         1.0, -1.0, -1.0,
         1.0,  1.0, -1.0,
        -1.0,  1.0, -1.0,

        -1.0, -1.0,  1.0,
        -1.0, -1.0, -1.0,
        -1.0,  1.0, -1.0,
        -1.0,  1.0, -1.0,
        -1.0,  1.0,  1.0,
        -1.0, -1.0,  1.0,

         1.0, -1.0, -1.0,
         1.0, -1.0,  1.0,
         1.0,  1.0,  1.0,
         1.0,  1.0,  1.0,
         1.0,  1.0, -1.0,
         1.0, -1.0, -1.0,

        -1.0, -1.0,  1.0,
        -1.0,  1.0,  1.0,
         1.0,  1.0,  1.0,
         1.0,  1.0,  1.0,
         1.0, -1.0,  1.0,
        -1.0, -1.0,  1.0,

        -1.0,  1.0, -1.0,
         1.0,  1.0, -1.0,
         1.0,  1.0,  1.0,
         1.0,  1.0,  1.0,
        -1.0,  1.0,  1.0,
        -1.0,  1.0, -1.0,

        -1.0, -1.0, -1.0,
        -1.0, -1.0,  1.0,
         1.0, -1.0, -1.0,
         1.0, -1.0, -1.0,
        -1.0, -1.0,  1.0,
         1.0, -1.0,  1.0
    };

    // cube VAO
    var cubeVAO: gl.Uint = undefined;
    var cubeVBO: gl.Uint = undefined;

    gl.genVertexArrays(1, &cubeVAO);
    defer gl.deleteVertexArrays(1, &cubeVAO);

    gl.genBuffers(1, &cubeVBO);
    defer gl.deleteBuffers(1, &cubeVBO);

    gl.bindBuffer(gl.ARRAY_BUFFER, cubeVBO);
    gl.bufferData(gl.ARRAY_BUFFER, @sizeOf(gl.Float) * cubeVertices.len, &cubeVertices, gl.STATIC_DRAW);
    gl.bindVertexArray(cubeVAO);
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 6 * @sizeOf(gl.Float), null);
    gl.enableVertexAttribArray(1);
    const texture_normal_offset: [*c]c_uint = (3 * @sizeOf(gl.Float));
    gl.vertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 6 * @sizeOf(gl.Float), texture_normal_offset);
    // skybox VAO
    var skyboxVAO: gl.Uint = undefined;
    var skyboxVBO: gl.Uint = undefined;
    gl.genVertexArrays(1, &skyboxVAO);
    defer gl.deleteVertexArrays(1, &skyboxVAO);
    gl.genBuffers(1, &skyboxVBO);
    defer gl.deleteBuffers(1, &skyboxVBO);
    gl.bindVertexArray(skyboxVAO);
    gl.bindBuffer(gl.ARRAY_BUFFER, skyboxVBO);
    gl.bufferData(gl.ARRAY_BUFFER, @sizeOf(gl.Float) * skyboxVertices.len, &skyboxVertices, gl.STATIC_DRAW);
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * @sizeOf(gl.Float), null);

    // zstbi: loading an image.
    zstbi.init(allocator);
    defer zstbi.deinit();

    // load textures
    // -------------
    const faces = &.{
        "resources/textures/skybox/right.jpg",
        "resources/textures/skybox/left.jpg",
        "resources/textures/skybox/top.jpg",
        "resources/textures/skybox/bottom.jpg",
        "resources/textures/skybox/front.jpg",
        "resources/textures/skybox/back.jpg",
    };
    var cube_map_texture: gl.Uint = undefined;
    try loadCubemap(faces, &cube_map_texture);

    // shader configuration
    // --------------------
    shader.use();
    shader.setInt("skybox", 0);

    skybox_shader.use();
    skybox_shader.setInt("skybox", 0);

    // Buffer to store Model matrix
    var model: [16]f32 = undefined;

    // View matrix
    var view: [16]f32 = undefined;

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

        // render
        // ------
        gl.clearColor(0.1, 0.1, 0.1, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        // draw scene as normal
        shader.use();

        zm.storeMat(&model, zm.identity());

        var viewM = camera.getViewMatrix();
        zm.storeMat(&view, viewM);

        // view/projection transformations
        const window_size = window.getSize();
        const aspect_ratio: f32 = @as(f32, @floatFromInt(window_size[0])) / @as(f32, @floatFromInt(window_size[1]));
        const projectionM = zm.perspectiveFovRhGl(math.degreesToRadians(camera.zoom), aspect_ratio, 0.1, 100.0);
        zm.storeMat(&projection, projectionM);
        shader.setMat4f("model", model);
        shader.setMat4f("view", view);
        shader.setMat4f("projection",  projection);
        shader.setVec3f("cameraPos", camera.getViewPos());

        // cubes
        gl.bindVertexArray(cubeVAO);
        gl.activeTexture(gl.TEXTURE0);
        gl.bindTexture(gl.TEXTURE_CUBE_MAP, cube_map_texture);
        gl.drawArrays(gl.TRIANGLES, 0, 36);
        gl.bindVertexArray(0);

        // draw skybox as last
        gl.depthFunc(gl.LEQUAL);  // change depth function so depth test passes when values are equal to depth buffer's content
        skybox_shader.use();
        viewM = zm.loadMat34(&view);
        zm.storeMat(&view, viewM);
        skybox_shader.setMat4f("view", view);
        skybox_shader.setMat4f("projection", projection);

        // skybox cube
        gl.bindVertexArray(skyboxVAO);
        gl.activeTexture(gl.TEXTURE0);
        gl.bindTexture(gl.TEXTURE_CUBE_MAP, cube_map_texture);
        gl.drawArrays(gl.TRIANGLES, 0, 36);
        gl.bindVertexArray(0);
        gl.depthFunc(gl.LESS); // set depth function back to default

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

    if (first_mouse)
    {
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

    std.debug.print("{s} is {}\n", .{path, format});

    gl.bindTexture(gl.TEXTURE_2D, textureID.*);
    // Generate the textureID
    gl.texImage2D(
        gl.TEXTURE_2D, 
        0, 
        format, 
        @as(c_int, @intCast(texture_image.width)), 
        @as(c_int, @intCast(texture_image.height)), 
        0, 
        format, 
        gl.UNSIGNED_BYTE, 
        @ptrCast(texture_image.data));
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
        gl.texImage2D(
            gl.TEXTURE_CUBE_MAP_POSITIVE_X + @as(c_uint, @intCast(i)), 
            0, 
            format, 
            @as(c_int, @intCast(texture_image.width)), 
            @as(c_int, @intCast(texture_image.height)), 
            0, 
            format, 
            gl.UNSIGNED_BYTE, 
            @ptrCast(texture_image.data));
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