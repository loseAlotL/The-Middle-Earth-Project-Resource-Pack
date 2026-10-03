#version 330
#extension GL_ARB_separate_shader_objects : require

#include <minecraft:fog.glsl>
#include <minecraft:dynamictransforms.glsl>

layout(location = 0) in float sphericalVertexDistance;
layout(location = 1) in float cylindricalVertexDistance;

layout(location = 0) out vec4 fragColor;

void main() {
    vec3 color = apply_fog(ColorModulator, sphericalVertexDistance, cylindricalVertexDistance, 0.0, FogSkyEnd, FogSkyEnd, FogSkyEnd, FogColor).rgb;
    uvec3 bytes = uvec3(clamp(color, 0.0, 1.0) * 255.0 + 0.5);
    fragColor = vec4(vec3((bytes & uvec3(248u)) | uvec3(5u, 2u, 6u)) / 255.0, 0.0);
}
