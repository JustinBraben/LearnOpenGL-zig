const std = @import("std");
const Allocator = std.mem.Allocator;
const zmesh = @import("zmesh");
const zstbi = @import("zstbi");
const zopengl = @import("zopengl");
const gl = zopengl.gl;

const Shader = @import("Shader");
const Mesh = @import("Mesh");
const Vertex = Mesh.Vertex;
const Texture = Mesh.Texture;

pub const Model = struct {
    meshes: std.ArrayList(Mesh),
    directory: []const u8,
    allocator: Allocator,
    
    pub fn init(allocator: Allocator, path: []const u8) !Model {
        var model = Model{
            .meshes = std.ArrayList(Mesh).init(allocator),
            .directory = std.fs.path.dirname(path) orelse "",
            .allocator = allocator,
        };
        
        try model.loadModel(path);
        return model;
    }
    
    pub fn deinit(self: *Model) void {
        for (self.meshes.items) |*mesh| {
            mesh.deinit(self.allocator);
        }
        self.meshes.deinit();
    }
    
    fn loadModel(self: *Model, path: []const u8) !void {
        // Initialize zmesh
        zmesh.init(self.allocator);
        defer zmesh.deinit();
        
        // Load the mesh
        var mesh = try zmesh.io.loadMesh(
            self.allocator,
            path,
            .{
                .compute_normal = true,
                .compute_tangent = true,
            }
        );
        defer mesh.deinit();
        
        // Process the mesh data
        try self.processZmesh(mesh);
    }
    
    fn processZmesh(self: *Model, mesh: zmesh.Mesh) !void {
        var vertices = std.ArrayList(Vertex).init(self.allocator);
        defer vertices.deinit();
        
        // Process vertex data
        const positions = mesh.positions orelse return error.NoVertexPositions;
        const normals = mesh.normals orelse return error.NoVertexNormals;
        const texcoords = mesh.texcoords orelse return error.NoVertexTexCoords;
        
        for (0..positions.len / 3) |i| {
            const vertex = Vertex{
                .position = .{
                    positions[i * 3 + 0],
                    positions[i * 3 + 1],
                    positions[i * 3 + 2],
                },
                .normal = .{
                    normals[i * 3 + 0],
                    normals[i * 3 + 1],
                    normals[i * 3 + 2],
                },
                .tex_coords = .{
                    texcoords[i * 2 + 0],
                    texcoords[i * 2 + 1],
                },
            };
            
            try vertices.append(vertex);
        }
        
        // Create a new mesh
        const new_mesh = try Mesh.init(
            self.allocator,
            vertices.items,
            mesh.indices,
            &[0]Texture{} // Replace with actual textures
        );
        
        try self.meshes.append(new_mesh);
    }
    
    pub fn draw(self: *const Model, shader: *Shader) void {
        for (self.meshes.items) |*mesh| {
            mesh.draw(shader);
        }
    }
};