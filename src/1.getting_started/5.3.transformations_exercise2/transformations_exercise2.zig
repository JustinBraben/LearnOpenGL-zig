const std = @import("std");
const math = std.math;
const glfw = @import("zglfw");
const zopengl = @import("zopengl");
const zstbi = @import("zstbi");
const zm = @import("zmath");
const gl = zopengl.bindings;
const Shader = @import("Shader");
const common = @import("common");

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

    const window = glfw.Window.create(800, 600, "LearnOpenGL", null) catch |e| {
        std.io.getStdErr().writer().print("Failed to create GLFW window\n", .{}) catch {};
        return e;
    };
    defer window.destroy();

    glfw.makeContextCurrent(window);
    try zopengl.loadCoreProfile(glfw.getProcAddress, gl_major, gl_minor);

    glfw.swapInterval(1);

    // create shader program
    var shader_program: Shader = Shader.create(arena, "assets/5.1.vertexShaderTransform.glsl", "assets/5.1.fragmentShaderTransform.glsl");

    // set up vertex data (and buffer(s)) and configure vertex attributes
    // ------------------------------------------------------------------
    const vertices = [_]f32{
        // positions      // colors        // texture coords
        0.5, 0.5, 0.0, 1.0, 1.0, // top right
        0.5, -0.5, 0.0, 1.0, 0.0, // bottom right
        -0.5, -0.5, 0.0, 0.0, 0.0, // bottom left
        -0.5, 0.5, 0.0, 0.0, 1.0, // top left
    };
    const indices = [_]c_uint{
        0, 1, 3, // first triangle
        1, 2, 3  // second triangle
    };

    var VBO: gl.Uint = undefined;
    var VAO: gl.Uint = undefined;
    var EBO: gl.Uint = undefined;

    gl.genVertexArrays(1, &VAO);
    defer gl.deleteVertexArrays(1, &VAO);

    gl.genBuffers(1, &VBO);
    defer gl.deleteBuffers(1, &VBO);

    gl.genBuffers(1, &EBO);
    defer gl.deleteBuffers(1, &EBO);

    // bind the Vertex Array Object first, then bind and set vertex buffer(s), and then configure vertex attributes(s).
    gl.bindVertexArray(VAO);
    gl.bindBuffer(gl.ARRAY_BUFFER, VBO);
    // Fill our buffer with the vertex data
    gl.bufferData(gl.ARRAY_BUFFER, @sizeOf(f32) * vertices.len, &vertices, gl.STATIC_DRAW);

    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, EBO);
    gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, @sizeOf(c_uint) * indices.len, &indices, gl.STATIC_DRAW);

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
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
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
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
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

    shader_program.use();
    shader_program.setInt("texture1", 0);
    shader_program.setInt("texture2", 1);

    while (!window.shouldClose()) {
        if (window.getKey(.escape) == .press) window.setShouldClose(true);

        // Set the whole screen to a color
        gl.clearColor(0.2, 0.3, 0.3, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT);

        // bind textures on corresponding texture units
        gl.activeTexture(gl.TEXTURE0);
        gl.bindTexture(gl.TEXTURE_2D, texture1);
        gl.activeTexture(gl.TEXTURE1);
        gl.bindTexture(gl.TEXTURE_2D, texture2);

        // // get matrix's uniform location and set matrix
        // shader_program.use();

        // first container
        // ---------------
        const rotZ = zm.rotationZ(@as(f32, @floatCast(glfw.getTime())));
        const translation = zm.translation(0.5, -0.5, 0.0);
        var transformM: zm.Mat = undefined;
        transformM = zm.mul(zm.translation(1.0, 1.0, 1.0), rotZ);
        transformM = zm.mul(transformM, translation);
        var transform: [16]f32 = undefined;
        zm.storeMat(&transform, transformM);
        const transformLoc = gl.getUniformLocation(shader_program.ID, "transform");
        gl.uniformMatrix4fv(transformLoc, 1, gl.FALSE, &transform);

        gl.bindVertexArray(VAO);
        gl.drawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, null);

        // second transformation
        // ---------------------
        const scaleAmount = @as(f32, @floatCast(math.sin(glfw.getTime())));
        transformM = zm.mul(translation, zm.scaling(scaleAmount, scaleAmount, scaleAmount));
        zm.storeMat(&transform, transformM);
        gl.uniformMatrix4fv(transformLoc, 1, gl.FALSE, &transform);

        // now with the uniform matrix being replaced with new transformations, draw it again.
        gl.drawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, null);

        window.swapBuffers();
        glfw.pollEvents();
    }
}

// // Some zmath functions using later zig 0.14-dev, repurposing for this version 

// pub inline fn storeMat(mem: []f32, m: zm.Mat) void {
//     store(mem[0..4], m[0], 0);
//     store(mem[4..8], m[1], 0);
//     store(mem[8..12], m[2], 0);
//     store(mem[12..16], m[3], 0);
// }

// pub fn store(mem: []f32, v: anytype, comptime len: u32) void {
//     const T = @TypeOf(v);
//     const loop_len = if (len == 0) veclen(T) else len;
//     comptime var i: u32 = 0;
//     inline while (i < loop_len) : (i += 1) {
//         mem[i] = v[i];
//     }
// }

// pub inline fn veclen(comptime T: type) comptime_int {
//     return @typeInfo(T).Vector.len;
// }
