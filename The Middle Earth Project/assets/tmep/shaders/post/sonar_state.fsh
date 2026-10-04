#version 330
#extension GL_ARB_separate_shader_objects : require

#include <minecraft:globals.glsl>
#include <tmep:precision.glsl>

uniform sampler2D InSampler;

layout(location = 0) in vec2 texCoord;

layout(location = 0) out vec4 fragColor;

void main() {
    vec4 previous = texelFetch(InSampler, ivec2(0), 0);
    if (previous.b > 0.5 && previous.a > 0.5) {
        float elapsed = fract(GameTime - precise_decode(previous) + 1.0) * 1200.0;
        if (elapsed < 4.5) {
            fragColor = previous;
            return;
        }
    }
    fragColor = precise_encode(GameTime);
    fragColor.b = 1.0;
}
