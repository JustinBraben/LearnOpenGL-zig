#version 410 core
out vec4 FragColor;
// in vec3 ourColor;
in vec3 ourPosition;

void main()
{
    FragColor = vec4(ourPosition, 1.0f);   // note how the position value is linearly interpolated to get all the different colors
}