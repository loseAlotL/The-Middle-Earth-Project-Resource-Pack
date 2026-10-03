#version 330
#extension GL_ARB_separate_shader_objects : require

#include <tmep:water_post.glsl>

uniform sampler2D InSampler;
uniform sampler2D DepthSampler;

layout(location = 0) in vec2 texCoord;

layout(location = 0) out vec4 fragColor;

void main() {
    ivec2 source = textureSize(InSampler, 0);
    vec2 cell = vec2(source) / vec2(256.0, 144.0);
    vec3 total = vec3(0.0);
    for (int y = 0; y < 4; y++) {
        for (int x = 0; x < 4; x++) {
            vec2 position = (floor(gl_FragCoord.xy) + (vec2(float(x), float(y)) + 0.5) / 4.0) * cell;
            ivec2 coord = clamp(ivec2(position), ivec2(0), source - 1);
            vec4 pixel = texelFetch(InSampler, coord, 0);
            float depth = texelFetch(DepthSampler, coord, 0).r;
            if ((abs(pixel.a - 0.75) < 0.01 || abs(pixel.a - 0.62) < 0.01) && !water_post_is_rain_depth(depth) && !water_post_is_hand_depth(depth) && !water_depth_is_water(depth) && !water_post_is_underside_depth(depth)) {
                total += pixel.rgb;
            }
        }
    }
    fragColor = vec4(total / 16.0, 1.0);
}
