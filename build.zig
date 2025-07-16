const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const modules = createModules(b, target, optimize);

    // Create categories
    const getting_started_step = createCategory(b, "getting_started", "1.getting_started", &getting_started, target, optimize, modules) catch unreachable;

    const lighting_step = createCategory(b, "lighting", "2.lighting", &lighting, target, optimize, modules) catch unreachable;

    const model_loading_step = createCategory(b, "model_loading", "3.model_loading", &model_loading, target, optimize, modules) catch unreachable;

    const advanced_opengl_step = createCategory(b, "advanced_opengl", "4.advanced_opengl", &advanced_opengl, target, optimize, modules) catch unreachable;

    const advanced_lighting_step = createCategory(b, "advanced_lighting", "5.advanced_lighting", &advanced_lighting, target, optimize, modules) catch unreachable;

    // Create "all" step
    const all_step = b.step("all", "Build everything and runs all tests");
    all_step.dependOn(getting_started_step);
    all_step.dependOn(lighting_step);
    all_step.dependOn(model_loading_step);
    all_step.dependOn(advanced_opengl_step);
    all_step.dependOn(advanced_lighting_step);

    b.default_step.dependOn(all_step);
}

fn createCategory(
    b: *std.Build,
    category_name: []const u8,
    folder_path: []const u8,
    examples: []const []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    modules: anytype,
) !*std.Build.Step {
    const category_step = b.step(category_name, b.fmt("Build {s} examples", .{category_name}));
    for (examples) |example_name| {
        var example_name_split_iter = std.mem.splitScalar(u8, example_name, '/');
        const actual_example_name = example_name_split_iter.next().?;

        const example_exe_mod = b.createModule(.{
            .root_source_file = b.path(b.fmt("src/{s}/{s}.zig", .{ folder_path, example_name })),
            .target = target,
            .optimize = optimize,
        });

        const example_exe = b.addExecutable(.{
            .name = actual_example_name,
            .root_module = example_exe_mod,
        });

        // Add common imports and libraries
        example_exe_mod.addImport("zglfw", modules.zglfw.module("root"));
        example_exe.linkLibrary(modules.zglfw.artifact("glfw"));
        example_exe_mod.addImport("zopengl", modules.zopengl.module("root"));
        example_exe_mod.addImport("zstbi", modules.zstbi.module("root"));
        example_exe_mod.addImport("zmath", modules.zmath.module("root"));
        example_exe_mod.addImport("zalgebra", modules.zalgebra.module("zalgebra"));
        example_exe_mod.addImport("Shader", modules.shader);
        example_exe_mod.addImport("Camera", modules.camera);
        example_exe_mod.addImport("obj", modules.obj);
        example_exe_mod.addImport("Model", modules.model);

        const output_dir = b.fmt("./{s}", .{@tagName(optimize)});

        const compile_step = b.step(actual_example_name, b.fmt("Build {s}", .{actual_example_name}));
        compile_step.dependOn(&b.addInstallArtifact(example_exe, .{ .dest_dir = .{
            .override = .{ .custom = output_dir },
            },
            .pdb_dir = .{
                .override = .{ .custom = output_dir },
            },
            .h_dir = .{
                .override = .{ .custom = output_dir },
            },
        }).step);
        b.getInstallStep().dependOn(compile_step);

        const run_cmd = b.addRunArtifact(example_exe);
        run_cmd.step.dependOn(compile_step);

        const run_step = b.step(b.fmt("run-{s}", .{actual_example_name}), b.fmt("Run {s}", .{actual_example_name}));
        run_step.dependOn(&run_cmd.step);
    }

    return category_step;
}

const Modules = struct {
    zmath: *std.Build.Dependency,
    zalgebra: *std.Build.Dependency,
    zstbi: *std.Build.Dependency,
    zopengl: *std.Build.Dependency,
    zglfw: *std.Build.Dependency,
    shader: *std.Build.Module,
    camera: *std.Build.Module,
    mesh: *std.Build.Module,
    obj: *std.Build.Module,
    model: *std.Build.Module,
};

fn createModules(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) Modules {
    const zglfw = b.dependency("zglfw", .{
        .target = target,
        .optimize = optimize,
    });

    const zopengl = b.dependency("zopengl", .{ .target = target });
    const zstbi = b.dependency("zstbi", .{
        .target = target,
        .optimize = optimize,
    });
    const zmath = b.dependency("zmath", .{
        .target = target,
    });
    const zalgebra = b.dependency("zalgebra", .{});
    const obj = b.dependency("obj", .{ .target = target, .optimize = optimize });

    // modules
    const shader_module = b.addModule("Shader", .{
        .root_source_file = b.path("includes/learnopengl/shader.zig"),
        .target = target,
        .optimize = optimize,
    });
    shader_module.addImport("zopengl", zopengl.module("root"));
    const camera_module = b.addModule("Camera", .{
        .root_source_file = b.path("includes/learnopengl/camera.zig"),
        .target = target,
        .optimize = optimize,
    });
    camera_module.addImport("zmath", zmath.module("root"));
    const mesh_module = b.addModule("Mesh", .{
        .root_source_file = b.path("includes/learnopengl/mesh.zig"),
        .target = target,
        .optimize = optimize,
    });
    mesh_module.addImport("Shader", shader_module);
    mesh_module.addImport("zopengl", zopengl.module("root"));
    mesh_module.addImport("zalgebra", zalgebra.module("zalgebra"));
    mesh_module.addImport("zstbi", zstbi.module("root"));
    const obj_module = obj.module("obj");
    const model_module = b.addModule("Model", .{
        .root_source_file = b.path("includes/learnopengl/model.zig"),
        .target = target,
        .optimize = optimize,
    });
    model_module.addImport("Shader", shader_module);
    model_module.addImport("obj", obj_module);
    model_module.addImport("zopengl", zopengl.module("root"));
    model_module.addImport("zalgebra", zalgebra.module("zalgebra"));
    model_module.addImport("zstbi", zstbi.module("root"));

    return .{
        .zmath = zmath,
        .zalgebra = zalgebra,
        .zstbi = zstbi,
        .zopengl = zopengl,
        .zglfw = zglfw,
        .shader = shader_module,
        .camera = camera_module,
        .mesh = mesh_module,
        .obj = obj_module,
        .model = model_module,
    };
}

const getting_started = [_][]const u8{
    "1.1.hello_window/hello_window",
    "1.2.hello_window_clear/hello_window_clear",
    "2.1.hello_triangle/hello_triangle",
    "2.2.hello_triangle_indexed/hello_triangle_indexed",
    "2.3.hello_triangle_exercise1/hello_triangle_exercise1",
    "2.4.hello_triangle_exercise2/hello_triangle_exercise2",
    "2.5.hello_triangle_exercise3/hello_triangle_exercise3",
    "3.1.shaders_uniform/shaders_uniform",
    "3.2.shaders_interpolation/shaders_interpolation",
    "3.3.shaders_class/shaders_class",
    "3.4.shaders_exercise1/shaders_exercise1",
    "3.5.shaders_exercise2/shaders_exercise2",
    "3.6.shaders_exercise3/shaders_exercise3",
    "4.1.textures/textures",
    "4.2.textures_combined/textures_combined",
    "4.3.textures_exercise1/textures_exercise1",
    "4.4.textures_exercise2/textures_exercise2",
    "4.5.textures_exercise3/textures_exercise3",
    "4.6.textures_exercise4/textures_exercise4",
    "5.1.transformations/transformations",
    "5.2.transformations_exercise1/transformations_exercise1",
    "5.3.transformations_exercise2/transformations_exercise2",
    "6.1.coordinate_systems/coordinate_systems",
    "6.2.coordinate_systems_depth/coordinate_systems_depth",
    "6.3.coordinate_systems_multiple/coordinate_systems_multiple",
    "6.4.coordinate_systems_exercise3/coordinate_systems_exercise3",
    "7.1.camera_circle/camera_circle",
    "7.2.camera_keyboard_dt/camera_keyboard_dt",
    "7.3.camera_mouse_zoom/camera_mouse_zoom",
    "7.4.camera_class/camera_class",
    "7.5.camera_class_exercise1/camera_class_exercise1",
};

const lighting = [_][]const u8{
    "1.colors/colors",
    "2.1.basic_lighting_diffuse/basic_lighting_diffuse",
    "2.2.basic_lighting_specular/basic_lighting_specular",
    "2.3.basic_lighting_exercise1/basic_lighting_exercise1",
    "2.4.basic_lighting_exercise2/basic_lighting_exercise2",
    "2.5.basic_lighting_exercise3/basic_lighting_exercise3",
    "3.1.materials/materials",
    "3.2.materials_exercise1/materials_exercise1",
    "4.1.lighting_maps_diffuse_map/lighting_maps_diffuse_map",
    "4.2.lighting_maps_specular_map/lighting_maps_specular_map",
    "4.3.lighting_maps_exercise2/lighting_maps_exercise2",
    "4.4.lighting_maps_exercise4/lighting_maps_exercise4",
    "5.1.light_casters_directional/light_casters_directional",
    "5.2.light_casters_point/light_casters_point",
    "5.3.light_casters_spot/light_casters_spot",
    "5.4.light_casters_spot_soft/light_casters_spot_soft",
    "6.1.multiple_lights/multiple_lights",
    "6.2.multiple_lights_exercise1/multiple_lights_exercise1",
};

const model_loading = [_][]const u8{
    "1.model_loading/model_loading",
};

const advanced_opengl = [_][]const u8{
    "1.1.depth_testing/depth_testing",
    "1.2.depth_testing_view/depth_testing_view",
    "2.stencil_testing/stencil_testing",
    "3.1.blending_discard/blending_discard",
    "3.2.blending_sort/blending_sort",
    "4.face_culling_exercise1/face_culling_exercise1",
    "5.1.framebuffers/framebuffers",
    "5.2.framebuffers_exercise1/framebuffers_exercise1",
    "6.1.cubemaps_skybox/cubemaps_skybox",
    "6.2.cubemaps_environment_mapping/cubemaps_environment_mapping",
    "8.advanced_glsl_ubo/advanced_glsl_ubo",
    "9.1.geometry_shader_houses/geometry_shader_houses"
};

const advanced_lighting = [_][]const u8{
    "1.advanced_lighting/advanced_lighting",
    "2.gamma_correction/gamma_correction",
    "3.1.1.shadow_mapping_depth/shadow_mapping_depth",
    "3.1.2.shadow_mapping_base/shadow_mapping_base"
};
