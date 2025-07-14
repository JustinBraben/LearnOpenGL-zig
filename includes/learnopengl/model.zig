const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const zstbi = @import("zstbi");
const zopengl = @import("zopengl");
const gl = zopengl.bindings;
const za = @import("zalgebra");
const obj = @import("obj");
const Mesh = @import("mesh.zig");
const Vertex = Mesh.Vertex;
const Texture = Mesh.Texture;

const Shader = @import("Shader");

const Model = @This();

meshes: ArrayList(Mesh),
textures_loaded: ArrayList(Texture),
directory: []u8,
allocator: Allocator,
gamma_correction: bool,

pub fn init(allocator: Allocator, path: []const u8, gamma_correction: bool) !Model {
    var model = Model{
        .meshes = ArrayList(Mesh).init(allocator),
        .textures_loaded = ArrayList(Texture).init(allocator),
        .directory = undefined,
        .allocator = allocator,
        .gamma_correction = gamma_correction,
    };
    
    // Extract directory from path
    const last_slash = std.mem.lastIndexOf(u8, path, "/") orelse 0;
    model.directory = try allocator.dupe(u8, path[0..last_slash]);

    std.debug.print("model.directory is {s}\n", .{model.directory});
    
    try model.loadModel(path);
    return model;
}

pub fn deinit(self: *Model) void {
    for (self.meshes.items) |*mesh| {
        mesh.deinit();
    }
    self.meshes.deinit();
    
    // Free texture paths
    for (self.textures_loaded.items) |texture| {
        self.allocator.free(texture.path);
    }
    self.textures_loaded.deinit();
    self.allocator.free(self.directory);
}

pub fn draw(self: *const Model, shader: *Shader) void {
    for (self.meshes.items) |*mesh| {
        mesh.draw(shader);
    }
}

fn loadModel(self: *Model, path: []const u8) !void {
    // Read and parse OBJ file
    const obj_file = try std.fs.cwd().readFileAlloc(self.allocator, path, 10 * 1024 * 1024);
    defer self.allocator.free(obj_file);
    
    var obj_data = try obj.parseObj(self.allocator, obj_file);
    defer obj_data.deinit(self.allocator);

    // Load material libraries
    const mtl_path = try std.mem.join(self.allocator, "/", &.{ self.directory, obj_data.material_libs[0] });
    const mtl_file = try std.fs.cwd().readFileAlloc(self.allocator, mtl_path, 1024 * 1024);
    defer self.allocator.free(mtl_file);
    var mtl_data = try obj.parseMtl(self.allocator, mtl_file);
    defer mtl_data.deinit(self.allocator);

    // Process each mesh
    for (obj_data.meshes) |mesh| {
        try self.processMesh(&obj_data, &mesh, &mtl_data.materials);
    }
}

fn processMesh(self: *Model, obj_data: *const obj.ObjData, mesh: *const obj.Mesh, materials: *std.StringHashMapUnmanaged(obj.Material)) !void {
    var vertices = ArrayList(Vertex).init(self.allocator);
    defer vertices.deinit();
    
    var indices = ArrayList(u32).init(self.allocator);
    defer indices.deinit();
    
    var textures = ArrayList(Texture).init(self.allocator);
    defer textures.deinit();

    // Process indices and create vertices
    for (mesh.indices) |index| {
        var vertex: Vertex = .{};

        // Position
        if (index.vertex) |v_idx| {
            const base_idx = v_idx * 3;
            vertex.position = za.Vec3.new(
                obj_data.vertices[base_idx],
                obj_data.vertices[base_idx + 1],
                obj_data.vertices[base_idx + 2],
            );
        }

        // Normal
        if (index.normal) |n_idx| {
            const base_idx = n_idx * 3;
            vertex.normal = za.Vec3.new(
                obj_data.normals[base_idx],
                obj_data.normals[base_idx + 1],
                obj_data.normals[base_idx + 2],
            );
        }

        // Texture coordinates
        if (index.tex_coord) |t_idx| {
            const base_idx = t_idx * 2;
            vertex.tex_coords = za.Vec2.new(
                obj_data.tex_coords[base_idx],
                obj_data.tex_coords[base_idx + 1],
            );
        }


        try vertices.append(vertex);
        try indices.append(@intCast(vertices.items.len - 1));
    }

    // Calculate tangents and bitangents
    try self.calculateTangents(vertices.items, indices.items);

    // Load textures for each material used in this mesh
    for (mesh.materials) |mat_ref| {
        if (materials.get(mat_ref.material)) |material| {
            // Load diffuse texture
            if (material.diffuse_map) |map| {
                const tex = try self.loadTexture(@as([:0]const u8, @ptrCast(map.path)), "texture_diffuse");
                try textures.append(tex);
            }
            
            // Load specular texture
            if (material.specular_color_map) |map| {
                const tex = try self.loadTexture(@as([:0]const u8, @ptrCast(map.path)), "texture_specular");
                try textures.append(tex);
            }
            
            // Load normal map
            if (material.normal_map) |map| {
                const tex = try self.loadTexture(@as([:0]const u8, @ptrCast(map.path)), "texture_normal");
                try textures.append(tex);
            }
            
            // Load bump map as height map
            if (material.bump_map) |map| {
                const tex = try self.loadTexture(@as([:0]const u8, @ptrCast(map.path)), "texture_height");
                try textures.append(tex);
            }
        }
    }

    const new_mesh = try Mesh.init(self.allocator, vertices.items, indices.items, textures.items);
    try self.meshes.append(new_mesh);
}

fn calculateTangents(self: *Model, vertices: []Vertex, indices: []const u32) !void {
    _ = self;
    
    // Process each triangle
    var i: usize = 0;
    while (i < indices.len) : (i += 3) {
        const i_0 = indices[i];
        const i_1 = indices[i + 1];
        const i_2 = indices[i + 2];

        const v0 = &vertices[i_0];
        const v1 = &vertices[i_1];
        const v2 = &vertices[i_2];

        const edge1 = v1.position.sub(v0.position);
        const edge2 = v2.position.sub(v0.position);
        
        const delta_uv1 = v1.tex_coords.sub(v0.tex_coords);
        const delta_uv2 = v2.tex_coords.sub(v0.tex_coords);

        const f: f32 = 1.0 / (delta_uv1.x() * delta_uv2.y() - delta_uv2.x() * delta_uv1.y());

        const tangent = za.Vec3.new(
            f * (delta_uv2.y() * edge1.x() - delta_uv1.y() * edge2.x()),
            f * (delta_uv2.y() * edge1.y() - delta_uv1.y() * edge2.y()),
            f * (delta_uv2.y() * edge1.z() - delta_uv1.y() * edge2.z()),
        ).norm();

        const bitangent = za.Vec3.new(
            f * (-delta_uv2.x() * edge1.x() + delta_uv1.x() * edge2.x()),
            f * (-delta_uv2.x() * edge1.y() + delta_uv1.x() * edge2.y()),
            f * (-delta_uv2.x() * edge1.z() + delta_uv1.x() * edge2.z()),
        ).norm();

        vertices[i_0].tangent = tangent;
        vertices[i_0].bitangent = bitangent;
        vertices[i_1].tangent = tangent;
        vertices[i_1].bitangent = bitangent;
        vertices[i_2].tangent = tangent;
        vertices[i_2].bitangent = bitangent;
    }
}

fn loadTexture(self: *Model, path: [:0]const u8, texture_type: []const u8) !Texture {
    // Check if texture was already loaded
    for (self.textures_loaded.items) |tex| {
        if (std.mem.eql(u8, tex.path, path)) {
            return Texture{
                .id = tex.id,
                .type = texture_type,
                .path = tex.path,
            };
        }
    }

    // Load new texture
    const full_path = try std.fs.path.join(self.allocator, &.{ self.directory, path });
    defer self.allocator.free(full_path);

    std.debug.print("Loading texture: {s}\n", .{full_path});

    const texture_id = try textureFromFile(@as([:0]const u8, @ptrCast(full_path)), self.gamma_correction);
    
    const tex_path = try self.allocator.dupe(u8, path);
    const texture = Texture{
        .id = texture_id,
        .type = texture_type,
        .path = tex_path,
    };
    
    try self.textures_loaded.append(texture);
    return texture;
}


fn textureFromFile(path: [:0]const u8, gamma: bool) !u32 {
    var texture_id: u32 = undefined;
    gl.genTextures(1, &texture_id);

    std.debug.print("Loading texture from file: {s}\n", .{path});

    var texture_image = try zstbi.Image.loadFromFile(path, 0);
    defer texture_image.deinit();

    const format: gl.Enum = switch (texture_image.num_components) {
        1 => gl.RED,
        3 => gl.RGB,
        4 => gl.RGBA,
        else => gl.RGB,
    };

    std.debug.print("  Texture dimensions: {}x{}, components: {}, format: {}\n", 
        .{texture_image.width, texture_image.height, texture_image.num_components, format});
    
    // Check if data is valid
    if (texture_image.data.len == 0) {
        std.debug.print("  ERROR: Texture data is empty!\n", .{});
        return error.EmptyTextureData;
    }

    gl.bindTexture(gl.TEXTURE_2D, texture_id);
    gl.texImage2D(
        gl.TEXTURE_2D,
        0,
        if (gamma) gl.SRGB else format,
        @as(c_int, @intCast(texture_image.width)), 
        @as(c_int, @intCast(texture_image.height)), 
        0,
        format,
        gl.UNSIGNED_BYTE,
        @ptrCast(texture_image.data)
    );
    gl.generateMipmap(gl.TEXTURE_2D);

    // ... texture parameters ...
    
    std.debug.print("  Created texture ID: {}\n", .{texture_id});
    return texture_id;
}

// allocator: Allocator,
// obj_data: obj.ObjData,
// mtl_data: obj.MaterialData,
// textures_loaded: std.ArrayList(Texture),
// vertices: std.ArrayList(Vertex),
// indices: std.ArrayList(u32),
// directory: []const u8,
// gamma_correction: bool,

// pub fn init(allocator: Allocator, obj_path: []const u8, mtl_path: []const u8, gamma: bool) !Model {
//     var self: Model = undefined;

//     const model_file = try std.fs.cwd().openFile(obj_path, .{});
//     defer model_file.close();
//     const model_data = try model_file.readToEndAllocOptions(allocator, (10000 * 1024), null, @alignOf(u8), 0);
//     defer allocator.free(model_data);

//     const mtl_file = try std.fs.cwd().openFile(mtl_path, .{});
//     defer mtl_file.close();
//     const mtl_data = try mtl_file.readToEndAllocOptions(allocator, (10000 * 1024), null, @alignOf(u8), 0);
//     defer allocator.free(mtl_data);

//     const idx = std.mem.lastIndexOfScalar(u8, obj_path[0..], '/');
//     const path = if (idx) |i| obj_path[0..i] else obj_path;

//     self.allocator = allocator;
//     self.obj_data = try obj.parseObj(allocator, model_data);
//     self.mtl_data = try obj.parseMtl(allocator, mtl_data);
//     self.textures_loaded = .init(allocator);
//     self.vertices = .init(allocator);
//     self.directory = path;
//     self.gamma_correction = gamma;

//     try self.processMeshs();

//     return self;
// }

// pub fn deinit(self: *Model) void {
//     self.obj_data.deinit(self.allocator);
//     self.mtl_data.deinit(self.allocator);
//     self.textures_loaded.deinit();
//     self.vertices.deinit();
// }

// pub fn processMeshs(self: *Model) !void {
//     var unique_vertices = std.HashMap(Vertex, u32, Vertex.HashContext, std.hash_map.default_max_load_percentage).init(self.allocator);
//     defer unique_vertices.deinit();

//     // walk through each of the mesh's vertices
//     for (self.obj_data.meshes) |mesh| {
//         for (mesh.indices) |index| {
//             // Vertices are stored as [x1, y1, z1, x2, y2, z2, ...]
//             // So vertex index N corresponds to positions [N*3, N*3+1, N*3+2]
//             const vertex_idx = index.vertex.? * 3;

//             // Texture coordinates are stored as [u1, v1, u2, v2, ...]
//             // So tex_coord index N corresponds to positions [N*2, N*2+1]
//             const tex_coord_idx = if (index.tex_coord) |tc| tc * 2 else 0;

//             // Normal coordinates are stored as [x1, y1, z1, x2, y2, z2, ...]
//             // So tex_coord index N corresponds to positions [N*3, N*3+1, N*3+2]
//             const normal_coord_idx = index.normal.? * 3;

//             const new_vertex: Vertex = .{
//                 .position  = .{
//                     self.obj_data.vertices[vertex_idx],
//                     self.obj_data.vertices[vertex_idx + 1],
//                     self.obj_data.vertices[vertex_idx + 2],
//                 },
//                 .normal = .{
//                     self.obj_data.normals[normal_coord_idx],
//                     self.obj_data.normals[normal_coord_idx + 1],
//                     self.obj_data.normals[normal_coord_idx + 2],
//                 },
//                 .tex_coords = if (index.tex_coord) |_| .{
//                     self.obj_data.tex_coords[tex_coord_idx],
//                     self.obj_data.tex_coords[tex_coord_idx + 1],
//                 } else .{ 0.0, 0.0 },
//             };

//             try self.vertices.append(new_vertex);

//             // if (unique_vertices.get(new_vertex) == null) {
//             //     try unique_vertices.put(new_vertex, @intCast(self.vertices.items.len));
//             //     try self.vertices.append(new_vertex);
//             // }

//             // try self.indices.append(@intCast(unique_vertices.get(new_vertex).?));
//         }
//     }
// }

// pub fn loadMaterialTextures(self: *Model) !void {
//     var diffuse_maps = std.ArrayList(Texture).init(self.allocator);
//     defer diffuse_maps.deinit();

//     try self.textures_loaded.appendSlice(diffuse_maps.toOwnedSlice()[0..]);
// }