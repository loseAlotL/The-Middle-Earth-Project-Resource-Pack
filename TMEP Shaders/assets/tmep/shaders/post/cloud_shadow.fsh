#version 330
#extension GL_ARB_separate_shader_objects : require

#define CAMERA_FROM_QUAD

#include <tmep:water_post.glsl>
#include <tmep:atmosphere.glsl>

uniform sampler2D InSampler;
uniform sampler2D DepthSampler;

layout(location = 0) in vec2 texCoord;

layout(std140) uniform CloudShadowConfig {
    vec4 CloudShadow;
};

layout(location = 0) out vec4 fragColor;

void main() {
    fragColor = vec4(0.0);
    if (CloudShadow.x <= 0.0) {
        return;
    }
    Camera camera = camera_load(InSampler);
    if (!camera.valid || !camera.skyValid || camera.underwater) {
        return;
    }
    ivec2 screen = textureSize(DepthSampler, 0);
    ivec2 pixel = clamp(ivec2(texCoord * vec2(screen)), ivec2(0), screen - 1);
    float depth = water_post_scene_depth(DepthSampler, pixel);
    if (depth <= 0.0) {
        return;
    }
    LightState state = atmos_state(camera);
    vec3 sun = camera_sun_direction(camera);
    if (sun.y < 0.03 || state.sunVisibility <= 0.0) {
        return;
    }
    vec3 point = camera_relative(camera, texCoord, depth) + camera_world_origin();
    float time = GameTime * 1200.0;
    float cover = 0.0;
    float slabHeight = ATMOS_CLOUD_BOTTOM + ATMOS_CLOUD_THICKNESS * 0.4;
    if (point.y < slabHeight) {
        vec3 q = point + sun * ((slabHeight - point.y) / sun.y);
        float coverage = mix(ATMOS_CLOUD_COVERAGE, ATMOS_CLOUD_COVERAGE - 0.18, state.rain) + atmos_cloud_bias(q.xz, time);
        cover = atmos_cloud_density(q, time, coverage, 3, 0.0) * 1.3;
    }
    float towerHeight = ATMOS_TOWER_BASE + 220.0;
    if (point.y < towerHeight) {
        vec3 q = point + sun * ((towerHeight - point.y) / sun.y);
        vec2 shift = ATMOS_CLOUD_WIND * time * 0.6;
        vec3 local = vec3(q.x - shift.x, q.y, q.z - shift.y);
        Tower tower;
        if (atmos_tower(floor(local.xz / ATMOS_TOWER_CELL), time, tower)) {
            cover += atmos_tower_density(tower, local, 0.0, false);
        }
    }
    float shadow = clamp(cover, 0.0, 1.0) * state.sunVisibility * (1.0 - state.rain) * smoothstep(0.03, 0.15, sun.y);
    fragColor = vec4(shadow, 0.0, 0.0, 1.0);
}
