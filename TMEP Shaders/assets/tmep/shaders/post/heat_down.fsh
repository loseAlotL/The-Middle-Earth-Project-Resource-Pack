#version 330
#extension GL_ARB_separate_shader_objects : require

#include <tmep:water_post.glsl>
#include <tmep:lighting.glsl>

uniform sampler2D InSampler;
uniform sampler2D DepthSampler;

layout(location = 0) in vec2 texCoord;

layout(location = 0) out vec4 fragColor;

void main() {
    ivec2 source = textureSize(InSampler, 0);
    vec2 cell = vec2(source) / vec2(256.0, 144.0);
    float heat = 0.0;
    for (int y = 0; y < 3; y++) {
        for (int x = 0; x < 3; x++) {
            vec2 position = (floor(gl_FragCoord.xy) + (vec2(float(x), float(y)) + 0.5) / 3.0) * cell;
            ivec2 coord = clamp(ivec2(position), ivec2(0), source - 1);
            float depth = texelFetch(DepthSampler, coord, 0).r;
            if (water_post_is_water_depth(depth) || water_post_is_underside_depth(depth) || water_post_is_rain_depth(depth)) {
                continue;
            }
            if (light_heat_stamped(texelFetch(InSampler, coord, 0))) {
                heat += 1.0;
            }
        }
    }
    fragColor = vec4(heat / 9.0, 0.0, 0.0, 1.0);
}
