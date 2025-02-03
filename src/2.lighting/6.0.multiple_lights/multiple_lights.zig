const std = @import("std");
const math = std.math;
const glfw = @import("zglfw");
const zopengl = @import("zopengl");
const zstbi = @import("zstbi");
const zm = @import("zmath");
const gl = zopengl.bindings;
const Shader = @import("Shader");
const Camera = @import("Camera");
const common = @import("common");

pub const ConfigOptions = struct {
    width: i32 = 1280,
    height: i32 = 720,
    gl_major: i32 = 4,
    gl_minor: i32 = 1,
};

// Create the transformation matrices:
// Degree to radians conversion factor
const rad_conversion = common.RAD_CONVERSION;

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

    // create shader program
    var lighting_shader: Shader = Shader.create(arena, "assets/6.0.multiple_lights_vert.glsl", "assets/6.0.multiple_lights_frag.glsl");
    var lighting_cube_shader: Shader = Shader.create(arena, "assets/1.1.light_cube_vert.glsl", "assets/1.1.light_cube_frag.glsl");

    // set up vertex data (and buffer(s)) and configure vertex attributes
    // ------------------------------------------------------------------
    const vertices = [_]gl.Float{
        // positions       // normals        // texture coords
        -0.5, -0.5, -0.5,  0.0,  0.0, -1.0,  0.0, 0.0,
        0.5, -0.5, -0.5,   0.0,  0.0, -1.0,  1.0, 0.0,
        0.5,  0.5, -0.5,   0.0,  0.0, -1.0,  1.0, 1.0,
        0.5,  0.5, -0.5,   0.0,  0.0, -1.0,  1.0, 1.0,
        -0.5,  0.5, -0.5,  0.0,  0.0, -1.0,  0.0, 1.0,
        -0.5, -0.5, -0.5,  0.0,  0.0, -1.0,  0.0, 0.0,

        -0.5, -0.5, 0.5,   0.0,  0.0, 1.0,  0.0, 0.0,
        0.5,  -0.5, 0.5,   0.0,  0.0, 1.0,  1.0, 0.0,
        0.5,  0.5,  0.5,   0.0,  0.0, 1.0,  1.0, 1.0,
        0.5,  0.5,  0.5,   0.0,  0.0, 1.0,  1.0, 1.0,
        -0.5, 0.5,  0.5,   0.0,  0.0, 1.0,  0.0, 1.0,
        -0.5, -0.5, 0.5,   0.0,  0.0, 1.0,  0.0, 0.0,

        -0.5, 0.5,  0.5,  -1.0,  0.0, 0.0,  1.0, 0.0,
        -0.5, 0.5,  -0.5, -1.0,  0.0, 0.0,  1.0, 1.0,
        -0.5, -0.5, -0.5, -1.0,  0.0, 0.0,  0.0, 1.0,
        -0.5, -0.5, -0.5, -1.0,  0.0, 0.0,  0.0, 1.0,
        -0.5, -0.5, 0.5,  -1.0,  0.0, 0.0,  0.0, 0.0,
        -0.5, 0.5,  0.5,  -1.0,  0.0, 0.0,  1.0, 0.0,

        0.5,  0.5,  0.5,   1.0,  0.0, 1.0,  1.0, 0.0,
        0.5,  0.5,  -0.5,  1.0,  0.0, 1.0,  1.0, 1.0,
        0.5,  -0.5, -0.5,  1.0,  0.0, 1.0,  0.0, 1.0,
        0.5,  -0.5, -0.5,  1.0,  0.0, 1.0,  0.0, 1.0,
        0.5,  -0.5, 0.5,   1.0,  0.0, 1.0,  0.0, 0.0,
        0.5,  0.5,  0.5,   1.0,  0.0, 1.0,  1.0, 0.0,

        -0.5, -0.5, -0.5,  0.0, -1.0, 0.0,  0.0, 1.0,
        0.5,  -0.5, -0.5,  0.0, -1.0, 0.0,  1.0, 1.0,
        0.5,  -0.5, 0.5,   0.0, -1.0, 0.0,  1.0, 0.0,
        0.5,  -0.5, 0.5,   0.0, -1.0, 0.0,  1.0, 0.0,
        -0.5, -0.5, 0.5,   0.0, -1.0, 0.0,  0.0, 0.0,
        -0.5, -0.5, -0.5,  0.0, -1.0, 0.0,  0.0, 1.0,

        -0.5, 0.5,  -0.5,  0.0,  1.0, 0.0,  0.0, 1.0,
        0.5,  0.5,  -0.5,  0.0,  1.0, 0.0,  1.0, 1.0,
        0.5,  0.5,  0.5,   0.0,  1.0, 0.0,  1.0, 0.0,
        0.5,  0.5,  0.5,   0.0,  1.0, 0.0,  1.0, 0.0,
        -0.5, 0.5,  0.5,   0.0,  1.0, 0.0,  0.0, 0.0,
        -0.5, 0.5,  -0.5,  0.0,  1.0, 0.0,  0.0, 1.0,
    };

    // positions all containers
    // Comment lines to view where each are in the view!
    const cube_positions = [_][3]gl.Float{
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
    // positions of the point lights
    const point_light_positions = [_][3]gl.Float{
        .{ 0.7, 0.2, 2.0 },
        .{ 2.3, -3.3, -4.0 },
        .{ -4.0, 2.0, -12.0 },
        .{ 0.0, 0.0, -3.0 },
    };

    // first, configure the cube's VAO (and VBO)
    var VBO: gl.Uint = undefined;
    var cube_vao: gl.Uint = undefined;

    gl.genVertexArrays(1, &cube_vao);
    defer gl.deleteVertexArrays(1, &cube_vao);

    gl.genBuffers(1, &VBO);
    defer gl.deleteBuffers(1, &VBO);

    // bind the Vertex Array Object first, then bind and set vertex buffer(s), and then configure vertex attributes(s).
    gl.bindBuffer(gl.ARRAY_BUFFER, VBO);
    gl.bufferData(gl.ARRAY_BUFFER, @sizeOf(gl.Float) * vertices.len, &vertices, gl.STATIC_DRAW);

    gl.bindVertexArray(cube_vao);

    // position attribute
    gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 8 * @sizeOf(gl.Float), null);
    gl.enableVertexAttribArray(0);
    // normal attribute
    const normal_offset: [*c]c_uint = (3 * @sizeOf(f32));
    gl.vertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 8 * @sizeOf(gl.Float), normal_offset);
    gl.enableVertexAttribArray(1);
    // texture coords attribute
    const texture_coords_offset: [*c]c_uint = (6 * @sizeOf(f32));
    gl.vertexAttribPointer(2, 2, gl.FLOAT, gl.FALSE, 8 * @sizeOf(gl.Float), texture_coords_offset);
    gl.enableVertexAttribArray(2);

    // second, configure the light's VAO (VBO stays the same; the vertices are the same for the light object which is also a 3D cube)
    var light_cube_vao: gl.Uint = undefined;

    gl.genVertexArrays(1, &light_cube_vao);
    defer gl.deleteVertexArrays(1, &light_cube_vao);
    gl.bindVertexArray(light_cube_vao);

    // we only need to bind to the VBO (to link it with glVertexAttribPointer), no need to fill it; the VBO's data already contains all we need (it's already bound, but we do it again for educational purposes)
    gl.bindBuffer(gl.ARRAY_BUFFER, VBO);
    gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 8 * @sizeOf(gl.Float), null);
    gl.enableVertexAttribArray(0);

    // zstbi: loading an image.
    zstbi.init(allocator);
    defer zstbi.deinit();
    zstbi.setFlipVerticallyOnLoad(true);

    const diffuse_map_path: [:0]const u8 = "assets/container2.png";
    const specular_map_path: [:0]const u8 = "assets/container2_specular.png";

    // load textures (we now use a utility function to keep the code more organized)
    // -----------------------------------------------------------------------------
    var diffuse_map_texture: gl.Uint = undefined;
    var specular_map_texture: gl.Uint = undefined;
    try loadTexture(diffuse_map_path, &diffuse_map_texture);
    try loadTexture(specular_map_path, &specular_map_texture);

    // Buffer to store Model matrix
    var model: [16]f32 = undefined;

    // View matrix
    var view: [16]f32 = undefined;

    // Buffer to store Ortho-projection matrix (in render loop)
    var projection: [16]f32 = undefined;

    // shader configuration
    // --------------------
    lighting_shader.use();
    lighting_shader.setInt("material.diffuse", 0);
    lighting_shader.setInt("material.specular", 1);

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

        // be sure to activate shader when setting uniforms/drawing objects
        lighting_shader.use();
        // lighting_shader.setVec3f("light.position",  camera.getViewPos());
        // lighting_shader.setVec3f("light.direction",  camera.getFrontPos());
        // lighting_shader.setFloat("light.cutOff", math.cos(common.radians(12.5)));
        // lighting_shader.setFloat("light.outerCutOff", math.cos(common.radians(17.5)));
        lighting_shader.setVec3f("viewPos", camera.getViewPos());
        lighting_shader.setFloat("material.shininess", 32.0);

        // Here we set all the uniforms for the 5/6 types of lights we have. We have to set them manually and index 
        // the proper PointLight struct in the array to set each uniform variable. This can be done more code-friendly
        // by defining light types as classes and set their values in there, or by using a more efficient uniform approach
        // by using 'Uniform buffer objects', but that is something we'll discuss in the 'Advanced GLSL' tutorial.

        // directional light
        lighting_shader.setVec3f("dirLight.direction", .{-0.2, -1.0, -0.3});
        lighting_shader.setVec3f("dirLight.ambient", .{ 0.05, 0.05, 0.05 });
        lighting_shader.setVec3f("dirLight.diffuse", .{ 0.4, 0.4, 0.4 });
        lighting_shader.setVec3f("dirLight.specular", .{ 0.5, 0.5, 0.5 });
        // point light 1
        lighting_shader.setVec3f("pointLights[0].position", point_light_positions[0]);
        lighting_shader.setVec3f("pointLights[0].ambient", .{ 0.05, 0.05, 0.05 });
        lighting_shader.setVec3f("pointLights[0].diffuse", .{ 0.8, 0.8, 0.8 });
        lighting_shader.setVec3f("pointLights[0].specular", .{ 1.0, 1.0, 1.0 });
        lighting_shader.setFloat("pointLights[0].constant", 1.0);
        lighting_shader.setFloat("pointLights[0].linear", 0.09);
        lighting_shader.setFloat("pointLights[0].quadratic", 0.032);
        // point light 2
        lighting_shader.setVec3f("pointLights[1].position", point_light_positions[1]);
        lighting_shader.setVec3f("pointLights[1].ambient", .{ 0.05, 0.05, 0.05 });
        lighting_shader.setVec3f("pointLights[1].diffuse", .{ 0.8, 0.8, 0.8 });
        lighting_shader.setVec3f("pointLights[1].specular", .{ 1.0, 1.0, 1.0 });
        lighting_shader.setFloat("pointLights[1].constant", 1.0);
        lighting_shader.setFloat("pointLights[1].linear", 0.09);
        lighting_shader.setFloat("pointLights[1].quadratic", 0.032);
        // point light 3
        lighting_shader.setVec3f("pointLights[2].position", point_light_positions[2]);
        lighting_shader.setVec3f("pointLights[2].ambient", .{ 0.05, 0.05, 0.05 });
        lighting_shader.setVec3f("pointLights[2].diffuse", .{ 0.8, 0.8, 0.8 });
        lighting_shader.setVec3f("pointLights[2].specular", .{ 1.0, 1.0, 1.0 });
        lighting_shader.setFloat("pointLights[2].constant", 1.0);
        lighting_shader.setFloat("pointLights[2].linear", 0.09);
        lighting_shader.setFloat("pointLights[2].quadratic", 0.032);
        // point light 4
        lighting_shader.setVec3f("pointLights[3].position", point_light_positions[3]);
        lighting_shader.setVec3f("pointLights[3].ambient", .{ 0.05, 0.05, 0.05 });
        lighting_shader.setVec3f("pointLights[3].diffuse", .{ 0.8, 0.8, 0.8 });
        lighting_shader.setVec3f("pointLights[3].specular", .{ 1.0, 1.0, 1.0 });
        lighting_shader.setFloat("pointLights[3].constant", 1.0);
        lighting_shader.setFloat("pointLights[3].linear", 0.09);
        lighting_shader.setFloat("pointLights[3].quadratic", 0.032);
        // spotLight
        lighting_shader.setVec3f("spotLight.position", camera.getViewPos());
        lighting_shader.setVec3f("spotLight.direction", camera.getFrontPos());
        lighting_shader.setVec3f("spotLight.ambient", .{ 0.0, 0.0, 0.0 });
        lighting_shader.setVec3f("spotLight.diffuse", .{ 1.0, 1.0, 1.0 });
        lighting_shader.setVec3f("spotLight.specular", .{ 1.0, 1.0, 1.0 });
        lighting_shader.setFloat("spotLight.constant", 1.0);
        lighting_shader.setFloat("spotLight.linear", 0.09);
        lighting_shader.setFloat("spotLight.quadratic", 0.032);
        lighting_shader.setFloat("spotLight.cutOff", math.cos(math.degreesToRadians(12.5)));
        lighting_shader.setFloat("spotLight.outerCutOff", math.cos(math.degreesToRadians(15.0)));     

        // view/projection transformations
        const window_size = window.getSize();
        const aspect_ratio: f32 = @as(f32, @floatFromInt(window_size[0])) / @as(f32, @floatFromInt(window_size[1]));
        const projectionM = zm.perspectiveFovRhGl(common.radians(camera.zoom), aspect_ratio, 0.1, 100.0);
        zm.storeMat(&projection, projectionM);
        lighting_shader.setMat4f("projection", projection);
        const viewM = camera.getViewMatrix();
        zm.storeMat(&view, viewM);
        lighting_shader.setMat4f("view", view);

        // world transformation
        zm.storeMat(&model, zm.identity());
        lighting_shader.setMat4f("model", model);

        // bind diffuse map
        gl.activeTexture(gl.TEXTURE0);
        gl.bindTexture(gl.TEXTURE_2D, diffuse_map_texture);
        // bind specular map
        gl.activeTexture(gl.TEXTURE1);
        gl.bindTexture(gl.TEXTURE_2D, specular_map_texture);

        // render containers
        gl.bindVertexArray(cube_vao);
        for (cube_positions, 0..) |cube_position, idx| {
            const cube_trans = zm.translation(cube_position[0], cube_position[1], cube_position[2]);
            const angle = 20.0 * @as(f32, @floatFromInt(idx));
            const rotation_direction = (((@mod(@as(f32, @floatFromInt(idx + 1)), 2.0)) * 2.0) - 1.0);
            const cube_rot = zm.matFromAxisAngle(zm.f32x4(1.0, 0.3, 0.5, 1.0), angle * rotation_direction * common.RAD_CONVERSION);
            const modelM = zm.mul(cube_rot, cube_trans);
            zm.storeMat(&model, modelM);
            lighting_shader.setMat4f("model", model);

            gl.drawArrays(gl.TRIANGLES, 0, 36);
        }

        // also draw the lamp object(s)
        lighting_cube_shader.use();
        lighting_cube_shader.setMat4f("projection", projection);
        lighting_cube_shader.setMat4f("view", view);

        gl.bindVertexArray(light_cube_vao);
        for (point_light_positions) |point_light_position| {
            const cube_trans = zm.translation(point_light_position[0], point_light_position[1], point_light_position[2]);
            const modelM = zm.mul(zm.scaling(0.2, 0.2, 0.2), cube_trans);
            zm.storeMat(&model, modelM);
            lighting_cube_shader.setMat4f("model", model);
            gl.drawArrays(gl.TRIANGLES, 0, 36);
        }

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