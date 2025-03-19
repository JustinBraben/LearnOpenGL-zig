const std = @import("std");
const Allocator = std.mem.Allocator;
const zstbi = @import("zstbi");
const zopengl = @import("zopengl");
const gl = zopengl.bindings;

const Shader = @import("Shader");

pub const Vertex = struct {
    position: [3]f32,
    normal: [3]f32,
    tex_coords: [2]f32,
};

pub const Texture = struct {
    id: u32,
    type: []const u8,
    path: []const u8,
};

pub const Mesh = struct {
    allocator: Allocator,
    vertices: []Vertex,
    indices: []u32,
    textures: []Texture,
    vao: gl.Uint,
    vbo: gl.Uint,
    ebo: gl.Uint,
    
    pub fn init(allocator: Allocator, vertices: []Vertex, indices: []u32, textures: []Texture) !Mesh {
        var mesh = Mesh{
            .allocator = allocator,
            .vertices = try allocator.dupe(Vertex, vertices),
            .indices = try allocator.dupe(u32, indices),
            .textures = try allocator.dupe(Texture, textures),
            .vao = undefined,
            .vbo = undefined,
            .ebo = undefined,
        };
        
        mesh.setupMesh();
        return mesh;
    }
    
    pub fn deinit(self: *Mesh) void {
        self.allocator.free(self.vertices);
        self.allocator.free(self.indices);
        self.allocator.free(self.textures);
        
        gl.deleteVertexArrays(1, &self.vao);
        gl.deleteBuffers(1, &self.vbo);
        gl.deleteBuffers(1, &self.ebo);
    }
    
    fn setupMesh(self: *Mesh) void {
        gl.genVertexArrays(1, &self.vao);
        gl.genBuffers(1, &self.vbo);
        gl.genBuffers(1, &self.ebo);
        
        gl.bindVertexArray(self.vao);
        
        gl.bindBuffer(gl.ARRAY_BUFFER, self.vbo);
        gl.bufferData(gl.ARRAY_BUFFER, @sizeOf(Vertex) * self.vertices.len, self.vertices.ptr, gl.STATIC_DRAW);
        
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, self.ebo);
        gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, @sizeOf(u32) * self.indices.len, self.indices.ptr, gl.STATIC_DRAW);
        
        // Position attribute
        gl.enableVertexAttribArray(0);
        gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, @sizeOf(Vertex), @ptrFromInt(@offsetOf(Vertex, "position")));
        
        // Normal attribute
        gl.enableVertexAttribArray(1);
        gl.vertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, @sizeOf(Vertex), @ptrFromInt(@offsetOf(Vertex, "normal")));
        
        // Texture coords attribute
        gl.enableVertexAttribArray(2);
        gl.vertexAttribPointer(2, 2, gl.FLOAT, gl.FALSE, @sizeOf(Vertex), @ptrFromInt(@offsetOf(Vertex, "tex_coords")));
        
        gl.bindVertexArray(0);
    }
    
    pub fn draw(self: *Mesh, shader: *Shader) void {
        var diffuse_nr: u32 = 1;
        var specular_nr: u32 = 1;
        
        for (self.textures, 0..) |texture, i| {
            // Activate texture unit
            gl.activeTexture(gl.TEXTURE0 + @as(u32, @intCast(i)));
            
            // Retrieve texture number
            var number: []const u8 = undefined;
            var name: []const u8 = undefined;
            
            if (std.mem.eql(u8, texture.type, "texture_diffuse")) {
                number = std.fmt.allocPrint(self.allocator, "{d}", .{diffuse_nr}) catch unreachable;
                diffuse_nr += 1;
                name = "texture_diffuse";
            } else if (std.mem.eql(u8, texture.type, "texture_specular")) {
                number = std.fmt.allocPrint(self.allocator, "{d}", .{specular_nr}) catch unreachable;
                specular_nr += 1;
                name = "texture_specular";
            }
            
            // Set the sampler to the correct texture unit
            const uniform_name = std.fmt.allocPrint(self.allocator, "material.{s}{s}", .{name, number}) catch unreachable;
            shader.setInt(uniform_name, @intCast(i));
            
            // Bind the texture
            gl.bindTexture(gl.TEXTURE_2D, texture.id);
        }
        
        // Draw mesh
        gl.bindVertexArray(self.vao);
        gl.drawElements(gl.TRIANGLES, @intCast(self.indices.len), gl.UNSIGNED_INT, null);
        gl.bindVertexArray(0);
        
        // Reset to defaults
        gl.activeTexture(gl.TEXTURE0);
    }
};