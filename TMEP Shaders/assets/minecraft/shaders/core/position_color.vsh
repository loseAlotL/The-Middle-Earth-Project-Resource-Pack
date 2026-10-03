#version 330
#extension GL_ARB_separate_shader_objects : require

#include <minecraft:dynamictransforms.glsl>
#include <minecraft:projection.glsl>

layout(location = 0) in vec3 Position;
layout(location = 1) in vec4 Color;

layout(location = 0) out vec4 vertexColor;

void main() {
    gl_Position = ProjMat * ModelViewMat * vec4(Position, 1.0);

    float radius = length(Position);
    bool skyFan = ProjMat[2][3] != 0.0 && radius > 98.0 && radius < 132.0;
    vertexColor = skyFan ? vec4(0.0) : Color;
}
