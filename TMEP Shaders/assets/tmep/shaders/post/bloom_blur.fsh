#version 330
#extension GL_ARB_separate_shader_objects : require

#include <minecraft:globals.glsl>

uniform sampler2D InSampler;

layout(location = 0) in vec2 texCoord;

layout(std140) uniform BlurConfig {
    vec4 Blur;
};

layout(location = 0) out vec4 fragColor;

void main() {
    vec2 step = Blur.xy * Blur.z * (ScreenSize.y / 1080.0) / max(ScreenSize, vec2(1.0));
    vec3 total = vec3(0.0);
    float weight = 0.0;
    for (int i = -6; i <= 6; i++) {
        float w = exp(-float(i * i) / 18.0);
        total += texture(InSampler, texCoord + step * float(i)).rgb * w;
        weight += w;
    }
    fragColor = vec4(total / weight, 1.0);
}
