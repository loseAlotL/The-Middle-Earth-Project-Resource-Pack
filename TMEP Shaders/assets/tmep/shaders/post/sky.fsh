#version 330
#extension GL_ARB_separate_shader_objects : require

#define CAMERA_FROM_QUAD

#include <tmep:water_post.glsl>
#include <tmep:atmosphere.glsl>
#include <tmep:shader_params.glsl>

uniform sampler2D InSampler;
uniform sampler2D DepthSampler;
uniform sampler2D CloudSampler;
uniform sampler2D WeatherSampler;
uniform sampler2D ParamsSampler;

layout(location = 0) in vec2 texCoord;

layout(std140) uniform SkyConfig {
    vec4 Clouds;
};

layout(location = 0) out vec4 fragColor;

vec3 skyNeighbour(ivec2 pixel, ivec2 screen, vec3 fallback) {
    pixel = clamp(pixel, ivec2(0), screen - 1);
    return water_post_scene_depth(DepthSampler, pixel) <= 0.0 ? texelFetch(InSampler, pixel, 0).rgb : fallback;
}

vec3 starLight(ivec2 pixel, ivec2 screen) {
    vec3 center = texelFetch(InSampler, pixel, 0).rgb;
    vec3 around = min(min(skyNeighbour(pixel + ivec2(3, 0), screen, center), skyNeighbour(pixel - ivec2(3, 0), screen, center)),
                      min(skyNeighbour(pixel + ivec2(0, 3), screen, center), skyNeighbour(pixel - ivec2(0, 3), screen, center)));
    return max(center - around, vec3(0.0));
}

void main() {
    ivec2 pixel = ivec2(gl_FragCoord.xy);
    vec4 raw = texelFetch(InSampler, pixel, 0);
    fragColor = raw;
    cameraScreenSize = textureSize(InSampler, 0);
    if (camera_is_data_pixel(pixel)) {
        return;
    }
    ivec2 source = water_post_scene_pixel(DepthSampler, pixel);
    float depth = texelFetch(DepthSampler, source, 0).r;
    vec3 rainLayer = source != pixel ? raw.rgb - texelFetch(InSampler, source, 0).rgb : vec3(0.0);
    Camera camera = camera_load(InSampler);
    if (!camera.valid || !camera.skyValid || camera.underwater) {
        return;
    }
    ivec2 screen = textureSize(DepthSampler, 0);
    vec3 direction = camera_ray(camera, texCoord);
    float limit = depth > 0.0 ? length(camera_relative(camera, texCoord, depth)) : 1e5;
    bool sky = camera_open_sky(camera, direction, depth, InSampler, source);
    if (Clouds.w > 0.5 && depth <= 0.0) {
        fragColor = vec4(camera_sky_debug(camera, InSampler, source) * 0.8 + (sky ? vec3(0.0) : vec3(0.2, 0.2, 0.0)), 0.0);
        return;
    }
    int steps = int(Clouds.x);
    if (!sky && limit < 150.0) {
        fragColor = vec4(raw.rgb, 0.0);
        return;
    }
    LightState state = atmos_state(camera);
    atmos_apply_weather(WeatherSampler, state);
    atmosAuroraForce = params_get(ParamsSampler, SMOOTH_AURORA);
    float eerie = params_get(ParamsSampler, SMOOTH_EERIE);
    vec3 sun = camera_sun_direction(camera);
    vec3 skyLinear = atmos_sky(direction, sun, state);
    vec3 origin = camera_world_origin();
    float time = GameTime * 1200.0 * Clouds.y;
    vec4 clouds = texture(CloudSampler, texCoord);
    if (sky) {
        vec4 cirrus = steps > 0 ? atmos_cirrus(origin, direction, time, sun, state) : vec4(0.0);
        vec4 alto = steps > 0 ? atmos_altocumulus(origin, direction, time, sun, state, skyLinear) : vec4(0.0);
        float cirrusRegion = atmos_region_cirrus(origin.xz + normalize(vec3(sun.x, 0.0, sun.z) + 1e-4).xz * 2000.0, time);
        vec4 contrail = atmos_contrail(direction, sun, state, time);
        vec4 overcast = atmos_overcast(origin, direction, time, sun, state, skyLinear);
        float veil = (1.0 - max(clouds.a, 0.0)) * (1.0 - overcast.a);
        vec3 background = skyLinear + (atmos_celestial(direction, sun, state) + atmos_aurora(origin, direction, sun, state, GameTime * 1200.0)) * veil * veil * veil + atmos_optics(direction, sun, state, cirrusRegion) * (1.0 - overcast.a * 0.35);
        background = background * (1.0 - contrail.a) + contrail.rgb;
        background = background * (1.0 - cirrus.a) + cirrus.rgb;
        background = background * (1.0 - alto.a) + alto.rgb;
        background = mix(background, overcast.rgb, overcast.a);
        vec3 lightning = atmos_lightning(direction, GameTime * 1200.0) * overcast.a;
        float deckShadow = smoothstep(0.02, 0.45, state.rain) * mix(0.38, 0.55, atmosStorm);
        vec3 cloudColor = mix(clouds.rgb, vec3(dot(clouds.rgb, vec3(0.2126, 0.7152, 0.0722))), deckShadow) * (1.0 - deckShadow) + light_tonemap(lightning * 0.7);
        if (eerie > 0.001) {
            float eerieLuma = dot(background, vec3(0.2126, 0.7152, 0.0722));
            float low = 1.0 - smoothstep(0.0, 0.45, direction.y);
            background = mix(background, vec3(eerieLuma) * mix(vec3(1.1, 0.42, 0.22), vec3(1.5, 0.55, 0.2), low) * mix(0.55, 0.9, low), eerie * 0.85);
            cloudColor = mix(cloudColor, vec3(dot(cloudColor, vec3(0.2126, 0.7152, 0.0722))) * vec3(0.95, 0.62, 0.5) * 0.7, eerie * 0.8);
        }
        vec3 color = mix(light_tonemap(background + lightning), cloudColor, clouds.a);
        vec4 birds = atmos_birds(direction, time);
        color = mix(color, birds.rgb, birds.a);
        color = max(color + rainLayer, vec3(0.0));
        fragColor = vec4(color, (1.0 - clouds.a) * (1.0 - alto.a * 0.8) * (1.0 - overcast.a));
    } else if (depth <= 0.0) {
        float height = max(camera_world_origin().y - 63.0, 1.0);
        float estimated = direction.y < -0.002 ? height / -direction.y : 1e4;
        float reach = smoothstep(180.0, 900.0, estimated);
        float night = mix(1.0, mix(0.7, 0.4, reach), state.moonVisibility) * mix(1.0, 0.8, state.rain);
        vec3 distant = raw.rgb * night;
        float deckShadow = smoothstep(0.02, 0.45, state.rain) * mix(0.38, 0.55, atmosStorm);
        vec3 cloudColor = mix(clouds.rgb, vec3(dot(clouds.rgb, vec3(0.2126, 0.7152, 0.0722))), deckShadow) * (1.0 - deckShadow);
        fragColor = vec4(mix(distant, cloudColor, clouds.a), 0.0);
    } else if (clouds.a > 0.001) {
        float deckShadow = smoothstep(0.02, 0.45, state.rain) * mix(0.38, 0.55, atmosStorm);
        vec3 cloudColor = mix(clouds.rgb, vec3(dot(clouds.rgb, vec3(0.2126, 0.7152, 0.0722))), deckShadow) * (1.0 - deckShadow);
        fragColor = vec4(mix(raw.rgb, cloudColor, clouds.a), 0.0);
    } else {
        fragColor = vec4(raw.rgb, 0.0);
    }
}
