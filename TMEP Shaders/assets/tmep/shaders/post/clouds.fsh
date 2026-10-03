#version 330
#extension GL_ARB_separate_shader_objects : require

#define CAMERA_FROM_QUAD

#include <tmep:water_post.glsl>
#include <tmep:atmosphere.glsl>

uniform sampler2D InSampler;
uniform sampler2D DepthSampler;
uniform sampler2D HistorySampler;
uniform sampler2D PreviousCameraSampler;
uniform sampler2D WeatherSampler;

layout(location = 0) in vec2 texCoord;

layout(std140) uniform SkyConfig {
    vec4 Clouds;
};

layout(location = 0) out vec4 fragColor;

float previousSlot(int slot) {
    return camera_data_decode(texelFetch(PreviousCameraSampler, ivec2(slot, 0), 0).rgb);
}

mat4 previousMatrix(int base) {
    mat4 m;
    for (int c = 0; c < 4; c++) {
        for (int r = 0; r < 4; r++) {
            m[c][r] = previousSlot(base + c * 4 + r);
        }
    }
    return m;
}

vec4 traceClouds(Camera camera, vec3 direction, float limit, int steps) {
    LightState state = atmos_state(camera);
    atmos_apply_weather(WeatherSampler, state);
    vec3 sun = camera_sun_direction(camera);
    vec3 skyLinear = atmos_sky_smooth(direction, sun, state);
    float time = GameTime * 1200.0 * Clouds.y;
    vec4 puffs = atmos_clouds(camera_world_origin(), direction, limit, time, sun, state, steps, skyLinear);
    vec4 towers = atmos_towers(camera_world_origin(), direction, limit, time, sun, state, skyLinear);
    if (camera_world_origin().y < ATMOS_OVERCAST_HEIGHT) {
        towers *= 1.0 - atmos_overcast(camera_world_origin(), direction, time, sun, state, skyLinear).a;
    }
    vec4 clouds = vec4(puffs.rgb + towers.rgb * (1.0 - puffs.a), puffs.a + towers.a * (1.0 - puffs.a));
    clouds.rgb += atmos_cloud_optics(direction, sun, state, clouds.a) * clouds.a;
    clouds.rgb = atmos_shadow_tint(clouds.rgb, atmos_earth_shadow(direction, sun) * 0.85);
    if (clouds.a <= 0.001) {
        return vec4(0.0);
    }
    return vec4(light_tonemap(clouds.rgb / clouds.a) * clouds.a, clouds.a);
}

void main() {
    fragColor = vec4(0.0);
    int steps = int(Clouds.x);
    if (steps <= 0) {
        return;
    }
    Camera camera = camera_load(InSampler);
    if (!camera.valid || !camera.skyValid || camera.underwater) {
        return;
    }
    ivec2 screen = textureSize(DepthSampler, 0);
    ivec2 pixel = clamp(ivec2(texCoord * vec2(screen)), ivec2(0), screen - 1);
    float depth = water_post_scene_depth(DepthSampler, pixel);
    vec3 direction = camera_ray(camera, texCoord);
    bool distantTerrain = depth <= 0.0 && !camera_open_sky(camera, direction, depth, InSampler, pixel);
    float limit = depth > 0.0 ? length(camera_relative(camera, texCoord, depth)) : (distantTerrain ? 256.0 : 1e5);
    bool hidden = limit < 150.0;

    float weight = 0.0;
    vec4 history = vec4(0.0);
    if (abs(previousSlot(CAMERA_DATA_MAGIC_SLOT) - CAMERA_DATA_MAGIC) < 0.25) {
        mat4 previousView = previousMatrix(0);
        mat4 previousProjection = previousMatrix(16);
        vec4 clip = previousProjection * vec4(mat3(previousView) * direction, 0.0);
        if (clip.w > 1e-4) {
            vec2 uv = clip.xy / clip.w * 0.5 + 0.5;
            if (all(greaterThanEqual(uv, vec2(0.0))) && all(lessThanEqual(uv, vec2(1.0)))) {
                vec3 previousOrigin = vec3(previousSlot(CAMERA_DATA_SLOTS), previousSlot(CAMERA_DATA_SLOTS + 1), previousSlot(CAMERA_DATA_SLOTS + 2));
                float moved = length(camera_world_origin() - previousOrigin);
                weight = Clouds.z * exp(-moved * 0.35);
                history = texture(HistorySampler, uv);
                history.rgb *= history.a;
            }
        }
    }
    bool refresh = fract(GameTime * 24000.0 * 7.31 + atmos_hash(gl_FragCoord.xy * 1.37 + 5.7)) < 0.15;
    if (hidden && weight > 0.0 && !refresh) {
        fragColor = history.a > 1e-4 ? vec4(history.rgb / history.a, history.a) : vec4(0.0);
        return;
    }
    atmosJitter = fract(GameTime * 24000.0 * 0.7548777 + atmos_hash(gl_FragCoord.xy * 0.731 + 3.1));
    vec4 current = traceClouds(camera, direction, hidden ? 1e5 : limit, steps);
    vec4 blended = mix(current, history, weight);
    fragColor = blended.a > 1e-4 ? vec4(blended.rgb / blended.a, blended.a) : vec4(0.0);
}
