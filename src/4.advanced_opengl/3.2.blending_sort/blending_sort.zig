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

// lighting
var light_position = [_]f32{4.2, 2.0, 4.0};

// Needed for HashMap with key f32
const FloatContext = struct {
    pub fn hash(_: @This(), key: f32) u64 {
        // Convert float bits to u32 for hashing
        const bits = @as(u32, @bitCast(key));
        return std.hash.Wyhash.hash(0, std.mem.asBytes(&bits));
    }

    pub fn eql(_: @This(), a: f32, b: f32) bool {
        return a == b;
    }
};


pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var arena_allocator_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_allocator_state.deinit();
    const arena = arena_allocator_state.allocator();

    const config: ConfigOptions = .{};

    try glfw.init();
    defer glfw.terminate();

    glfw.windowHintTyped(.context_version_major, config.gl_major);
    glfw.windowHintTyped(.context_version_minor, config.gl_minor);
    glfw.windowHintTyped(.opengl_profile, .opengl_core_profile);
    glfw.windowHintTyped(.opengl_forward_compat, true);
    glfw.windowHintTyped(.client_api, .opengl_api);
    glfw.windowHintTyped(.doublebuffer, true);

    var window = glfw.Window.create(config.width, config.height, "LearnOpenGL", null) catch |e| {
        std.io.getStdErr().writer().print("Failed to create GLFW window\n", .{}) catch {};
        return e;
    };
    defer window.destroy();

    glfw.makeContextCurrent(window);
    _ = window.setCursorPosCallback(mouse_callback);
    _ = window.setScrollCallback(scroll_callback);
    _ = window.setFramebufferSizeCallback(framebuffer_size_callback);
    window.setInputMode(.cursor, glfw.Cursor.Mode.disabled);
    try zopengl.loadCoreProfile(glfw.getProcAddress, @intCast(config.gl_major), @intCast(config.gl_minor));

    glfw.swapInterval(1);

    // configure global opengl state
    // -----------------------------
    gl.enable(gl.DEPTH_TEST);
    gl.enable(gl.BLEND);
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

    // build and compile shaders
    // -------------------------
    var shader: Shader = Shader.create(arena, "src/4.advanced_opengl/3.2.blending_sort/3.2.blending.vs", "src/4.advanced_opengl/3.2.blending_sort/3.2.blending.fs");

    const cube_vertices = [_]gl.Float{
        // positions       // texture Coords
        -0.5, -0.5, -0.5,  0.0, 0.0,
         0.5, -0.5, -0.5,  1.0, 0.0,
         0.5,  0.5, -0.5,  1.0, 1.0,
         0.5,  0.5, -0.5,  1.0, 1.0,
        -0.5,  0.5, -0.5,  0.0, 1.0,
        -0.5, -0.5, -0.5,  0.0, 0.0,

        -0.5, -0.5,  0.5,  0.0, 0.0,
         0.5, -0.5,  0.5,  1.0, 0.0,
         0.5,  0.5,  0.5,  1.0, 1.0,
         0.5,  0.5,  0.5,  1.0, 1.0,
        -0.5,  0.5,  0.5,  0.0, 1.0,
        -0.5, -0.5,  0.5,  0.0, 0.0,

        -0.5,  0.5,  0.5,  1.0, 0.0,
        -0.5,  0.5, -0.5,  1.0, 1.0,
        -0.5, -0.5, -0.5,  0.0, 1.0,
        -0.5, -0.5, -0.5,  0.0, 1.0,
        -0.5, -0.5,  0.5,  0.0, 0.0,
        -0.5,  0.5,  0.5,  1.0, 0.0,

         0.5,  0.5,  0.5,  1.0, 0.0,
         0.5,  0.5, -0.5,  1.0, 1.0,
         0.5, -0.5, -0.5,  0.0, 1.0,
         0.5, -0.5, -0.5,  0.0, 1.0,
         0.5, -0.5,  0.5,  0.0, 0.0,
         0.5,  0.5,  0.5,  1.0, 0.0,

        -0.5, -0.5, -0.5,  0.0, 1.0,
         0.5, -0.5, -0.5,  1.0, 1.0,
         0.5, -0.5,  0.5,  1.0, 0.0,
         0.5, -0.5,  0.5,  1.0, 0.0,
        -0.5, -0.5,  0.5,  0.0, 0.0,
        -0.5, -0.5, -0.5,  0.0, 1.0,

        -0.5,  0.5, -0.5,  0.0, 1.0,
         0.5,  0.5, -0.5,  1.0, 1.0,
         0.5,  0.5,  0.5,  1.0, 0.0,
         0.5,  0.5,  0.5,  1.0, 0.0,
        -0.5,  0.5,  0.5,  0.0, 0.0,
        -0.5,  0.5, -0.5,  0.0, 1.0
    };

    const plane_vertices = [_]gl.Float{
        // positions       // texture Coords
        5.0, -0.5,  5.0,   2.0, 0.0,
        -5.0, -0.5,  5.0,  0.0, 0.0,
        -5.0, -0.5, -5.0,  0.0, 2.0,

        5.0, -0.5,  5.0,   2.0, 0.0,
        -5.0, -0.5, -5.0,  0.0, 2.0,
        5.0, -0.5, -5.0,   2.0, 2.0		
    };

    const transparent_vertices = [_]gl.Float{
        // positions      // texture Coords (swapped y coordinates because texture is flipped upside down)
        0.0,  0.5,  0.0,  0.0,  0.0,
        0.0, -0.5,  0.0,  0.0,  1.0,
        1.0, -0.5,  0.0,  1.0,  1.0,

        0.0,  0.5,  0.0,  0.0,  0.0,
        1.0, -0.5,  0.0,  1.0,  1.0,
        1.0,  0.5,  0.0,  1.0,  0.0	
    };

    // cube VAO
    var cubeVAO: gl.Uint = undefined;
    var cubeVBO: gl.Uint = undefined;

    gl.genVertexArrays(1, &cubeVAO);
    defer gl.deleteVertexArrays(1, &cubeVAO);

    gl.genBuffers(1, &cubeVBO);
    defer gl.deleteBuffers(1, &cubeVBO);

    gl.bindBuffer(gl.ARRAY_BUFFER, cubeVBO);
    gl.bufferData(gl.ARRAY_BUFFER, @sizeOf(gl.Float) * cube_vertices.len, &cube_vertices, gl.STATIC_DRAW);
    gl.bindVertexArray(cubeVAO);
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 5 * @sizeOf(gl.Float), null);
    gl.enableVertexAttribArray(1);
    const texture_coords_offset: [*c]c_uint = (3 * @sizeOf(gl.Float));
    gl.vertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 5 * @sizeOf(gl.Float), texture_coords_offset);
    gl.bindVertexArray(0);
    // plane VAO
    var planeVAO: gl.Uint = undefined;
    var planeVBO: gl.Uint = undefined;
    gl.genVertexArrays(1, &planeVAO);
    defer gl.deleteVertexArrays(1, &planeVAO);
    gl.genBuffers(1, &planeVBO);
    defer gl.deleteBuffers(1, &planeVBO);
    gl.bindVertexArray(planeVAO);
    gl.bindBuffer(gl.ARRAY_BUFFER, planeVBO);
    gl.bufferData(gl.ARRAY_BUFFER, @sizeOf(gl.Float) * plane_vertices.len, &plane_vertices, gl.STATIC_DRAW);
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 5 * @sizeOf(gl.Float), null);
    gl.enableVertexAttribArray(1);
    gl.vertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 5 * @sizeOf(gl.Float), texture_coords_offset);
    gl.bindVertexArray(0);
    // transparent VAO
    var transparentVAO: gl.Uint = undefined;
    var transparentVBO: gl.Uint = undefined;
    gl.genVertexArrays(1, &transparentVAO);
    defer gl.deleteVertexArrays(1, &transparentVAO);
    gl.genBuffers(1, &transparentVBO);
    defer gl.deleteBuffers(1, &transparentVBO);
    gl.bindVertexArray(transparentVAO);
    gl.bindBuffer(gl.ARRAY_BUFFER, transparentVBO);
    gl.bufferData(gl.ARRAY_BUFFER, @sizeOf(gl.Float) * transparent_vertices.len, &transparent_vertices, gl.STATIC_DRAW);
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 5 * @sizeOf(gl.Float), null);
    gl.enableVertexAttribArray(1);
    gl.vertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 5 * @sizeOf(gl.Float), texture_coords_offset);
    gl.bindVertexArray(0);

    // zstbi: loading an image.
    zstbi.init(allocator);
    defer zstbi.deinit();

    // load textures (we now use a utility function to keep the code more organized)
    // -----------------------------------------------------------------------------
    const marble_path = "resources/textures/marble.jpg";
    const metal_path = "resources/textures/metal.png";
    const transparent_path = "resources/textures/window.png";
    var cube_texture: gl.Uint = undefined;
    var floor_texture: gl.Uint = undefined;
    var transparent_texture: gl.Uint = undefined;
    try loadTexture(marble_path, &cube_texture);
    try loadTexture(metal_path, &floor_texture);
    try loadTexture(transparent_path, &transparent_texture);

    // transparent vegetation locations
    // --------------------------------
    const windows = [_][3]gl.Float{
        .{ -1.5, 0.0, -0.48 },
        .{ 1.5, 0.0, 0.51 },
        .{ 0.0, 0.0, 0.7 },
        .{ -0.3, 0.0, -2.3 },
        .{ 0.5, 0.0, -0.6 },
    };

    // shader configuration
    // --------------------
    shader.use();
    shader.setInt("texture1", 0);

    // Buffer to store Model matrix
    var model: [16]f32 = undefined;

    // View matrix
    var view: [16]f32 = undefined;

    // Buffer to store Ortho-projection matrix (in render loop)
    var projection: [16]f32 = undefined;

    // var sorted = std.HashMap(f32, [3]f32, FloatContext, std.hash_map.default_max_load_percentage).init(allocator);
    // defer sorted.deinit();
    // for (windows) |w| {
    //     const distance = zm.length3(camera.position - zm.loadArr3(w));
    //     try sorted.put(distance[0], w);
    //     std.debug.print("k: {d}, v: {d}\n", .{ distance[0], w });
    // }

    // render loop
    // -----------
    while (!window.shouldClose()) {
        // per-frame time logic
        // --------------------
        const current_frame: f32 = @floatCast(glfw.getTime());
        delta_time = current_frame - last_frame;
        last_frame = current_frame;

        // sort the transparent windows before rendering
        // ---------------------------------------------
        var sorted = std.HashMap(f32, [3]f32, FloatContext, std.hash_map.default_max_load_percentage).init(allocator);
        defer sorted.deinit();

        // Create an ArrayList to store the distances for sorting
        var distances = std.ArrayList(f32).init(allocator);
        defer distances.deinit();

        for (windows) |w| {
            const distance = zm.length3(camera.position - zm.loadArr3(w));
            try sorted.put(distance[0], w);
            try distances.append(distance[0]);
        }

        // Sort distances in descending order (furthest first)
        std.mem.sort(f32, distances.items, {}, std.sort.desc(f32));

        // input
        // -----
        processInput(window, delta_time);

        // render
        // ------
        gl.clearColor(0.1, 0.1, 0.1, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        // draw objects
        shader.use();
        zm.storeMat(&model, zm.identity());
        const viewM = camera.getViewMatrix();
        zm.storeMat(&view, viewM);
        const window_size = window.getSize();
        const aspect_ratio: f32 = @as(f32, @floatFromInt(window_size[0])) / @as(f32, @floatFromInt(window_size[1]));
        const projectionM = zm.perspectiveFovRhGl(math.degreesToRadians(camera.zoom), aspect_ratio, 0.1, 100.0);
        zm.storeMat(&projection, projectionM);
        shader.setMat4f("view", view);
        shader.setMat4f("projection", projection);
        // cubes
        const model_translation1 = zm.translation(-1.0, 0.0, -1.0);
        const model_translation2 = zm.translation(2.0, 0.0, 0.0);
        gl.bindVertexArray(cubeVAO);
        gl.activeTexture(gl.TEXTURE0);
        gl.bindTexture(gl.TEXTURE_2D, cube_texture);
        zm.storeMat(&model, zm.mul(zm.identity(), model_translation1));
        shader.setMat4f("model", model);
        gl.drawArrays(gl.TRIANGLES, 0, 36);
        zm.storeMat(&model, zm.mul(zm.identity(), model_translation2));
        shader.setMat4f("model", model);
        gl.drawArrays(gl.TRIANGLES, 0, 36);
        // floor
        gl.bindVertexArray(planeVAO);
        gl.bindTexture(gl.TEXTURE_2D, floor_texture);
        zm.storeMat(&model, zm.identity());
        shader.setMat4f("model",  model);
        gl.drawArrays(gl.TRIANGLES, 0, 6);
        // windows (from furthest to nearest)
        gl.bindVertexArray(transparentVAO);
        gl.bindTexture(gl.TEXTURE_2D, transparent_texture);
        // Now render windows from furthest to nearest using sorted distances
        for (distances.items) |distance| {
            const w = sorted.get(distance).?;
            zm.storeMat(&model, zm.mul(zm.identity(), zm.translation(w[0], w[1], w[2])));
            shader.setMat4f("model", model);
            gl.drawArrays(gl.TRIANGLES, 0, 6);
        }

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
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, if (format == gl.RGBA) gl.CLAMP_TO_EDGE else gl.REPEAT); // for this tutorial: use GL_CLAMP_TO_EDGE to prevent semi-transparent borders. Due to interpolation it takes texels from next repeat 
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, if (format == gl.RGBA) gl.CLAMP_TO_EDGE else gl.REPEAT);
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