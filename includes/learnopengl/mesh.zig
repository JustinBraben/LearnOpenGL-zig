const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const zstbi = @import("zstbi");
const zopengl = @import("zopengl");
const gl = zopengl.bindings;
const za = @import("zalgebra");

const Shader = @import("Shader");

const Mesh = @This();

pub const Vertex = struct {
    position: za.Vec3 = .zero(),
    normal: za.Vec3 = .zero(),
    tex_coords: za.Vec2 = .zero(),
    tangent: za.Vec3 = .zero(),
    bitangent: za.Vec3 = .zero(),
};

pub const Texture = struct {
    id: u32,
    type: []const u8,
    path: []const u8,
};

vertices: []Vertex,
indices: []u32,
textures: []Texture,
vao: u32,
vbo: u32,
ebo: u32,
allocator: Allocator,

pub fn init(allocator: Allocator, vertices: []const Vertex, indices: []const u32, textures: []const Texture) !Mesh {
    var mesh = Mesh{
        .vertices = try allocator.dupe(Vertex, vertices),
        .indices = try allocator.dupe(u32, indices),
        .textures = try allocator.dupe(Texture, textures),
        .vao = 0,
        .vbo = 0,
        .ebo = 0,
        .allocator = allocator,
    };
    mesh.setupMesh();
    return mesh;
}

pub fn deinit(self: *Mesh) void {
    gl.deleteVertexArrays(1, &self.vao);
    gl.deleteBuffers(1, &self.vbo);
    gl.deleteBuffers(1, &self.ebo);
    self.allocator.free(self.vertices);
    self.allocator.free(self.indices);
    self.allocator.free(self.textures);
}

fn setupMesh(self: *Mesh) void {
    gl.genVertexArrays(1, &self.vao);
    gl.genBuffers(1, &self.vbo);
    gl.genBuffers(1, &self.ebo);

    gl.bindVertexArray(self.vao);
    
    gl.bindBuffer(gl.ARRAY_BUFFER, self.vbo);
    gl.bufferData(gl.ARRAY_BUFFER, @intCast(self.vertices.len * @sizeOf(Vertex)), self.vertices.ptr, gl.STATIC_DRAW);

    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, self.ebo);
    gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, @intCast(self.indices.len * @sizeOf(u32)), self.indices.ptr, gl.STATIC_DRAW);

    // vertex positions
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, @sizeOf(Vertex), @ptrFromInt(@offsetOf(Vertex, "position")));
    
    // vertex normals
    gl.enableVertexAttribArray(1);
    gl.vertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, @sizeOf(Vertex), @ptrFromInt(@offsetOf(Vertex, "normal")));
    
    // vertex texture coords
    gl.enableVertexAttribArray(2);
    gl.vertexAttribPointer(2, 2, gl.FLOAT, gl.FALSE, @sizeOf(Vertex), @ptrFromInt(@offsetOf(Vertex, "tex_coords")));
    
    // vertex tangent
    gl.enableVertexAttribArray(3);
    gl.vertexAttribPointer(3, 3, gl.FLOAT, gl.FALSE, @sizeOf(Vertex), @ptrFromInt(@offsetOf(Vertex, "tangent")));
    
    // vertex bitangent
    gl.enableVertexAttribArray(4);
    gl.vertexAttribPointer(4, 3, gl.FLOAT, gl.FALSE, @sizeOf(Vertex), @ptrFromInt(@offsetOf(Vertex, "bitangent")));

    gl.bindVertexArray(0);
}

pub fn draw(self: *const Mesh, shader: *Shader) void {
    var diffuse_nr: u32 = 1;
    var specular_nr: u32 = 1;
    var normal_nr: u32 = 1;
    var height_nr: u32 = 1;

    for (self.textures, 0..) |texture, i| {
        gl.activeTexture(gl.TEXTURE0 + @as(u32, @intCast(i)));
        
        var number: []const u8 = undefined;
        const name = texture.type;
        
        if (std.mem.eql(u8, name, "texture_diffuse")) {
            number = std.fmt.allocPrint(self.allocator, "{d}", .{diffuse_nr}) catch "1";
            diffuse_nr += 1;
        } else if (std.mem.eql(u8, name, "texture_specular")) {
            number = std.fmt.allocPrint(self.allocator, "{d}", .{specular_nr}) catch "1";
            specular_nr += 1;
        } else if (std.mem.eql(u8, name, "texture_normal")) {
            number = std.fmt.allocPrint(self.allocator, "{d}", .{normal_nr}) catch "1";
            normal_nr += 1;
        } else if (std.mem.eql(u8, name, "texture_height")) {
            number = std.fmt.allocPrint(self.allocator, "{d}", .{height_nr}) catch "1";
            height_nr += 1;
        }
        
        const uniform_name = std.fmt.allocPrintZ(self.allocator, "{s}{s}", .{ name, number }) catch continue;
        defer self.allocator.free(uniform_name);
        
        shader.setInt(uniform_name, @intCast(i));
        gl.bindTexture(gl.TEXTURE_2D, texture.id);
        
        if (!std.mem.eql(u8, number, "1")) {
            self.allocator.free(number);
        }
    }

    gl.bindVertexArray(self.vao);
    gl.drawElements(gl.TRIANGLES, @intCast(self.indices.len), gl.UNSIGNED_INT, null);
    gl.bindVertexArray(0);

    gl.activeTexture(gl.TEXTURE0);
}
