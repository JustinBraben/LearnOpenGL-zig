const std = @import("std");
const zopengl = @import("zopengl");
const gl = zopengl.bindings;
const Shader = @This();

// The program ID
ID: c_uint,

pub fn create(arena: std.mem.Allocator, vs_path: []const u8, fs_path: []const u8) !Shader {
    const vs_file = try std.fs.cwd().openFile(vs_path, .{});
    defer vs_file.close();
    const vs_code = try vs_file.readToEndAllocOptions(arena, (10 * 1024), null, @alignOf(u8), 0);

    const fs_file = try std.fs.cwd().openFile(fs_path, .{});
    defer fs_file.close();
    const fs_code = try fs_file.readToEndAllocOptions(arena, (10 * 1024), null, @alignOf(u8), 0);

    // Check if shader was compiled successfully
    var success: c_int = undefined;
    var infoLog: [512]u8 = [_]u8{0} ** 512;

    // Vertex shader
    var vertexShader: c_uint = undefined;
    vertexShader = gl.createShader(gl.VERTEX_SHADER);
    defer gl.deleteShader(vertexShader);
    gl.shaderSource(vertexShader, 1, @as([*c]const [*c]const u8, @ptrCast(&vs_code)), 0);
    gl.compileShader(vertexShader);
    gl.getShaderiv(vertexShader, gl.COMPILE_STATUS, &success);
    if (success == 0) {
        gl.getShaderInfoLog(vertexShader, 512, 0, &infoLog);
        std.log.err("{s}", .{infoLog});
        return error.ShaderCompileError;
    }

    // Fragment shader
    var fragmentShader: c_uint = undefined;
    fragmentShader = gl.createShader(gl.FRAGMENT_SHADER);
    defer gl.deleteShader(fragmentShader);
    gl.shaderSource(fragmentShader, 1, @as([*c]const [*c]const u8, @ptrCast(&fs_code)), 0);
    gl.compileShader(fragmentShader);
    gl.getShaderiv(fragmentShader, gl.COMPILE_STATUS, &success);
    if (success == 0) {
        gl.getShaderInfoLog(fragmentShader, 512, 0, &infoLog);
        std.log.err("{s}", .{infoLog});
        return error.ShaderCompileError;
    }

    // create a program object
    const shaderProgram = gl.createProgram();

    // attach compiled shader objects to the program object and link
    gl.attachShader(shaderProgram, vertexShader);
    gl.attachShader(shaderProgram, fragmentShader);
    gl.linkProgram(shaderProgram);

    // check if shader linking was successfull
    gl.getProgramiv(shaderProgram, gl.LINK_STATUS, &success);
    if (success == 0) {
        gl.getProgramInfoLog(shaderProgram, 512, 0, &infoLog);
        std.log.err("{s}", .{infoLog});
        return error.ShaderLinkError;
    }
    return Shader{ .ID = shaderProgram };
}

pub fn createGeometryShader(arena: std.mem.Allocator, vs_path: []const u8, fs_path: []const u8, gs_path: []const u8) !Shader {
    const vs_file = try std.fs.cwd().openFile(vs_path, .{});
    defer vs_file.close();
    const vs_code = try vs_file.readToEndAllocOptions(arena, (10 * 1024), null, @alignOf(u8), 0);

    const fs_file = try std.fs.cwd().openFile(fs_path, .{});
    defer fs_file.close();
    const fs_code = try fs_file.readToEndAllocOptions(arena, (10 * 1024), null, @alignOf(u8), 0);

    const gs_file = try std.fs.cwd().openFile(gs_path, .{});
    defer gs_file.close();
    const gs_code = try gs_file.readToEndAllocOptions(arena, (10 * 1024), null, @alignOf(u8), 0);

    // Check if shader was compiled successfully
    var success: c_int = undefined;
    var infoLog: [512]u8 = [_]u8{0} ** 512;

    // Vertex shader
    var vertexShader: c_uint = undefined;
    vertexShader = gl.createShader(gl.VERTEX_SHADER);
    defer gl.deleteShader(vertexShader);
    gl.shaderSource(vertexShader, 1, @as([*c]const [*c]const u8, @ptrCast(&vs_code)), 0);
    gl.compileShader(vertexShader);
    gl.getShaderiv(vertexShader, gl.COMPILE_STATUS, &success);
    if (success == 0) {
        gl.getShaderInfoLog(vertexShader, 512, 0, &infoLog);
        std.log.err("{s}", .{infoLog});
        return error.ShaderCompileError;
    }

    // Fragment shader
    var fragmentShader: c_uint = undefined;
    fragmentShader = gl.createShader(gl.FRAGMENT_SHADER);
    defer gl.deleteShader(fragmentShader);
    gl.shaderSource(fragmentShader, 1, @as([*c]const [*c]const u8, @ptrCast(&fs_code)), 0);
    gl.compileShader(fragmentShader);
    gl.getShaderiv(fragmentShader, gl.COMPILE_STATUS, &success);
    if (success == 0) {
        gl.getShaderInfoLog(fragmentShader, 512, 0, &infoLog);
        std.log.err("{s}", .{infoLog});
        return error.ShaderCompileError;
    }

    // Geometry shader
    var geometryShader: c_uint = undefined;
    geometryShader = gl.createShader(gl.GEOMETRY_SHADER);
    defer gl.deleteShader(geometryShader);
    gl.shaderSource(geometryShader, 1, @as([*c]const [*c]const u8, @ptrCast(&gs_code)), 0);
    gl.compileShader(geometryShader);
    gl.getShaderiv(geometryShader, gl.COMPILE_STATUS, &success);
    if (success == 0) {
        gl.getShaderInfoLog(geometryShader, 512, 0, &infoLog);
        std.log.err("{s}", .{infoLog});
        return error.ShaderCompileError;
    }

    // create a program object
    const shaderProgram = gl.createProgram();

    // attach compiled shader objects to the program object and link
    gl.attachShader(shaderProgram, vertexShader);
    gl.attachShader(shaderProgram, fragmentShader);
    gl.attachShader(shaderProgram, geometryShader);
    gl.linkProgram(shaderProgram);

    // check if shader linking was successfull
    gl.getProgramiv(shaderProgram, gl.LINK_STATUS, &success);
    if (success == 0) {
        gl.getProgramInfoLog(shaderProgram, 512, 0, &infoLog);
        std.log.err("{s}", .{infoLog});
        return error.ShaderLinkError;
    }
    return Shader{ .ID = shaderProgram };
}

pub fn use(self: Shader) void {
    gl.useProgram(self.ID);
}

pub fn setBool(self: Shader, name: [*c]const u8, value: bool) void {
    gl.uniform1i(gl.getUniformLocation(self.ID, name), @intFromBool(value));
}

pub fn setInt(self: Shader, name: [*c]const u8, value: u32) void {
    gl.uniform1i(gl.getUniformLocation(self.ID, name), @intCast(value));
}

pub fn setFloat(self: Shader, name: [*c]const u8, value: f32) void {
    gl.uniform1f(gl.getUniformLocation(self.ID, name), value);
}

pub fn setVec3f(self: Shader, name: [*c]const u8, value: [3]f32) void {
    gl.uniform3f(gl.getUniformLocation(self.ID, name), value[0], value[1], value[2]);
}

pub fn setMat4f(self: Shader, name: [*c]const u8, value: [16]f32) void {
    const matLoc = gl.getUniformLocation(self.ID, name);
    if (matLoc == -1) {
        std.debug.print("Warning: Uniform '{s}' not found in shader program.\n", .{name});
    }
    gl.uniformMatrix4fv(matLoc, 1, gl.FALSE, &value);
}
