const std = @import("std");
const glfw = @import("zglfw");
const zopengl = @import("zopengl");

const vertexShaderSource =
    \\ #version 410 core
    \\ layout (location = 0) in vec3 aPos;
    \\ void main()
    \\ {
    \\    gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);
    \\ }
;

const fragmentShaderSource =
    \\ #version 410 core
    \\ out vec4 FragColor;
    \\ void main() 
    \\ {
    \\    FragColor = vec4(1.0, 0.3, 0.2, 1.0); 
    \\ }
;

pub fn main() !void {
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

    const gl = zopengl.bindings;

    // vertex shader
    var vertexShader: c_uint = undefined;
    vertexShader = gl.createShader(gl.VERTEX_SHADER);
    defer gl.deleteShader(vertexShader);

    // Attach the shader source to the vertex shader object and compile it
    gl.shaderSource(vertexShader, 1, @as([*c]const [*c]const u8, @ptrCast(&vertexShaderSource)), 0);
    gl.compileShader(vertexShader);

    // Check if vertex shader was compiled successfully
    var success: gl.Int = undefined;
    var infoLog: [512]u8 = [_]u8{0} ** 512;

    gl.getShaderiv(vertexShader, gl.COMPILE_STATUS, &success);
    if (success == 0) {
        gl.getShaderInfoLog(vertexShader, 512, 0, &infoLog);
        std.log.err("{s}", .{infoLog});
    }

    // Fragment shader
    var fragmentShader: c_uint = undefined;
    fragmentShader = gl.createShader(gl.FRAGMENT_SHADER);
    defer gl.deleteShader(fragmentShader);

    gl.shaderSource(fragmentShader, 1, @as([*c]const [*c]const u8, @ptrCast(&fragmentShaderSource)), 0);
    gl.compileShader(fragmentShader);

    gl.getShaderiv(fragmentShader, gl.COMPILE_STATUS, &success);

    if (success == 0) {
        gl.getShaderInfoLog(fragmentShader, 512, 0, &infoLog);
        std.log.err("{s}", .{infoLog});
    }

    // create a program object
    var shaderProgram: c_uint = undefined;
    shaderProgram = gl.createProgram();
    std.debug.print("{any}", .{shaderProgram});
    defer gl.deleteProgram(shaderProgram);

    // attach compiled shader objects to the program object and link
    gl.attachShader(shaderProgram, vertexShader);
    gl.attachShader(shaderProgram, fragmentShader);
    gl.linkProgram(shaderProgram);

    // check if shader linking was successfull
    gl.getProgramiv(shaderProgram, gl.LINK_STATUS, &success);
    if (success == 0) {
        gl.getProgramInfoLog(shaderProgram, 512, 0, &infoLog);
        std.log.err("{s}", .{infoLog});
    }

    // set up vertex data (and buffer(s)) and configure vertex attributes
    // ------------------------------------------------------------------
    const vertices_1 = [_]f32{
        // Triangle 1
        -1.0, -0.5, 0.0, 0.0, -0.5, 0.0, -0.5, 0.5, 0.0,
    };

    const vertices_2 = [_]f32{
        0.0, -0.5, 0.0, 1.0, -0.5, 0.0, 0.5, 0.5, 0.0,
    };

    var VBOs: [2]gl.Uint = undefined;
    var VAOs: [2]gl.Uint = undefined;

    gl.genVertexArrays(2, &VAOs);
    defer gl.deleteVertexArrays(1, &VAOs);

    gl.genBuffers(2, &VBOs);
    defer gl.deleteBuffers(1, &VBOs);

    // bind the Vertex Array Object first, then bind and set vertex buffer(s), and then configure vertex attributes(s).
    gl.bindVertexArray(VAOs[0]);
    gl.bindBuffer(gl.ARRAY_BUFFER, VBOs[0]);
    // Fill our buffer with the vertex data
    gl.bufferData(gl.ARRAY_BUFFER, @sizeOf(f32) * vertices_1.len, &vertices_1, gl.STATIC_DRAW);
    // Specify and link our vertext attribute description
    gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * @sizeOf(f32), null);
    gl.enableVertexAttribArray(0);

    // bind the VAO for triangle 2 first, then bind and set VBOs, then configure vertex attribs
    gl.bindVertexArray(VAOs[1]);
    gl.bindBuffer(gl.ARRAY_BUFFER, VBOs[1]);
    gl.bufferData(gl.ARRAY_BUFFER, @sizeOf(f32) * vertices_2.len, &vertices_2, gl.STATIC_DRAW);

    gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * @sizeOf(f32), null);
    gl.enableVertexAttribArray(0);

    while (!window.shouldClose()) {
        if (window.getKey(.escape) == .press) window.setShouldClose(true);

        // Set the whole screen to a color
        gl.clearBufferfv(gl.COLOR, 0, &[_]f32{ 0.2, 0.6, 0.4, 1.0 });

        // draw our first triangle
        gl.useProgram(shaderProgram);
        // Draw triangle 1
        gl.bindVertexArray(VAOs[0]);
        gl.drawArrays(gl.TRIANGLES, 0, 3);
        // Draw triangle 1
        gl.bindVertexArray(VAOs[1]);
        gl.drawArrays(gl.TRIANGLES, 0, 3);

        window.swapBuffers();
        glfw.pollEvents();
    }
}
