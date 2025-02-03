const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zglfw = b.dependency("zglfw", .{
        .target = target,
    });

    const zopengl = b.dependency("zopengl", .{ .target = target });
    const zstbi = b.dependency("zstbi", .{ .target = target });
    const zmath = b.dependency("zmath", .{ .target = target });
    const zgui = b.dependency("zgui", .{
        .target = target,
        .backend = .glfw_opengl3,
    });

    // modules
    const shader_module = b.addModule("Shader", .{ .root_source_file = b.path("includes/learnopengl/shader.zig") });
    shader_module.addImport("zopengl", zopengl.module("root"));
    const common_module = b.addModule("common", .{ .root_source_file = b.path("includes/learnopengl/common.zig") });
    const camera_module = b.addModule("Camera", .{ .root_source_file = b.path("includes/learnopengl/camera.zig") });
    camera_module.addImport("zmath", zmath.module("root"));
    camera_module.addImport("common", common_module);

    // Build getting_started
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

    const lighting_step = b.step("lighting", "Build lighting examples");
    inline for (lighting) |example_name| {
        var example_name_split_iter = std.mem.splitScalar(u8, example_name, '/');
        const actual_example_name = example_name_split_iter.next().?;
        const example = b.addExecutable(.{
            .name = actual_example_name,
            .root_source_file = b.path("src/2.lighting/" ++ example_name ++ ".zig"),
            .target = target,
            .optimize = optimize,
        });

        // Add imports and/or link libraries if necessary
        example.root_module.addImport("zglfw", zglfw.module("root"));
        example.linkLibrary(zglfw.artifact("glfw"));
        example.root_module.addImport("zopengl", zopengl.module("root"));
        example.root_module.addImport("zstbi", zstbi.module("root"));
        example.linkLibrary(zstbi.artifact("zstbi"));
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

    const advanced_opengl_step = b.step("advanced_opengl", "Build lighting examples");
    inline for (advanced_opengl) |example_name| {
        var example_name_split_iter = std.mem.splitScalar(u8, example_name, '/');
        const actual_example_name = example_name_split_iter.next().?;
        const example = b.addExecutable(.{
            .name = actual_example_name,
            .root_source_file = b.path("src/4.advanced_opengl/" ++ example_name ++ ".zig"),
            .target = target,
            .optimize = optimize,
        });

        // Add imports and/or link libraries if necessary
        example.root_module.addImport("zglfw", zglfw.module("root"));
        example.linkLibrary(zglfw.artifact("glfw"));
        example.root_module.addImport("zopengl", zopengl.module("root"));
        example.root_module.addImport("zstbi", zstbi.module("root"));
        example.linkLibrary(zstbi.artifact("zstbi"));
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
    all_step.dependOn(lighting_step);
    // TODO: Add model loading step
    all_step.dependOn(advanced_opengl_step);

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
    "1_1_model_loading",
};

const advanced_opengl = [_][]const u8{
    "1.1.depth_testing/depth_testing",
    "1.2.depth_testing_view/depth_testing_view",
    "2.stencil_testing/stencil_testing",
    "3.1.blending_discard/blending_discard",
    "6.1.cubemaps_skybox/cubemaps_skybox",
};