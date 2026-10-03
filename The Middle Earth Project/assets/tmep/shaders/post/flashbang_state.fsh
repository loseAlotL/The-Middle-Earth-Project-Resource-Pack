#version 330

#extension GL_ARB_separate_shader_objects : require

#include <minecraft:globals.glsl>

uniform sampler2D InSampler;

layout(location = 0) in vec2 texCoord;
layout(location = 0) out vec4 fragColor;

void main() {
    vec4 previous = texelFetch(InSampler, ivec2(0), 0);
    if (previous.a > 0.5) {
        fragColor = previous;
        return;
    }
    float scaled = GameTime * 255.0;
    fragColor = vec4(floor(scaled) / 255.0, fract(scaled), 0.0, 1.0);
}
