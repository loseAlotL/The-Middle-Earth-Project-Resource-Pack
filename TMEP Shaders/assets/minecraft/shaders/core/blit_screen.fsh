#version 330
#extension GL_ARB_separate_shader_objects : require

#include <tmep:water_depth.glsl>

uniform sampler2D InSampler;

layout(location = 0) in vec2 texCoord;

layout(location = 0) out vec4 fragColor;

void main() {
    vec4 color = texture(InSampler, texCoord);
    if (color.a == 0.0 && color.b == 0.0) {
        ivec2 pixel = ivec2(gl_FragCoord.xy);
        bool near = false;
        const ivec2 probes[8] = ivec2[](ivec2(1, 0), ivec2(-1, 0), ivec2(0, 1), ivec2(0, -1), ivec2(1, 1), ivec2(-1, 1), ivec2(1, -1), ivec2(-1, -1));
        for (int i = 0; i < 8; i++) {
            vec4 probe = texelFetch(InSampler, pixel + probes[i], 0);
            near = near || (water_bounds_marked(probe.a) && water_depth_is_water(probe.b));
        }
        if (!near) {
            fragColor = color;
            return;
        }
        for (int y = -2; y <= 2; y++) {
            for (int x = -2; x <= 2; x++) {
                vec4 candidate = texelFetch(InSampler, pixel + ivec2(x, y), 0);
                if (water_bounds_marked(candidate.a) && water_depth_is_water(candidate.b)) {
                    color = vec4(candidate.rgb, 0.0);
                }
            }
        }
    }
    fragColor = color;
}
