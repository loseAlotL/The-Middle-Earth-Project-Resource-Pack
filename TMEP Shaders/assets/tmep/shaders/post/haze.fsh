#version 330
#extension GL_ARB_separate_shader_objects : require

#define CAMERA_FROM_QUAD

#include <tmep:water_post.glsl>
#include <tmep:atmosphere.glsl>
#include <tmep:shader_params.glsl>

uniform sampler2D SceneSampler;
uniform sampler2D InSampler;
uniform sampler2D CameraSampler;
uniform sampler2D DepthSampler;
uniform sampler2D ParamsSampler;

layout(location = 0) in vec2 texCoord;

layout(std140) uniform HazeConfig {
    vec4 Haze;
};

layout(location = 0) out vec4 fragColor;

float godRays(Camera camera, vec3 sun, ivec2 screen) {
    bool visible;
    vec2 sunUv = water_post_project(camera.projection * camera.view, sun * 4096.0, visible);
    vec4 clip = camera.projection * camera.view * vec4(sun * 4096.0, 1.0);
    if (clip.w <= 0.0) {
        return 0.0;
    }
    sunUv = clip.xy / clip.w * 0.5 + 0.5;
    int samples = int(Haze.z);
    float jitter = fract(52.9829189 * fract(dot(gl_FragCoord.xy, vec2(0.06711056, 0.00583715))));
    float lit = 0.0;
    for (int i = 0; i < 32; i++) {
        if (i >= samples) {
            break;
        }
        vec2 uv = mix(texCoord, sunUv, (float(i) + jitter) / float(samples) * 0.9);
        if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) {
            continue;
        }
        lit += texture(CameraSampler, uv).a;
    }
    return lit / float(max(samples, 1));
}

void main() {
    ivec2 pixel = ivec2(gl_FragCoord.xy);
    vec4 raw = texelFetch(InSampler, pixel, 0);
    fragColor = raw;
    if (Haze.x <= 0.0 && Haze.z <= 0.0) {
        return;
    }
    Camera camera = camera_load(CameraSampler);
    if (!camera.valid || !camera.skyValid || camera.underwater || camera_is_data_pixel(pixel)) {
        return;
    }
    ivec2 screen = textureSize(DepthSampler, 0);
    float depth = water_post_scene_depth(DepthSampler, pixel);
    vec3 direction = camera_ray(camera, texCoord);
    LightState state = atmos_state(camera);
    vec3 sun = camera_sun_direction(camera);
    vec3 tint = atmos_sun_tint(state);
    float facing = max(dot(direction, sun), 0.0);
    vec3 color = raw.rgb;

    bool distantTerrain = depth <= 0.0 && !camera_open_sky(camera, direction, depth, SceneSampler, pixel);
    float estimated = direction.y < -0.002 ? min(max(camera_world_origin().y - 63.0, 1.0) / -direction.y, 1200.0) : 1200.0;
    if ((depth > 0.0 || distantTerrain) && Haze.x > 0.0) {
        vec3 point = depth > 0.0 ? camera_relative(camera, texCoord, depth) : direction * estimated;
        float distance = length(point);
        vec3 origin = camera_world_origin();
        float amount = atmos_haze_amount(distance, origin.y, origin.y + point.y, state, camera.daytime) * Haze.x;
        vec3 horizonDirection = normalize(vec3(direction.x, max(direction.y, 0.0) * 0.35 + 0.03, direction.z));
        vec3 hazeLinear = atmos_sky_smooth(horizonDirection, sun, state) + tint * pow(facing, 6.0) * 0.8 * state.sunVisibility * (1.0 - state.rain);
        vec3 hazeDisplay = light_tonemap(hazeLinear);
        vec3 biomeFog = camera.fogColor;
        float biomeLuma = max(dot(biomeFog, vec3(0.2126, 0.7152, 0.0722)), 1e-3);
        vec3 vanillaFog = vec3(0.753, 0.847, 1.0) / dot(vec3(0.753, 0.847, 1.0), vec3(0.2126, 0.7152, 0.0722));
        float custom = smoothstep(0.08, 0.3, length(biomeFog / biomeLuma - vanillaFog)) * (1.0 - state.rain) * smoothstep(0.02, 0.08, biomeLuma);
        vec3 biomeTint = biomeFog * (dot(hazeDisplay, vec3(0.2126, 0.7152, 0.0722)) / biomeLuma);
        hazeDisplay = mix(hazeDisplay, biomeTint, custom * 0.7);
        color = mix(color, hazeDisplay, clamp(amount, 0.0, distantTerrain ? 0.4 : 1.0));
    }

    if (Haze.z > 0.0 && facing > 0.2 && state.sunVisibility > 0.01) {
        float rays = godRays(camera, sun, screen);
        vec3 rayColor = mix(tint / max(max(tint.r, tint.g), tint.b), vec3(1.0, 0.45, 0.15), 0.4);
        float strength = Haze.w * state.sunVisibility * (1.0 - state.rain);
        if (depth > 0.0) {
            float weight = pow(facing, 30.0) + 0.8 * pow(facing, 16.0) + 0.125 * pow(facing, 2.0);
            color += rayColor * rays * weight * ATMOS_GODRAYS * strength;
        } else {
            float here = texelFetch(CameraSampler, pixel, 0).a;
            float beams = max(rays - 0.35, 0.0) * here;
            color += rayColor * beams * pow(facing, 4.0) * ATMOS_SKY_RAYS * strength;
        }
    }

    float regionFog = params_get(ParamsSampler, SMOOTH_FOG_DENSITY);
    if (regionFog > 0.001) {
        float fogDistance = depth > 0.0 ? length(camera_relative(camera, texCoord, depth)) : (distantTerrain ? estimated : 1e4);
        float amount = depth > 0.0 || distantTerrain ? 1.0 - exp(-fogDistance * regionFog * 0.06) : min(regionFog * 1.6, 0.92);
        float light = mix(0.1, 1.0, state.sunVisibility) * (1.0 - state.rain * 0.35) + state.moonVisibility * 0.05;
        color = mix(color, params_fog_color(ParamsSampler) * light, clamp(amount, 0.0, 1.0));
    }
    fragColor = vec4(color, raw.a);
}
