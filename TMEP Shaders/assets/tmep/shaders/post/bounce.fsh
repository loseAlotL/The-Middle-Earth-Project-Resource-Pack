#version 330
#extension GL_ARB_separate_shader_objects : require

#define CAMERA_FROM_QUAD

#include <tmep:water_post.glsl>

uniform sampler2D InSampler;
uniform sampler2D DepthSampler;

layout(location = 0) in vec2 texCoord;

layout(std140) uniform BounceConfig {
    vec4 Bounce;
};

layout(location = 0) out vec4 fragColor;

vec3 pointAt(Camera camera, ivec2 pixel, ivec2 screen) {
    pixel = clamp(pixel, ivec2(0), screen - 1);
    return camera_relative(camera, (vec2(pixel) + 0.5) / vec2(screen), max(water_post_scene_depth(DepthSampler, pixel), 1e-7));
}

void main() {
    fragColor = vec4(0.0);
    int samples = int(Bounce.x);
    if (samples <= 0) {
        return;
    }
    Camera camera = camera_load(InSampler);
    if (!camera.valid || camera.underwater) {
        return;
    }
    ivec2 screen = textureSize(DepthSampler, 0);
    ivec2 pixel = clamp(ivec2(texCoord * vec2(screen)), ivec2(0), screen - 1);
    float depth = water_post_scene_depth(DepthSampler, pixel);
    if (depth <= 0.0 || water_post_is_hand_depth(depth)) {
        return;
    }
    vec3 center = pointAt(camera, pixel, screen);
    float distance = length(center);
    if (distance > Bounce.w) {
        return;
    }
    vec3 dx = pointAt(camera, pixel + ivec2(2, 0), screen) - center;
    vec3 dy = pointAt(camera, pixel + ivec2(0, 2), screen) - center;
    vec3 normal = normalize(cross(dx, dy));
    normal = dot(normal, center) > 0.0 ? -normal : normal;
    vec3 tangent = normalize(abs(normal.y) < 0.9 ? cross(normal, vec3(0.0, 1.0, 0.0)) : cross(normal, vec3(1.0, 0.0, 0.0)));
    vec3 bitangent = cross(normal, tangent);
    mat4 viewProjection = camera.projection * camera.view;
    float noise = fract(52.9829189 * fract(dot(gl_FragCoord.xy, vec2(0.06711056, 0.00583715))));
    vec3 gathered = vec3(0.0);
    float weight = 0.0;
    for (int i = 0; i < 16; i++) {
        if (i >= samples) {
            break;
        }
        float f = (float(i) + noise) / float(samples);
        float angle = float(i) * 2.3999632 + noise * 6.2831853;
        vec3 offset = (tangent * cos(angle) * sqrt(f) + bitangent * sin(angle) * sqrt(f) + normal * sqrt(1.0 - f)) * Bounce.y;
        bool visible;
        vec2 uv = water_post_project(viewProjection, center + offset, visible);
        if (!visible) {
            continue;
        }
        ivec2 tap = clamp(ivec2(uv * vec2(screen)), ivec2(0), screen - 1);
        float tapDepth = water_post_scene_depth(DepthSampler, tap);
        if (tapDepth <= 0.0 || water_post_is_hand_depth(tapDepth) || camera_is_data_pixel(tap)) {
            continue;
        }
        vec3 source = camera_relative(camera, uv, tapDepth) - center;
        float reach = length(source);
        float facing = dot(source, normal) / max(reach, 1e-3);
        if (reach < 0.2 || reach > Bounce.y * 2.5 || facing < 0.1) {
            continue;
        }
        float w = facing / (1.0 + reach * reach * 0.3);
        gathered += texelFetch(InSampler, tap, 0).rgb * w;
        weight += w;
    }
    fragColor = weight > 1e-4 ? vec4(gathered / weight, clamp(weight / float(samples) * 2.0, 0.0, 1.0)) : vec4(0.0);
}
