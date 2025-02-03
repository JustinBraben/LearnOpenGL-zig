const std = @import("std");
const math = std.math;

pub fn pathToContent(arena: std.mem.Allocator, resource_relative_path: [:0]const u8) ![4096:0] u8 {
    const exe_path = std.fs.selfExeDirPathAlloc(arena) catch unreachable;
    const content_path = std.fs.path.join(arena, &.{exe_path, resource_relative_path}) catch unreachable;
    var content_path_zero : [4096:0]u8 = undefined;
    if (content_path.len >= 4096) return error.NameTooLong;
    std.mem.copyForwards(u8, &content_path_zero, content_path);
    content_path_zero[content_path.len] = 0;
    return content_path_zero; 
}

pub fn radians(input: f32) f32 {
    return RAD_CONVERSION * input;
}

/// Create the transformation matrices:
/// Degree to radians conversion factor
pub const RAD_CONVERSION = math.pi / 180.0;