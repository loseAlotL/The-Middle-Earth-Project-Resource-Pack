#version 330
#extension GL_ARB_separate_shader_objects : require

#include <minecraft:globals.glsl>

uniform sampler2D InSampler;

layout(location = 0) in vec2 texCoord;

layout(std140) uniform BloomConfig {
    vec4 Bloom;
};

layout(location = 0) out vec4 fragColor;

void main() {
    vec2 footprint = 1.0 / vec2(textureSize(InSampler, 0)) * max(vec2(textureSize(InSampler, 0)) / vec2(512.0, 288.0), vec2(1.0));
    vec3 total = vec3(0.0);
    float weight = 0.0;
    for (int y = -1; y <= 2; y++) {
        for (int x = -1; x <= 2; x++) {
            vec2 uv = texCoord + (vec2(x, y) - 0.5) * footprint * 0.5;
            vec3 color = texture(InSampler, uv).rgb;
            float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
            float bright = smoothstep(Bloom.x, Bloom.x + Bloom.y, luma);
            total += color * bright;
            weight += 1.0;
        }
    }
    fragColor = vec4(total / weight, 1.0);
}
