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

    // create shader program
    var shader_program: Shader = Shader.create(arena, "assets/6.2.vertexShaderCoord.glsl", "assets/6.2.fragmentShaderCoord.glsl");

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

    // // Comment lines to view where each are in the view!
    // const cube_positions = [_][3]f32{
    //     .{ 0.0, 0.0, 0.0 },
    //     .{ 2.0, 5.0, -15.0 },
    //     .{ -1.5, -2.2, -2.5 },
    //     .{ -3.8, -2.0, -12.3 },
    //     .{ 2.4, -0.4, -3.5 },
    //     .{ -1.7, 3.0, -7.5 },
    //     .{ 1.3, -2.0, -2.5 },
    //     .{ 1.5, 2.0, -2.5 },
    //     .{ 1.5, 0.2, -1.5 },
    //     .{ -1.3, 1.0, -1.5 },
    // };

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

    const image1_path: [:0]const u8 = "assets/container.jpg";
    var image1 = try zstbi.Image.loadFromFile(image1_path, 0);
    defer image1.deinit();

    const image2_path: [:0]const u8 = "assets/awesomeface.png";
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
    gl.enable(gl.CULL_FACE);
    // gl.depthFunc(gl.LESS);
    // gl.polygonMode(gl.FRONT_AND_BACK, gl.LINE);

    shader_program.use();
    shader_program.setInt("texture1", 0);
    shader_program.setInt("texture2", 1);

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
        gl.clearColor(0.2, 0.3, 0.3, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT); // also clear the depth buffer now!

        // bind textures on corresponding texture units
        gl.activeTexture(gl.TEXTURE0);
        gl.bindTexture(gl.TEXTURE_2D, texture1);
        gl.activeTexture(gl.TEXTURE1);
        gl.bindTexture(gl.TEXTURE_2D, texture2);
        gl.bindVertexArray(VAO);

        shader_program.use();

        const window_size = window.getSize();
        const aspect_ratio: f32 = @as(f32, @floatFromInt(window_size[0])) / @as(f32, @floatFromInt(window_size[1]));
        const projectionM = zm.perspectiveFovRhGl(camera.zoom * rad_conversion, aspect_ratio, 0.1, 100.0);
        zm.storeMat(&projection, projectionM);
        shader_program.setMat4f("projection", projection);

        // View matrix: Camera
        const viewM = camera.getViewMatrix();
        zm.storeMat(&view, viewM);
        shader_program.setMat4f("view", view);

        // for (cube_positions) |cube_position| {
        //     const cube_trans = zm.translation(cube_position[0], cube_position[1], cube_position[2]);
        //     const modelM = zm.mul(zm.identity(), cube_trans);
        //     zm.storeMat(&model, modelM);
        //     shader_program.setMat4f("model", model);

        //     gl.drawArrays(gl.TRIANGLES, 0, 36);
        // }

        // for (0..100) |cube_pos_x| {
        //     for (0..100) |cube_pos_z| {
        //         const cube_pos_x_f32: f32 = @floatFromInt(cube_pos_x);
        //         const cube_pos_z_f32: f32 = @floatFromInt(cube_pos_z);
        //         const cube_trans = zm.translation(cube_pos_x_f32, cube_pos_z_f32, 0.0);
        //         const modelM = zm.mul(zm.identity(), cube_trans);
        //         zm.storeMat(&model, modelM);
        //         shader_program.setMat4f("model", model);

        //         gl.drawArrays(gl.TRIANGLES, 0, 36);
                
        //     }
        // }

        for (0..10) |cube_pos_x| {
            for (0..10) |cube_pos_y| {
                for (0..10) |cube_pos_z| {
                    const cube_pos_x_f32: f32 = @floatFromInt(cube_pos_x);
                    const cube_pos_y_f32: f32 = @floatFromInt(cube_pos_y);
                    const cube_pos_z_f32: f32 = @floatFromInt(cube_pos_z);
                    const cube_trans = zm.translation(cube_pos_x_f32, cube_pos_y_f32, cube_pos_z_f32 * -1.0);
                    const modelM = zm.mul(zm.identity(), cube_trans);
                    zm.storeMat(&model, modelM);
                    shader_program.setMat4f("model", model);

                    gl.drawArrays(gl.TRIANGLES, 0, 36);

                }
                
            }
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