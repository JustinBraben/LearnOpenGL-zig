const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zglfw = b.dependency("zglfw", .{
        .target = target,
    });

    const zopengl = b.dependency("zopengl", .{});
    const zstbi = b.dependency("zstbi", .{});
    const zmath = b.dependency("zmath", .{});
    const zgui = b.dependency("zgui", .{
        .backend = .glfw_opengl3,
    });

    // modules
    const shader_module = b.addModule("Shader", .{ .root_source_file = b.path("includes/learnopengl/shader.zig") });
    shader_module.addImport("zopengl", zopengl.module("root"));
    const common_module = b.addModule("common", .{ .root_source_file = b.path("includes/learnopengl/common.zig") });
    const camera_module = b.addModule("Camera", .{ .root_source_file = b.path("includes/learnopengl/camera.zig") });
    camera_module.addImport("zmath", zmath.module("root"));
    camera_module.addImport("common", common_module);

    const getting_started_step = b.step("getting_started", "Build getting_started examples");
    inline for (getting_started) |example_name| {
        var example_name_split_iter = std.mem.splitScalar(u8, example_name, '/');
        const actual_example_name = example_name_split_iter.next().?;
        const example = b.addExecutable(.{
            .name = actual_example_name,
            .root_source_file = b.path("src/1.getting_started/" ++ example_name ++ ".zig"),
            .target = target,
            .optimize = optimize,
        });

        // Add imports and/or link libraries if necessary
        example.root_module.addImport("zglfw", zglfw.module("root"));
        example.linkLibrary(zglfw.artifact("glfw"));
        example.root_module.addImport("zopengl", zopengl.module("root"));
        example.root_module.addImport("zstbi", zstbi.module("root"));
        example.linkLibrary(zstbi.artifact("zstbi"));
        example.root_module.addImport("zgui", zgui.module("root"));
        example.linkLibrary(zgui.artifact("imgui"));
        example.root_module.addImport("zmath", zmath.module("root"));
        example.root_module.addImport("Shader", shader_module);
        example.root_module.addImport("common", common_module);
        example.root_module.addImport("Camera", camera_module);

        const compile_step = b.step(example_name, "Build " ++ example_name);
        compile_step.dependOn(&b.addInstallArtifact(example, .{}).step);
        b.getInstallStep().dependOn(compile_step);

        const run_cmd = b.addRunArtifact(example);
        run_cmd.step.dependOn(compile_step);

        const run_step = b.step("run-" ++ example_name, "Run " ++ example_name);
        run_step.dependOn(&run_cmd.step);
    }

    const all_step = b.step("all", "Build everything and runs all tests");
    all_step.dependOn(getting_started_step);

    b.default_step.dependOn(all_step);
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
    // "7.1.camera_circle/camera_circle",
    // "7.2.camera_keyboard_dt/camera_keyboard_dt",
    // "7.3.camera_mouse_zoom/camera_mouse_zoom",
    // "7.4.camera_class/camera_class",
    // "7.5.camera_class_exercise1/camera_class_exercise1",
};

const lighting = [_][]const u8{
    "1_1_light_cube",
    "2_1_basic_lighting_diffuse",
    "2_2_basic_lighting_specular",
    "3_1_materials",
    "3_2_materials_exercise1",
    "4_1_lighting_map_diffuse",
    "4_2_lighting_maps_specular",
    "5_1_light_casters_directional",
    "5_2_light_casters_point",
    "5_3_light_casters_spot",
    "5_4_light_casters_spot_soft",
    "6_0_multiple_lights",
    "6_1_multiple_lights_exercise1",
};

const model_loading = [_][]const u8{
    "1_1_model_loading",
};

const advanced_opengl = [_][]const u8{
    "1_1_depth_testing",
    "6_1_cubemaps_skybox",
};