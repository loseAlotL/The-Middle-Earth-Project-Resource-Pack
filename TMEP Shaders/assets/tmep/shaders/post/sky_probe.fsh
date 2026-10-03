#version 330
#extension GL_ARB_separate_shader_objects : require

#define CAMERA_FROM_QUAD

#include <tmep:water_post.glsl>

uniform sampler2D InSampler;
uniform sampler2D DepthSampler;
uniform sampler2D ProbeSampler;

layout(location = 0) in vec2 texCoord;

layout(std140) uniform ProbeConfig {
    vec4 Probe;
};

layout(location = 0) out vec4 fragColor;

void main() {
    vec4 previous = texture(ProbeSampler, texCoord);
    fragColor = previous;
    Camera camera = camera_load(InSampler);
    if (!camera.valid || camera.underwater) {
        return;
    }

    vec3 direction = water_post_probe_direction(texCoord);
    bool visible;
    vec2 uv = water_post_project(camera.projection * camera.view, direction * 4096.0, visible);
    if (!visible) {
        return;
    }

    ivec2 screen = textureSize(DepthSampler, 0);
    ivec2 pixel = clamp(ivec2(uv * vec2(screen)), ivec2(0), screen - 1);
    if (camera_is_data_pixel(pixel)) {
        return;
    }
    float depth = texelFetch(DepthSampler, pixel, 0).r;
    bool distant = depth <= 0.0 || (!water_post_is_water_depth(depth) && length(camera_relative(camera, uv, depth)) > Probe.x);
    if (!distant) {
        return;
    }

    vec3 current = texelFetch(InSampler, pixel, 0).rgb;
    fragColor = vec4(previous.a > 0.5 ? mix(previous.rgb, current, Probe.y) : current, 1.0);
}
