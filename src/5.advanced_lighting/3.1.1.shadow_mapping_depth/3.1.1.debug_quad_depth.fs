#version 410 core
out vec4 FragColor;

in vec2 TexCoords;

uniform sampler2D depthMap;
uniform float near_plane;
uniform float far_plane;

// required when using a perspective projection matrix
float LinearizeDepth(float depth)
{
    float z = depth * 2.0 - 1.0; // Back to NDC 
    return (2.0 * near_plane * far_plane) / (far_plane + near_plane - z * (far_plane - near_plane));	
}

void main()
{             
    float depthValue = texture(depthMap, TexCoords).r;
    
    // Option 1: Display depth as grayscale (simple visualization)
    FragColor = vec4(vec3(depthValue), 1.0);
    
    // Option 2: Linearize the depth for better visualization
    // float z = depthValue * 2.0 - 1.0; // Back to NDC 
    // float linearDepth = (2.0 * near_plane * far_plane) / (far_plane + near_plane - z * (far_plane - near_plane));
    // linearDepth = linearDepth / far_plane; // Normalize to 0-1 range
    // FragColor = vec4(vec3(linearDepth), 1.0);
}