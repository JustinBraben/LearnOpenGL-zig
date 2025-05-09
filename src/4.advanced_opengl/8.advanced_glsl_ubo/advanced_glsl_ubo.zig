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
    var shader_red = try Shader.create(arena, "src/4.advanced_opengl/8.advanced_glsl_ubo/8.advanced_glsl.vs", "src/4.advanced_opengl/8.advanced_glsl_ubo/8.red.fs");
    var shader_green = try Shader.create(arena, "src/4.advanced_opengl/8.advanced_glsl_ubo/8.advanced_glsl.vs", "src/4.advanced_opengl/8.advanced_glsl_ubo/8.green.fs");
    var shader_blue = try Shader.create(arena, "src/4.advanced_opengl/8.advanced_glsl_ubo/8.advanced_glsl.vs", "src/4.advanced_opengl/8.advanced_glsl_ubo/8.blue.fs");
    var shader_yellow = try Shader.create(arena, "src/4.advanced_opengl/8.advanced_glsl_ubo/8.advanced_glsl.vs", "src/4.advanced_opengl/8.advanced_glsl_ubo/8.yellow.fs");

    const cubeVertices = [_]gl.Float{
        // positions         
        -0.5, -0.5, -0.5, 
         0.5, -0.5, -0.5,  
         0.5,  0.5, -0.5,  
         0.5,  0.5, -0.5,  
        -0.5,  0.5, -0.5, 
        -0.5, -0.5, -0.5, 

        -0.5, -0.5,  0.5, 
         0.5, -0.5,  0.5,  
         0.5,  0.5,  0.5,  
         0.5,  0.5,  0.5,  
        -0.5,  0.5,  0.5, 
        -0.5, -0.5,  0.5, 

        -0.5,  0.5,  0.5, 
        -0.5,  0.5, -0.5, 
        -0.5, -0.5, -0.5, 
        -0.5, -0.5, -0.5, 
        -0.5, -0.5,  0.5, 
        -0.5,  0.5,  0.5, 

         0.5,  0.5,  0.5,  
         0.5,  0.5, -0.5,  
         0.5, -0.5, -0.5,  
         0.5, -0.5, -0.5,  
         0.5, -0.5,  0.5,  
         0.5,  0.5,  0.5,  

        -0.5, -0.5, -0.5, 
         0.5, -0.5, -0.5,  
         0.5, -0.5,  0.5,  
         0.5, -0.5,  0.5,  
        -0.5, -0.5,  0.5, 
        -0.5, -0.5, -0.5, 

        -0.5,  0.5, -0.5, 
         0.5,  0.5, -0.5,  
         0.5,  0.5,  0.5,  
         0.5,  0.5,  0.5,  
        -0.5,  0.5,  0.5, 
        -0.5,  0.5, -0.5, 
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
    gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * @sizeOf(gl.Float), null);

    // configure a uniform buffer object
    // ---------------------------------
    // first. We get the relevant block indices
    var uniformBlockIndexRed: gl.Uint = undefined;
    var uniformBlockIndexGreen: gl.Uint = undefined;
    var uniformBlockIndexBlue: gl.Uint = undefined;
    var uniformBlockIndexYellow: gl.Uint = undefined;
    uniformBlockIndexRed = gl.getUniformBlockIndex(shader_red.ID, "Matrices");
    uniformBlockIndexGreen = gl.getUniformBlockIndex(shader_green.ID, "Matrices");
    uniformBlockIndexBlue = gl.getUniformBlockIndex(shader_blue.ID, "Matrices");
    uniformBlockIndexYellow = gl.getUniformBlockIndex(shader_yellow.ID, "Matrices");
    // then we link each shader's uniform block to this uniform binding point
    gl.uniformBlockBinding(shader_red.ID, uniformBlockIndexRed, 0);
    gl.uniformBlockBinding(shader_green.ID, uniformBlockIndexGreen, 0);
    gl.uniformBlockBinding(shader_blue.ID, uniformBlockIndexBlue, 0);
    gl.uniformBlockBinding(shader_yellow.ID, uniformBlockIndexYellow, 0);
    // Now actually create the buffer
    var uboMatrices: gl.Uint = undefined;
    gl.genBuffers(1, &uboMatrices);
    gl.bindBuffer(gl.UNIFORM_BUFFER, uboMatrices);
    gl.bufferData(gl.UNIFORM_BUFFER, 2 * @sizeOf(zm.Mat), null, gl.STATIC_DRAW);
    gl.bindBuffer(gl.UNIFORM_BUFFER, 0);
    // define the range of the buffer that links to a uniform binding point
    gl.bindBufferRange(gl.UNIFORM_BUFFER, 0, uboMatrices, 0, 2 * @sizeOf(zm.Mat));

    // Buffer to store Model matrix
    var model: [16]f32 = undefined;
    // View matrix
    var view: [16]f32 = undefined;
    // Buffer to store Ortho-projection matrix (in render loop)
    var projection: [16]f32 = undefined;

    // store the projection matrix (we only do this once now) (note: we're not using zoom anymore by changing the FoV)
    const window_size = window.getSize();
    const aspect_ratio: f32 = @as(f32, @floatFromInt(window_size[0])) / @as(f32, @floatFromInt(window_size[1]));
    const projectionM = zm.perspectiveFovRhGl(45.0, aspect_ratio, 0.1, 100.0);
    zm.storeMat(&projection, projectionM);
    gl.bindBuffer(gl.UNIFORM_BUFFER, uboMatrices);
    gl.bufferSubData(gl.UNIFORM_BUFFER, 0, @sizeOf(zm.Mat), &projection);
    gl.bindBuffer(gl.UNIFORM_BUFFER, 0);

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


        zm.storeMat(&model, zm.identity());

        // set the view and projection matrix in the uniform block - we only have to do this once per loop iteration.
        zm.storeMat(&view, camera.getViewMatrix());
        gl.bindBuffer(gl.UNIFORM_BUFFER, uboMatrices);
        gl.bufferSubData(gl.UNIFORM_BUFFER, @sizeOf(zm.Mat), @sizeOf(zm.Mat), &view);
        gl.bindBuffer(gl.UNIFORM_BUFFER, 0);

        // draw 4 cubes 
        // RED
        gl.bindVertexArray(cubeVAO);
        shader_red.use();
        zm.storeMat(&model, zm.translation(-0.75, 0.75, 0.0)); // move top-left
        shader_red.setMat4f("model", model);
        gl.drawArrays(gl.TRIANGLES, 0, 36);
        // GREEN
        shader_green.use();
        zm.storeMat(&model, zm.translation(0.75, 0.75, 0.0)); // move top-right
        shader_green.setMat4f("model", model);
        gl.drawArrays(gl.TRIANGLES, 0, 36);
        // YELLOW
        shader_yellow.use();
        zm.storeMat(&model, zm.translation(-0.75, -0.75, 0.0)); // move bottom-left
        shader_yellow.setMat4f("model", model);
        gl.drawArrays(gl.TRIANGLES, 0, 36);
        // BLUE
        shader_blue.use();
        zm.storeMat(&model, zm.translation(0.75, -0.75, 0.0)); // move bottom-right
        shader_blue.setMat4f("model", model);
        gl.drawArrays(gl.TRIANGLES, 0, 36);

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