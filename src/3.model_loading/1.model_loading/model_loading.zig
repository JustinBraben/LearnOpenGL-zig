const std = @import("std");
const math = std.math;
const glfw = @import("zglfw");
const zopengl = @import("zopengl");
const zstbi = @import("zstbi");
const zm = @import("zmath");
const zmesh = @import("zmesh");
const gl = zopengl.bindings;
const Shader = @import("Shader");
const Camera = @import("Camera");
const obj = @import("obj");
const Model = @import("Model");

pub const ConfigOptions = struct {
    width: i32 = 800,
    height: i32 = 600,
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

    // zstbi: loading an image.
    zstbi.init(allocator);
    defer zstbi.deinit();

    // configure global opengl state
    // -----------------------------
    gl.enable(gl.DEPTH_TEST);

    // build and compile shaders
    // -------------------------
    var our_shader: Shader = Shader.create(arena, "src/3.model_loading/1.model_loading/1.model_loading.vs", "src/3.model_loading/1.model_loading/1.model_loading.fs");

    // load models
    // -----------
    zmesh.init(allocator);
    defer zmesh.deinit();

    const model_obj_path = "resources/objects/backpack/backpack.obj";
    const model_mtl_path = "resources/objects/backpack/backpack.mtl";
    var our_model = try Model.initFromPath(allocator, model_obj_path, model_mtl_path);
    defer our_model.deinit();

    // After creating your cube
    var cube = zmesh.Shape.initCube();
    defer cube.deinit();
    // Unweld the cube to create distinct vertices for each face
    cube.unweld();

    // cube VAO
    var cubeVAO: gl.Uint = undefined;
    var cubeVBO: gl.Uint = undefined;
    var cubeEBO: gl.Uint = undefined;
    gl.genVertexArrays(1, &cubeVAO);
    defer gl.deleteVertexArrays(1, &cubeVAO);
    gl.genBuffers(1, &cubeVBO);
    defer gl.deleteBuffers(1, &cubeVBO);
    gl.genBuffers(1, &cubeEBO);
    defer gl.deleteBuffers(1, &cubeEBO);

    gl.bindVertexArray(cubeVAO);
    // Assuming positions are [3]f32, normals are [3]f32, and texcoords are [2]f32
    // Buffer the position data
    gl.bindBuffer(gl.ARRAY_BUFFER, cubeVBO);
    gl.bufferData(gl.ARRAY_BUFFER, @intCast(cube.positions.len * @sizeOf([3]f32)), cube.positions.ptr, gl.STATIC_DRAW);

    // Set up position attribute
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, @sizeOf([3]f32), null);

    // Buffer the normal data (if available)
    if (cube.normals) |normals| {
        var normalVBO: gl.Uint = undefined;
        gl.genBuffers(1, &normalVBO);
        defer gl.deleteBuffers(1, &normalVBO);
        
        gl.bindBuffer(gl.ARRAY_BUFFER, normalVBO);
        gl.bufferData(gl.ARRAY_BUFFER, @intCast(normals.len * @sizeOf([3]f32)), normals.ptr, gl.STATIC_DRAW);
        
        gl.enableVertexAttribArray(1);
        gl.vertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, @sizeOf([3]f32), null);
    }

    var texcoordVBO: gl.Uint = undefined;
    gl.genBuffers(1, &texcoordVBO);
    defer gl.deleteBuffers(1, &texcoordVBO);
    
    // Create texture coordinates for a cube (6 faces, 4 vertices per face)
    // This is if the cube doesn't have texture coordinates already
    const texcoords = try allocator.alloc([2]f32, cube.positions.len);
    defer allocator.free(texcoords);

    // The cube likely has 36 vertices (6 faces * 2 triangles * 3 vertices)
    // Each face should have consistent texture coordinates
    for (0..6) |face| {
        // For each face, set texture coordinates for 6 vertices (2 triangles)
        const base_idx = face * 6;
        
        // First triangle (bottom-left, bottom-right, top-right)
        texcoords[base_idx + 0] = .{0.0, 0.0}; // bottom-left
        texcoords[base_idx + 1] = .{1.0, 0.0}; // bottom-right
        texcoords[base_idx + 2] = .{1.0, 1.0}; // top-right
        
        // Second triangle (top-right, top-left, bottom-left)
        texcoords[base_idx + 3] = .{1.0, 1.0}; // top-right
        texcoords[base_idx + 4] = .{0.0, 1.0}; // top-left
        texcoords[base_idx + 5] = .{0.0, 0.0}; // bottom-left
    }

    // // Print vertex positions to verify ordering
    // for (cube.positions, 0..) |pos, i| {
    //     std.debug.print("Vertex {d}: ({d:.1}, {d:.1}, {d:.1})\n", 
    //         .{i, pos[0], pos[1], pos[2]});
    // }

    // // Print debug information after computations
    // std.debug.print("Cube stats after processing:\n", .{});
    // std.debug.print("  - Indices: {d}\n", .{cube.indices.len});
    // std.debug.print("  - Positions: {d}\n", .{cube.positions.len});
    // std.debug.print("  - Has normals: {}\n", .{cube.normals != null});
    // std.debug.print("  - Has texcoords: {}\n", .{cube.texcoords != null});

    // // Manually print texture coordinates to verify
    // std.debug.print("Added texcoords. First few: \n", .{});
    // for (texcoords, 0..) |coord, i| {
    //     if (i < 8) std.debug.print("  [{d}]: ({d:.2}, {d:.2})\n", .{i, coord[0], coord[1]});
    // }

    // Then use these texture coordinates in your rendering pipeline
    gl.bindBuffer(gl.ARRAY_BUFFER, texcoordVBO);
    gl.bufferData(gl.ARRAY_BUFFER, @intCast(texcoords.len * @sizeOf([2]f32)), texcoords.ptr, gl.STATIC_DRAW);
    gl.enableVertexAttribArray(2);
    gl.vertexAttribPointer(2, 2, gl.FLOAT, gl.FALSE, @sizeOf([2]f32), null);

    // Buffer the indices
    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, cubeEBO);
    gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, @intCast(cube.indices.len * @sizeOf(zmesh.Shape.IndexType)), cube.indices.ptr, gl.STATIC_DRAW);
    gl.bindVertexArray(0);

    const diffuse_map_path: [:0]const u8 = "resources/textures/container2.png";

    // load textures (we now use a utility function to keep the code more organized)
    // -----------------------------------------------------------------------------
    var diffuse_map_texture: gl.Uint = undefined;
    try loadTexture(diffuse_map_path, &diffuse_map_texture);

    // Buffer to store Model matrix
    var model: [16]f32 = undefined;

    // View matrix
    var view: [16]f32 = undefined;

    // Buffer to store Orojection matrix (in render loop)
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
        gl.clearColor(0.05, 0.05, 0.05, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT); // also clear the depth buffer now!

        // don't forget to enable shader before setting uniforms
        our_shader.use();
        our_shader.setInt("texture_diffuse1", 0);

        // view/projection transformations
        const window_size = window.getSize();
        const aspect_ratio: f32 = @as(f32, @floatFromInt(window_size[0])) / @as(f32, @floatFromInt(window_size[1]));
        const projectionM = zm.perspectiveFovRhGl(math.degreesToRadians(45.0), aspect_ratio, 0.1, 100.0);
        zm.storeMat(&projection, projectionM);
        our_shader.setMat4f("projection", projection);
        const viewM = camera.getViewMatrix();
        zm.storeMat(&view, viewM);
        our_shader.setMat4f("view", view);

        // render the loaded model
        gl.activeTexture(gl.TEXTURE0);
        gl.bindTexture(gl.TEXTURE_2D, diffuse_map_texture);
        gl.bindVertexArray(cubeVAO);
        zm.storeMat(&model, zm.identity());
        our_shader.setMat4f("model",  model);
        // bind diffuse map
        gl.drawElements(gl.TRIANGLES, @intCast(cube.indices.len), gl.UNSIGNED_INT, null);
        gl.bindVertexArray(0);

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

    camera.speed_modifier = if (window.getKey(.left_control) == .press) 3.0 else 1.0;

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