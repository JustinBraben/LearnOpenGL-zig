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

var gammaEnabled = false;
var gammaKeyPressed = false;

// Camera
const camera_pos = zm.loadArr3(.{ 0.0, 0.0, 5.0 });
var lastX: f64 = 0.0;
var lastY: f64 = 0.0;
var first_mouse = true;
var camera = Camera.init(camera_pos);

// Timing
var delta_time: f32 = 0.0;
var last_frame: f32 = 0.0;

var planeVAO: gl.Uint = undefined;

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

    // build and compile shaders
    // -------------------------
    var simpleDepthShader = try Shader.create(
        arena,
        "src/5.advanced_lighting/3.1.1.shadow_mapping_depth/3.1.1.shadow_mapping_depth.vs",
        "src/5.advanced_lighting/3.1.1.shadow_mapping_depth/3.1.1.shadow_mapping_depth.fs",
    );
    var debugDepthQuad = try Shader.create(
        arena,
        "src/5.advanced_lighting/3.1.1.shadow_mapping_depth/3.1.1.debug_quad.vs",
        "src/5.advanced_lighting/3.1.1.shadow_mapping_depth/3.1.1.debug_quad_depth.fs",
    );

    // set up vertex data (and buffer(s)) and configure vertex attributes
    // ------------------------------------------------------------------
    const planeVertices = [_]gl.Float{
        // positions            // normals         // texcoords
         25.0, -0.5,  25.0,  0.0, 1.0, 0.0,  25.0,  0.0,
        -25.0, -0.5,  25.0,  0.0, 1.0, 0.0,   0.0,  0.0,
        -25.0, -0.5, -25.0,  0.0, 1.0, 0.0,   0.0, 25.0,

         25.0, -0.5,  25.0,  0.0, 1.0, 0.0,  25.0,  0.0,
        -25.0, -0.5, -25.0,  0.0, 1.0, 0.0,   0.0, 25.0,
         25.0, -0.5, -25.0,  0.0, 1.0, 0.0,  25.0, 25.0
    };

    // cube VAO
    var planeVBO: gl.Uint = undefined;

    gl.genVertexArrays(1, &planeVAO);
    defer gl.deleteVertexArrays(1, &planeVAO);

    gl.genBuffers(1, &planeVBO);
    defer gl.deleteBuffers(1, &planeVBO);

    gl.bindBuffer(gl.ARRAY_BUFFER, planeVBO);
    gl.bufferData(gl.ARRAY_BUFFER, @sizeOf(gl.Float) * planeVertices.len, &planeVertices, gl.STATIC_DRAW);
    gl.bindVertexArray(planeVAO);
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 8 * @sizeOf(gl.Float), null);
    gl.enableVertexAttribArray(1);
    const normal_offset: [*c]c_uint = (3 * @sizeOf(gl.Float));
    gl.vertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 8 * @sizeOf(gl.Float), normal_offset);
    gl.enableVertexAttribArray(2);
    const tex_offset: [*c]c_uint = (6 * @sizeOf(gl.Float));
    gl.vertexAttribPointer(2, 2, gl.FLOAT, gl.FALSE, 8 * @sizeOf(gl.Float), tex_offset);
    gl.enableVertexAttribArray(0);

    // zstbi: loading an image.
    zstbi.init(allocator);
    defer zstbi.deinit();
    zstbi.setFlipVerticallyOnLoad(true);

    const floor_path: [:0]const u8 = "resources/textures/wood.png";

    // load textures
    // -------------
    var woodTexture: gl.Uint = undefined;
    woodTexture = try loadTexture(floor_path, false);

    // configure depth map FBO
    // -----------------------
    const SHADOW_WIDTH: gl.Uint = 1024; 
    const SHADOW_HEIGHT: gl.Uint = 1024;
    var depthMapFBO: gl.Uint = undefined;
    gl.genFramebuffers(1, &depthMapFBO);
    // create depth texture
    var depthMap: gl.Uint = undefined;
    gl.genTextures(1, &depthMap);
    gl.bindTexture(gl.TEXTURE_2D, depthMap);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.DEPTH_COMPONENT, SHADOW_WIDTH, SHADOW_HEIGHT, 0, gl.DEPTH_COMPONENT, gl.FLOAT, null);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_BORDER);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_BORDER);
    const borderColor = [_]gl.Float{ 1.0, 1.0, 1.0, 1.0 };
    gl.texParameterfv(gl.TEXTURE_2D, gl.TEXTURE_BORDER_COLOR, &borderColor);
    // attach depth texture as FBO's depth buffer
    gl.bindFramebuffer(gl.FRAMEBUFFER, depthMapFBO);
    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT, gl.TEXTURE_2D, depthMap, 0);
    gl.drawBuffer(gl.NONE);
    gl.readBuffer(gl.NONE);
    const status = gl.checkFramebufferStatus(gl.FRAMEBUFFER);
    if (status != gl.FRAMEBUFFER_COMPLETE) {
        std.debug.print("Framebuffer not complete: {}\n", .{status});
    }
    gl.bindFramebuffer(gl.FRAMEBUFFER, 0);

    // // Buffer to store Model matrix
    // var model: [16]f32 = undefined;
    // // View matrix
    // var view: [16]f32 = undefined;
    // Buffer to store Ortho-projection matrix (in render loop)
    // var projection: [16]f32 = undefined;

    // // store the projection matrix (we only do this once now) (note: we're not using zoom anymore by changing the FoV)
    // const window_size = window.getSize();
    // const aspect_ratio: f32 = @as(f32, @floatFromInt(window_size[0])) / @as(f32, @floatFromInt(window_size[1]));
    // const projectionM = zm.perspectiveFovRhGl(45.0, aspect_ratio, 0.1, 100.0);
    // zm.storeMat(&projection, projectionM);

    // shader configuration
    // --------------------
    debugDepthQuad.use();
    debugDepthQuad.setInt("depthMap", 0);

    // lighting info
    // -------------
    const lightPos: zm.Vec = .{
        -2.0, 4.0, -1.0, 0.0,
    };

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

        // 1. render depth of scene to texture (from light's perspective)
        // --------------------------------------------------------------
        var lightProjection: [16]f32 = undefined;
        var lightView: [16]f32 = undefined;
        var lightSpaceMatrix: [16]f32 = undefined;
        const near_plane: f32 = 1.0;
        const far_plane: f32 = 7.5;
        zm.storeMat(&lightProjection, zm.orthographicOffCenterLh(
            -10.0, // left
            10.0,  // right
            -10.0, // bottom
            10.0,  // top
            near_plane,
            far_plane
        ));
        zm.storeMat(&lightView, zm.lookAtLh(lightPos, .{0.0, 0.0, 0.0, 0.0}, .{0.0, 1.0, 0.0, 0.0}));
        zm.storeMat(&lightSpaceMatrix, zm.mul(zm.matFromArr(lightProjection), zm.matFromArr(lightView)));
        // render scene from light's point of view
        simpleDepthShader.use();
        simpleDepthShader.setMat4f("lightSpaceMatrix", lightSpaceMatrix);

        gl.viewport(0, 0, SHADOW_WIDTH, SHADOW_HEIGHT);
        gl.bindFramebuffer(gl.FRAMEBUFFER, depthMapFBO);
        gl.clear(gl.DEPTH_BUFFER_BIT);
        gl.activeTexture(gl.TEXTURE0);
        gl.bindTexture(gl.TEXTURE_2D, woodTexture);
        renderScene(&simpleDepthShader);
        gl.bindFramebuffer(gl.FRAMEBUFFER, 0);

        // reset viewport
        gl.viewport(0, 0, config.width, config.height);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        // render Depth map to quad for visual debugging
        // ---------------------------------------------
        debugDepthQuad.use();
        debugDepthQuad.setFloat("near_plane", near_plane);
        debugDepthQuad.setFloat("far_plane", far_plane);
        // gl.activeTexture(gl.TEXTURE0);
        // gl.bindTexture(gl.TEXTURE_2D, depthMap);
        renderQuad();

        // glfw: swap buffers and poll IO events (keys pressed/released, mouse moved etc.)
        // -------------------------------------------------------------------------------
        window.swapBuffers();
        glfw.pollEvents();
    }
}

// renders the 3D scene
// --------------------
fn renderScene(shader: *const Shader) void {
    // floor
    var model: [16]f32 = undefined;
    zm.storeMat(&model, zm.identity());
    shader.setMat4f("model", model);
    gl.bindVertexArray(planeVAO);
    gl.drawArrays(gl.TRIANGLES, 0, 6);
    // cubes
    zm.storeMat(&model, zm.identity());
    zm.storeMat(&model, zm.mul(zm.scaling(0.5, 0.5, 0.5), zm.translation(0.0, 1.5, 0.0)));
    shader.setMat4f("model", model);
    renderCube();
    zm.storeMat(&model, zm.identity());
    zm.storeMat(&model, zm.mul(zm.scaling(0.5, 0.5, 0.5), zm.translation(2.0, 0.0, 1.0)));
    shader.setMat4f("model", model);
    renderCube();
    zm.storeMat(&model, zm.identity());
    zm.storeMat(&model, zm.mul(zm.translation(-1.0, 0.0, 2.0), zm.rotationX(math.degreesToRadians(60.0))));
    // model = glm::rotate(model, glm::radians(60.0f), glm::normalize(glm::vec3(1.0, 0.0, 1.0)));
    zm.storeMat(&model, zm.mul(zm.matFromArr(model), zm.scaling(0.25, 0.25, 0.25)));
    // model = glm::scale(model, glm::vec3(0.25));
    shader.setMat4f("model", model);
    renderCube();
}

// renderCube() renders a 1x1 3D cube in NDC.
// -------------------------------------------------
var cubeVAO: gl.Uint = 0;
var cubeVBO: gl.Uint = 0;
fn renderCube() void {
    // initialize (if necessary)
    if (cubeVAO == 0)
    {
        const vertices = [_]f32{
            // back face
            -1.0, -1.0, -1.0,  0.0,  0.0, -1.0, 0.0, 0.0, // bottom-left
             1.0,  1.0, -1.0,  0.0,  0.0, -1.0, 1.0, 1.0, // top-right
             1.0, -1.0, -1.0,  0.0,  0.0, -1.0, 1.0, 0.0, // bottom-right         
             1.0,  1.0, -1.0,  0.0,  0.0, -1.0, 1.0, 1.0, // top-right
            -1.0, -1.0, -1.0,  0.0,  0.0, -1.0, 0.0, 0.0, // bottom-left
            -1.0,  1.0, -1.0,  0.0,  0.0, -1.0, 0.0, 1.0, // top-left
            // front face
            -1.0, -1.0,  1.0,  0.0,  0.0,  1.0, 0.0, 0.0, // bottom-left
             1.0, -1.0,  1.0,  0.0,  0.0,  1.0, 1.0, 0.0, // bottom-right
             1.0,  1.0,  1.0,  0.0,  0.0,  1.0, 1.0, 1.0, // top-right
             1.0,  1.0,  1.0,  0.0,  0.0,  1.0, 1.0, 1.0, // top-right
            -1.0,  1.0,  1.0,  0.0,  0.0,  1.0, 0.0, 1.0, // top-left
            -1.0, -1.0,  1.0,  0.0,  0.0,  1.0, 0.0, 0.0, // bottom-left
            // left face
            -1.0,  1.0,  1.0, -1.0,  0.0,  0.0, 1.0, 0.0, // top-right
            -1.0,  1.0, -1.0, -1.0,  0.0,  0.0, 1.0, 1.0, // top-left
            -1.0, -1.0, -1.0, -1.0,  0.0,  0.0, 0.0, 1.0, // bottom-left
            -1.0, -1.0, -1.0, -1.0,  0.0,  0.0, 0.0, 1.0, // bottom-left
            -1.0, -1.0,  1.0, -1.0,  0.0,  0.0, 0.0, 0.0, // bottom-right
            -1.0,  1.0,  1.0, -1.0,  0.0,  0.0, 1.0, 0.0, // top-right
            // right face
             1.0,  1.0,  1.0,  1.0,  0.0,  0.0, 1.0, 0.0, // top-left
             1.0, -1.0, -1.0,  1.0,  0.0,  0.0, 0.0, 1.0, // bottom-right
             1.0,  1.0, -1.0,  1.0,  0.0,  0.0, 1.0, 1.0, // top-right         
             1.0, -1.0, -1.0,  1.0,  0.0,  0.0, 0.0, 1.0, // bottom-right
             1.0,  1.0,  1.0,  1.0,  0.0,  0.0, 1.0, 0.0, // top-left
             1.0, -1.0,  1.0,  1.0,  0.0,  0.0, 0.0, 0.0, // bottom-left     
            // bottom face
            -1.0, -1.0, -1.0,  0.0, -1.0,  0.0, 0.0, 1.0, // top-right
             1.0, -1.0, -1.0,  0.0, -1.0,  0.0, 1.0, 1.0, // top-left
             1.0, -1.0,  1.0,  0.0, -1.0,  0.0, 1.0, 0.0, // bottom-left
             1.0, -1.0,  1.0,  0.0, -1.0,  0.0, 1.0, 0.0, // bottom-left
            -1.0, -1.0,  1.0,  0.0, -1.0,  0.0, 0.0, 0.0, // bottom-right
            -1.0, -1.0, -1.0,  0.0, -1.0,  0.0, 0.0, 1.0, // top-right
            // top face
            -1.0,  1.0, -1.0,  0.0,  1.0,  0.0, 0.0, 1.0, // top-left
             1.0,  1.0 , 1.0,  0.0,  1.0,  0.0, 1.0, 0.0, // bottom-right
             1.0,  1.0, -1.0,  0.0,  1.0,  0.0, 1.0, 1.0, // top-right     
             1.0,  1.0,  1.0,  0.0,  1.0,  0.0, 1.0, 0.0, // bottom-right
            -1.0,  1.0, -1.0,  0.0,  1.0,  0.0, 0.0, 1.0, // top-left
            -1.0,  1.0,  1.0,  0.0,  1.0,  0.0, 0.0, 0.0  // bottom-left        
        };
        gl.genVertexArrays(1, &cubeVAO);
        gl.genBuffers(1, &cubeVBO);
        // fill buffer
        gl.bindBuffer(gl.ARRAY_BUFFER, cubeVBO);
        gl.bufferData(gl.ARRAY_BUFFER, @sizeOf(gl.Float) * vertices.len, &vertices, gl.STATIC_DRAW);
        // link vertex attributes
        gl.bindVertexArray(cubeVAO);
        gl.enableVertexAttribArray(0);
        gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 8 * @sizeOf(gl.Float), null);
        gl.enableVertexAttribArray(1);
        const normal_offset: [*c]c_uint = (3 * @sizeOf(gl.Float));
        gl.vertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 8 * @sizeOf(gl.Float), normal_offset);
        gl.enableVertexAttribArray(2);
        const tex_offset: [*c]c_uint = (6 * @sizeOf(gl.Float));
        gl.vertexAttribPointer(2, 2, gl.FLOAT, gl.FALSE, 8 * @sizeOf(gl.Float), tex_offset);
        gl.bindBuffer(gl.ARRAY_BUFFER, 0);
        gl.bindVertexArray(0);
    }
    // render Cube
    gl.bindVertexArray(cubeVAO);
    gl.drawArrays(gl.TRIANGLES, 0, 36);
    gl.bindVertexArray(0);
}

// renderQuad() renders a 1x1 XY quad in NDC
// -----------------------------------------
var quadVAO: gl.Uint = 0;
var quadVBO: gl.Uint = 0;
fn renderQuad() void {
    if (quadVAO == 0)
    {
        const quadVertices = [_]f32{
            // positions     // texture Coords
            -1.0,  1.0, 0.0, 0.0, 1.0,
            -1.0, -1.0, 0.0, 0.0, 0.0,
             1.0,  1.0, 0.0, 1.0, 1.0,
             1.0, -1.0, 0.0, 1.0, 0.0,
        };
        // setup plane VAO
        gl.genVertexArrays(1, &quadVAO);
        gl.genBuffers(1, &quadVBO);
        gl.bindVertexArray(quadVAO);
        gl.bindBuffer(gl.ARRAY_BUFFER, quadVBO);
        gl.bufferData(gl.ARRAY_BUFFER, @sizeOf(gl.Float) * quadVertices.len, &quadVertices, gl.STATIC_DRAW);
        gl.enableVertexAttribArray(0);
        gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 5 * @sizeOf(gl.Float), null);
        gl.enableVertexAttribArray(1);
        const tex_offset: [*c]c_uint = (3 * @sizeOf(gl.Float));
        gl.vertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 5 * @sizeOf(gl.Float), tex_offset);
    }
    gl.bindVertexArray(quadVAO);
    gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
    gl.bindVertexArray(0);
}


fn framebuffer_size_callback(window: *glfw.Window, width: i32, height: i32) callconv(.C) void {
    _ = &window;
    // make sure the viewport matches the new window dimensions; note that width and 
    // height will be significantly larger than specified on retina displays.
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

    if (window.getKey(.space) == .press and !gammaKeyPressed) {
        gammaEnabled = !gammaEnabled;
        gammaKeyPressed = true;
    }
    if (window.getKey(.space) == .release) {
        gammaKeyPressed = false;
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

fn loadTexture(path: [:0]const u8, gammaCorrection: bool) !gl.Uint {
    var textureID: c_uint = undefined;
    gl.genTextures(1, &textureID);

    var texture_image = try zstbi.Image.loadFromFile(path, 0);
    defer texture_image.deinit();

    const internalFormat: gl.Enum = switch (texture_image.num_components) {
        1 => gl.RED,
        3 => if (gammaCorrection) gl.SRGB else gl.RGB,
        4 => if (gammaCorrection) gl.SRGB_ALPHA else gl.RGBA,
        else => unreachable,
    };

    const dataFormat: gl.Enum = switch (texture_image.num_components) {
        1 => gl.RED,
        3 => gl.RGB,
        4 => gl.RGBA,
        else => unreachable,
    };

    std.debug.print("{s} is {}\n", .{ path, internalFormat });

    gl.bindTexture(gl.TEXTURE_2D, textureID);
    // Generate the textureID
    gl.texImage2D(gl.TEXTURE_2D, 0, internalFormat, @as(c_int, @intCast(texture_image.width)), @as(c_int, @intCast(texture_image.height)), 0, dataFormat, gl.UNSIGNED_BYTE, @ptrCast(texture_image.data));
    gl.generateMipmap(gl.TEXTURE_2D);

    // set the texture1 wrapping parameters
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
    // set textureID filtering parameters
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);

    return textureID;
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
