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
    \\ in vec4 v_color;
    \\ in float time;
    \\ out vec4 FragColor;
    \\ void main() 
    \\ {
    \\    FragColor = vec4(1.0f, 0.5f, 0.2f, 1.0f); 
    \\    //FragColor = vec4(fract(v_color.rgb + time), 1.0);
    \\    //FragColor = v_color;
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
    const vertices = [12]f32{
        0.5, 0.5, 0.0, // top right
        0.5, -0.5, 0.0, // bottom right
        -0.5, -0.5, 0.0, // bottom left
        -0.5, 0.5, 0.0, // top left
    };

    const indices = [6]c_uint{ // note that we start from 0!
        0, 1, 3, // first Triangle
        1, 2, 3, // second Triangle
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
    // copy our index array in an element buffer for OpenGL to use
    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, EBO);
    gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, 6 * @sizeOf(c_uint), &indices, gl.STATIC_DRAW);

    // Specify and link our vertext attribute description
    gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * @sizeOf(f32), null);
    gl.enableVertexAttribArray(0);

    // note that this is allowed, the call to glVertexAttribPointer registered VBO as the vertex attribute's bound vertex buffer object so afterwards we can safely unbind
    gl.bindBuffer(gl.ARRAY_BUFFER, 0);

    // You can unbind the VAO afterwards so other VAO calls won't accidentally modify this VAO, but this rarely happens. Modifying other
    // VAOs requires a call to glBindVertexArray anyways so we generally don't unbind VAOs (nor VBOs) when it's not directly necessary.
    gl.bindVertexArray(0);

    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0);

    while (!window.shouldClose()) {
        if (window.getKey(.escape) == .press) window.setShouldClose(true);

        // Set the whole screen to a color
        gl.clearBufferfv(gl.COLOR, 0, &[_]f32{ 0.2, 0.6, 0.4, 1.0 });

        // Activate shaderProgram
        gl.useProgram(shaderProgram);
        gl.bindVertexArray(VAO); // seeing as we only have a single VAO there's no need to bind it every time, but we'll do so to keep things a bit more organized
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, EBO);
        gl.drawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, null);
        gl.bindVertexArray(0);

        window.swapBuffers();
        glfw.pollEvents();
    }
}
