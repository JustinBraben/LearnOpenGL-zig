# LearnOpenGL Zig

Rewrite of [LearnOpenGL example source code](https://github.com/JoeyDeVries/LearnOpenGL) in Zig language.

# Instructions on how to build this repository

## Prerequisites

First of all you'll need to have Zig `0.14.0` on your system.

## Build the source code

To build everything, switch to the repository root directory and run:

```shell
zig build
```

To see which examples to explicitly run, use:

```shell
zig build -l
```

For example, to run example code within the "Hello Triangle" section of "Getting started" chapter,
execute in shell as the following (assuming you are in the repository root directory initially):

```shell
zig build run-2.1.hello_triangle
```

## Dependencies

- [zmath](https://github.com/zig-gamedev/zmath): SIMD math library for Zig game developers
- [zstbi](https://github.com/zig-gamedev/zstbi): Zig bindings and build package for stb_image, stb_image_resize and stb_image_write
- [zopengl](https://github.com/zig-gamedev/zopengl): OpenGL loader and bindings for Zig.
- [zglfw](https://github.com/zig-gamedev/zglfw): Zig build package and bindings for GLFW 
- [zmesh](https://github.com/zig-gamedev/zmesh): Zig library for loading, generating, processing and optimising triangle meshes.

## License

For the images, audios and models used under this repository (under the `resources` directory), licensed under the
[CC BY 4.0](https://spdx.org/licenses/CC-BY-4.0.html) license as mentioned in
[LearnOpenGL About](https://learnopengl.com/About) page.

For the other parts, licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
