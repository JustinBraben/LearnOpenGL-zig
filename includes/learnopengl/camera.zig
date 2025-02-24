const std = @import("std");
const math = std.math;
const zm = @import("zmath");
const Shader = @import("Shader");

const Camera = @This();

pub const CameraMovement = enum {
    FORWARD,
    BACKWARD,
    LEFT,
    RIGHT,
};

// Default camera values
const YAW: f32 = -90.0;
const PITCH: f32 = 0.0;
const SPEED: f32 = 2.5;
const SENSITIVITY: f32 = 0.1;
const ZOOM: f32 = 45.0;

// Camera attributes
position: zm.F32x4 = zm.loadArr3(.{ 0.0, 0.0, 0.0 }),
front: zm.F32x4 = zm.loadArr3(.{ 0.0, 0.0, -1.0 }),
up: zm.F32x4 = undefined,
right: zm.F32x4 = undefined,
world_up: zm.F32x4 = zm.loadArr3(.{ 0.0, 1.0, 0.0 }),

// euler Angles
yaw: f32 = -90.0,
pitch: f32 = 0.0,

// camera options
movement_speed: f32 = SPEED,
mouse_sensitivity: f32 = SENSITIVITY,
zoom: f32 = 45.0,
speed_modifier: f32 = 1.0,

/// Initialize the camera.
/// If null is passed initial position is .{0.0, 0.0, 0.0}
pub fn init(position: ?zm.F32x4) Camera {
    const front = zm.loadArr3(.{ 0.0, 0.0, -1.0 });
    const world_up = zm.loadArr3(.{ 0.0, 1.0, 0.0 });
    const right = zm.normalize3(zm.cross3(front, world_up));
    const up = zm.normalize3(zm.cross3(right, front));

    return .{
        .position = if (position) |val| val else zm.loadArr3(.{ 0.0, 0.0, 0.0 }),
        .world_up = up,
        .right = right,
    };
}

/// returns the view matrix calculated using Euler Angles and the LookAt Matrix
pub fn getViewMatrix(self: *Camera) zm.Mat {
    return zm.lookAtRh(self.position, self.position + self.front, self.up);
}

/// returns the view position of camera as [3]f32
pub fn getViewPos(self: *Camera) [3]f32 {
    return zm.vecToArr3(self.position);
}

pub fn getFrontPos(self: *Camera) [3]f32 {
    return zm.vecToArr3(self.front);
}

/// processes input received from any keyboard-like input system.
/// Accepts input parameter in the form of camera defined ENUM (to abstract it from windowing systems)
pub fn processKeyboard(self: *Camera, direction: Camera.CameraMovement, delta_time: f32) void {
    // const velocity = self.movement_speed * delta_time;
    // const velocity_vec = zm.f32x4s(velocity);
    // const modified_velocity = velocity_vec * @as(zm.Vec, @splat(self.speed_modifier));
    const velocity = zm.f32x4s(self.movement_speed * delta_time) * @as(zm.Vec, @splat(self.speed_modifier));
    switch (direction) {
        .FORWARD => self.position += self.front * velocity,
        .BACKWARD => self.position -= self.front * velocity,
        .LEFT => self.position -= self.right * velocity,
        .RIGHT => self.position += self.right * velocity,
    }
    // make sure the user stays at the ground level
    // self.position[1] = 0.0;
}

/// Processes input received from a mouse input system.
/// Expects the offset value in both the x and y direction.
pub fn processMouseMovement(self: *Camera, x_offset: f64, y_offset: f64, constrain_pitch: bool) void {
    // const _xoffset = @as(f32, @floatCast(xoffset)) * SENSITIVITY;
    // const _yoffset = @as(f32, @floatCast(yoffset)) * SENSITIVITY;
    const xoff: f32 = @as(f32, @floatCast(x_offset)) * self.mouse_sensitivity;
    const yoff: f32 = @as(f32, @floatCast(y_offset)) * self.mouse_sensitivity;

    self.yaw += xoff;
    self.pitch += yoff;

    // make sure that when pitch is out of bounds, screen doesn't get flipped
    if (constrain_pitch) {
        if (self.pitch > 89.0)
            self.pitch = 89.0;
        if (self.pitch < -89.0)
            self.pitch = -89.0;
    }

    // update Front, Right and Up Vectors using the updated Euler angles
    self.updateCameraVectors();
}

/// Processes input received from a mouse scroll-wheel event.
/// Only requires input on the vertical wheel-axis
pub fn processMouseScroll(self: *Camera, yoffset: f64) void {
    self.zoom -= @as(f32, @floatCast(yoffset));
    if (self.zoom < 1.0)
        self.zoom = 1.0;
    if (self.zoom > 45.0)
        self.zoom = 45.0;
}

/// Calculates the front vector from the Camera's (updated) Euler Angles
fn updateCameraVectors(self: *Camera) void {
    // Calculate the new front vector
    const pitch_rad = math.degreesToRadians(self.pitch);
    const yaw_rad = math.degreesToRadians(self.yaw);
    
    // calculate the new Front vector
    const x = @cos(yaw_rad) * @cos(pitch_rad);
    const y = @sin(pitch_rad);
    const z = @sin(yaw_rad) * @cos(pitch_rad);
    
    self.front = zm.normalize3(zm.f32x4(x, y, z, 0.0));

    // Re-calculate the Right and Up vector
    // Normalize the vectors, because their length gets closer to 0 the more you
    // look up or down which results in slower movement
    self.right = zm.normalize3(zm.cross3(self.front, self.world_up));
    self.up = zm.normalize3(zm.cross3(self.right, self.front));
}
