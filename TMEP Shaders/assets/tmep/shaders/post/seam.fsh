#version 330
#extension GL_ARB_separate_shader_objects : require

#include <tmep:water_post.glsl>

uniform sampler2D InSampler;
uniform sampler2D DepthSampler;
uniform sampler2D SceneSampler;

layout(location = 0) in vec2 texCoord;

layout(location = 0) out vec4 fragColor;

int seamClass(Camera camera, ivec2 pixel, ivec2 screen) {
    pixel = clamp(pixel, ivec2(0), screen - 1);
    float depth = water_post_scene_depth(DepthSampler, pixel);
    if (depth > 0.0) {
        if (water_post_is_hand_depth(depth) || water_post_is_rain_depth(depth)) {
            return 0;
        }
        vec2 uv = (vec2(pixel) + 0.5) / vec2(screen);
        return length(camera_relative(camera, uv, depth)) > 64.0 ? 1 : 0;
    }
    vec4 raw = texelFetch(SceneSampler, pixel, 0);
    if (raw.a > 0.5 / 255.0 || camera_sky_stamped(raw.rgb) || all(lessThan(abs(raw.rgb - camera.fogColor), vec3(6.0 / 255.0)))) {
        return 0;
    }
    return 2;
}

void main() {
    ivec2 pixel = ivec2(gl_FragCoord.xy);
    vec4 center = texelFetch(InSampler, pixel, 0);
    fragColor = center;
    cameraScreenSize = textureSize(SceneSampler, 0);
    if (camera_is_data_pixel(pixel)) {
        return;
    }
    Camera camera = camera_load(SceneSampler);
    if (!camera.valid || !camera.skyValid || camera.underwater) {
        return;
    }
    ivec2 screen = textureSize(DepthSampler, 0);
    int own = seamClass(camera, pixel, screen);
    if (own == 0) {
        return;
    }
    const ivec2 directions[8] = ivec2[](ivec2(1, 0), ivec2(-1, 0), ivec2(0, 1), ivec2(0, -1), ivec2(1, 1), ivec2(-1, 1), ivec2(1, -1), ivec2(-1, -1));
    float reach = 0.0;
    for (int ring = 1; ring <= 4 && reach == 0.0; ring++) {
        for (int i = 0; i < 8; i++) {
            int other = seamClass(camera, pixel + directions[i] * ring * 2, screen);
            if (other != 0 && other != own) {
                reach = 1.0 - float(ring - 1) / 4.0;
                break;
            }
        }
    }
    if (reach == 0.0) {
        return;
    }
    vec3 total = vec3(0.0);
    float weights = 0.0;
    for (int y = -4; y <= 4; y++) {
        for (int x = -4; x <= 4; x++) {
            ivec2 tap = clamp(pixel + ivec2(x, y) * 2, ivec2(0), screen - 1);
            if (seamClass(camera, tap, screen) == 0) {
                continue;
            }
            float w = exp(-float(x * x + y * y) / 8.0);
            total += texelFetch(InSampler, tap, 0).rgb * w;
            weights += w;
        }
    }
    if (weights > 0.0) {
        fragColor = vec4(mix(center.rgb, total / weights, 0.85 * smoothstep(0.0, 1.0, reach)), center.a);
    }
}
