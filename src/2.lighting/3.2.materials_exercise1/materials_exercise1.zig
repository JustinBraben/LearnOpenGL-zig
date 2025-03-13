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

    // create shader program
    var lighting_shader: Shader = Shader.create(arena, "src/2.lighting/3.2.materials_exercise1/3.2.materials.vs", "src/2.lighting/3.2.materials_exercise1/3.2.materials.fs");
    var lighting_cube_shader: Shader = Shader.create(arena, "src/2.lighting/3.2.materials_exercise1/3.2.light_cube.vs", "src/2.lighting/3.2.materials_exercise1/3.2.light_cube.fs");

    // set up vertex data (and buffer(s)) and configure vertex attributes
    // ------------------------------------------------------------------
    const vertices = [_]f32{
        -0.5, -0.5, -0.5,  0.0,  0.0, -1.0,
        0.5, -0.5, -0.5,   0.0,  0.0, -1.0,
        0.5,  0.5, -0.5,   0.0,  0.0, -1.0,
        0.5,  0.5, -0.5,   0.0,  0.0, -1.0,
        -0.5,  0.5, -0.5,  0.0,  0.0, -1.0,
        -0.5, -0.5, -0.5,  0.0,  0.0, -1.0,

        -0.5, -0.5, 0.5,   0.0,  0.0, 1.0,
        0.5,  -0.5, 0.5,   0.0,  0.0, 1.0,
        0.5,  0.5,  0.5,   0.0,  0.0, 1.0,
        0.5,  0.5,  0.5,   0.0,  0.0, 1.0,
        -0.5, 0.5,  0.5,   0.0,  0.0, 1.0,
        -0.5, -0.5, 0.5,   0.0,  0.0, 1.0,

        -0.5, 0.5,  0.5,  -1.0,  0.0, 0.0,
        -0.5, 0.5,  -0.5, -1.0,  0.0, 0.0,
        -0.5, -0.5, -0.5, -1.0,  0.0, 0.0,
        -0.5, -0.5, -0.5, -1.0,  0.0, 0.0,
        -0.5, -0.5, 0.5,  -1.0,  0.0, 0.0,
        -0.5, 0.5,  0.5,  -1.0,  0.0, 0.0,

        0.5,  0.5,  0.5,   1.0,  0.0, 1.0,
        0.5,  0.5,  -0.5,  1.0,  0.0, 1.0,
        0.5,  -0.5, -0.5,  1.0,  0.0, 1.0,
        0.5,  -0.5, -0.5,  1.0,  0.0, 1.0,
        0.5,  -0.5, 0.5,   1.0,  0.0, 1.0,
        0.5,  0.5,  0.5,   1.0,  0.0, 1.0,

        -0.5, -0.5, -0.5,  0.0, -1.0, 0.0,
        0.5,  -0.5, -0.5,  0.0, -1.0, 0.0,
        0.5,  -0.5, 0.5,   0.0, -1.0, 0.0,
        0.5,  -0.5, 0.5,   0.0, -1.0, 0.0,
        -0.5, -0.5, 0.5,   0.0, -1.0, 0.0,
        -0.5, -0.5, -0.5,  0.0, -1.0, 0.0,

        -0.5, 0.5,  -0.5,  0.0,  1.0, 0.0,
        0.5,  0.5,  -0.5,  0.0,  1.0, 0.0,
        0.5,  0.5,  0.5,   0.0,  1.0, 0.0,
        0.5,  0.5,  0.5,   0.0,  1.0, 0.0,
        -0.5, 0.5,  0.5,   0.0,  1.0, 0.0,
        -0.5, 0.5,  -0.5,  0.0,  1.0, 0.0,
    };

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
    gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 6 * @sizeOf(gl.Float), null);
    gl.enableVertexAttribArray(0);
    // normal attribute
    const normal_offset: [*c]c_uint = (3 * @sizeOf(f32));
    gl.vertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 6 * @sizeOf(gl.Float), normal_offset);
    gl.enableVertexAttribArray(1);

    // second, configure the light's VAO (VBO stays the same; the vertices are the same for the light object which is also a 3D cube)
    var light_cube_vao: gl.Uint = undefined;

    gl.genVertexArrays(1, &light_cube_vao);
    defer gl.deleteVertexArrays(1, &light_cube_vao);
    gl.bindVertexArray(light_cube_vao);

    // we only need to bind to the VBO (to link it with glVertexAttribPointer), no need to fill it; the VBO's data already contains all we need (it's already bound, but we do it again for educational purposes)
    gl.bindBuffer(gl.ARRAY_BUFFER, VBO);
    gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 6 * @sizeOf(gl.Float), null);
    gl.enableVertexAttribArray(0);

    gl.enable(gl.DEPTH_TEST);

    // Buffer to store Model matrix
    var model: [16]f32 = undefined;

    // View matrix
    var view: [16]f32 = undefined;

    // Buffer to store Orojection matrix (in render loop)
    var projection: [16]f32 = undefined;

    while (!window.shouldClose()) {
        // Time per frame
        const current_frame: f32 = @floatCast(glfw.getTime());
        delta_time = current_frame - last_frame;
        last_frame = current_frame;

        processInput(window, delta_time);

        // Set the whole screen to a color
        gl.clearColor(0.1, 0.1, 0.1, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT); // also clear the depth buffer now!

        const radius: f32 = 5.0; // Distance from the center
        const speed: f32 = 1.0; // Speed of rotation
        light_position[0] = zm.sin(current_frame * speed) * radius; // X coordinate
        light_position[1] = zm.sin(current_frame * speed) * radius; // Y coordinate
        light_position[2] = zm.cos(current_frame * speed) * radius; // Z coordinate

        // be sure to activate shader when setting uniforms/drawing objects
        lighting_shader.use();
        lighting_shader.setVec3f("light.position",  light_position);
        lighting_shader.setVec3f("viewPos", zm.vecToArr3(camera.position));

        // light properties
        var light_color = [_]f32{0.0, 0.0, 0.0};
        light_color[0] = zm.sin(@as(f32, @floatCast(glfw.getTime())) * 2.0);
        light_color[1] = zm.sin(@as(f32, @floatCast(glfw.getTime())) * 0.7);
        light_color[2] = zm.sin(@as(f32, @floatCast(glfw.getTime())) * 1.3);
        // const diffuse_color = [_]f32{light_color[0] * 0.5, light_color[1] * 0.5, light_color[2] * 0.5};
        // const ambient_color = [_]f32{diffuse_color[0] * 0.2, diffuse_color[1] * 0.2, diffuse_color[2] * 0.2};
        lighting_shader.setVec3f("light.diffuse",  .{ 1.0, 1.0, 1.0 });
        lighting_shader.setVec3f("light.ambient",  .{ 1.0, 1.0, 1.0 });
        lighting_shader.setVec3f("light.specular",  .{ 1.0, 1.0, 1.0 });

        // material properties
        lighting_shader.setVec3f("material.diffuse",  .{ 0.0, 0.50980392, 0.50980392 });
        lighting_shader.setVec3f("material.ambient",  .{ 0.0, 0.1, 0.06 });
        lighting_shader.setVec3f("material.specular",  .{ 0.50196078, 0.50196078, 0.50196078 });
        lighting_shader.setFloat("material.shininess", 32.0);

        const window_size = window.getSize();
        const aspect_ratio: f32 = @as(f32, @floatFromInt(window_size[0])) / @as(f32, @floatFromInt(window_size[1]));
        const projectionM = zm.perspectiveFovRhGl(math.degreesToRadians(45.0), aspect_ratio, 0.1, 100.0);
        zm.storeMat(&projection, projectionM);
        lighting_shader.setMat4f("projection", projection);

        // View matrix: Camera
        const viewM = camera.getViewMatrix();
        zm.storeMat(&view, viewM);
        lighting_shader.setMat4f("view", view);

        // // zm.storeMat(&model, zm.translation(0.0, zm.sin(current_frame), 0.0));
        zm.storeMat(&model, zm.identity());
        lighting_shader.setMat4f("model", model);
        gl.bindVertexArray(cube_vao);
        gl.drawArrays(gl.TRIANGLES, 0, 36);

        const light_trans = zm.translation(light_position[0], light_position[1], light_position[2]);
        const light_modelM = zm.mul(light_trans, zm.scaling(0.2, 0.2, 0.2));
        zm.storeMat(&model, light_modelM);
        // zm.storeMat(&model, zm.mul(zm.translation(4.2, 2.0, 4.0), zm.scaling(0.2, 0.2, 0.2)));
        // zm.storeMat(&model, zm.identity());

        lighting_cube_shader.use();
        lighting_cube_shader.setMat4f("projection", projection);
        lighting_cube_shader.setMat4f("view", view);
        lighting_cube_shader.setMat4f("model", model);
        gl.bindVertexArray(light_cube_vao);
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