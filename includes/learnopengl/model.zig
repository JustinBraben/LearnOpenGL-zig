const std = @import("std");
const Allocator = std.mem.Allocator;
const zmesh = @import("zmesh");
const zstbi = @import("zstbi");
const zopengl = @import("zopengl");
const gl = zopengl.bindings;
const obj = @import("obj");

const Shader = @import("Shader");

const Model = @This();

allocator: Allocator,
obj_raw_data: []const u8,
obj_data: obj.ObjData,
mtl_data: obj.MaterialData,

pub fn init(allocator: Allocator, obj_raw_data: []const u8, mtl_raw_data: []const u8) !Model {
    var obj_data: obj.ObjData = undefined;
    obj_data = try obj.parseObj(allocator, obj_raw_data);

    var mtl_data: obj.MaterialData = undefined;
    mtl_data = try obj.parseMtl(allocator, mtl_raw_data);

    // for (obj_data.material_libs) |material_lib| {
    //     std.debug.print("material lib - {s}\n", .{material_lib});
    // }

    // for (obj_data.meshes) |mesh| {
    //     std.debug.print("mesh name - {?s}\n", .{mesh.name});
    //     for (mesh.materials) |material| {
    //         std.debug.print("\tmaterial - {s}\n", .{material.material});
    //     }
    // }
    
    return .{
        .allocator = allocator,
        .obj_raw_data = try allocator.dupe(u8, obj_raw_data),
        .obj_data = obj_data,
        .mtl_data = mtl_data,
    };
}

pub fn initFromPath(allocator: Allocator, obj_path: []const u8, mtl_path: []const u8) !Model {
    const obj_file = try std.fs.cwd().openFile(obj_path, .{});
    defer obj_file.close();
    const obj_data = try obj_file.readToEndAllocOptions(allocator, (10000 * 1024), null, @alignOf(u8), 0);
    defer allocator.free(obj_data);

    const mtl_file = try std.fs.cwd().openFile(mtl_path, .{});
    defer mtl_file.close();
    const mtl_data = try mtl_file.readToEndAllocOptions(allocator, (10 * 1024), null, @alignOf(u8), 0);
    defer allocator.free(mtl_data);

    return try init(allocator, obj_data, mtl_data);
}

pub fn deinit(self: *Model) void {
    self.allocator.free(self.obj_raw_data);
    self.obj_data.deinit(self.allocator);
    self.mtl_data.deinit(self.allocator);
}

pub fn draw(self: *Model) void {
    for (self.obj_data.meshes) |mesh| {
        _ = mesh;
        // // render the loaded model
        // gl.activeTexture(gl.TEXTURE0);
        // gl.bindTexture(gl.TEXTURE_2D, diffuse_map_texture);
        // gl.bindVertexArray(cubeVAO);
        // zm.storeMat(&model, zm.identity());
        // our_shader.setMat4f("model",  model);
        // // bind diffuse map
        // gl.drawElements(gl.TRIANGLES, @intCast(cube.indices.len), gl.UNSIGNED_INT, null);
        // gl.bindVertexArray(0);
    }
}

pub const Texture = struct {
    id: gl.Uint,
    type: []const u8,
    path: []const u8,
};

fn loadTextureFromFile(path: [:0]const u8) !gl.Uint {
    var textureID: gl.Uint = undefined;
    gl.genTextures(1, &textureID);

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

    return textureID;
}