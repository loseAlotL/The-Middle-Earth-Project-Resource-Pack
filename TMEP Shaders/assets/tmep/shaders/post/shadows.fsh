#version 330
#extension GL_ARB_separate_shader_objects : require

#define CAMERA_FROM_QUAD

#include <tmep:water_post.glsl>
#include <tmep:lighting.glsl>
#include <tmep:heightmap.glsl>

uniform sampler2D InSampler;
uniform sampler2D DepthSampler;
uniform sampler2D HeightSampler;

layout(location = 0) in vec2 texCoord;

layout(std140) uniform ShadowConfig {
    vec4 Occlusion;
    vec4 SunShadow;
    vec4 Extra;
    vec4 Terrain;
};

float terrainShadow(vec3 world, vec3 normal, vec3 lightDirection, float noise) {
    int steps = int(Terrain.x);
    vec3 start = world + normal * 0.5;
    float travelled = 1.5 + noise * 0.6;
    float stepLength = 0.7;
    for (int i = 0; i < 48; i++) {
        if (i >= steps || travelled > Terrain.y) {
            break;
        }
        vec3 q = start + lightDirection * travelled;
        if (q.y > 330.0) {
            break;
        }
        float height = heightmap_lookup(HeightSampler, q.xz);
        if (q.y < height - 0.35) {
            return 1.0;
        }
        travelled += stepLength;
        stepLength *= 1.12;
    }
    return 0.0;
}

layout(location = 0) out vec4 fragColor;

vec3 scenePoint(Camera camera, ivec2 pixel, ivec2 screen) {
    pixel = clamp(pixel, ivec2(0), screen - 1);
    float depth = water_post_scene_depth(DepthSampler, pixel);
    return camera_relative(camera, (vec2(pixel) + 0.5) / vec2(screen), max(depth, 1e-7));
}

vec3 surfaceNormal(Camera camera, ivec2 pixel, ivec2 screen, vec3 center) {
    vec3 right = scenePoint(camera, pixel + ivec2(1, 0), screen) - center;
    vec3 left = center - scenePoint(camera, pixel - ivec2(1, 0), screen);
    vec3 up = scenePoint(camera, pixel + ivec2(0, 1), screen) - center;
    vec3 down = center - scenePoint(camera, pixel - ivec2(0, 1), screen);
    vec3 dx = dot(right, right) < dot(left, left) ? right : left;
    vec3 dy = dot(up, up) < dot(down, down) ? up : down;
    vec3 normal = normalize(cross(dx, dy));
    return dot(normal, center) > 0.0 ? -normal : normal;
}

float behind(Camera camera, mat4 viewProjection, vec3 point, ivec2 screen, out bool onScreen) {
    vec4 clip = viewProjection * vec4(point, 1.0);
    onScreen = false;
    if (clip.w <= 1e-4) {
        return -1.0;
    }
    vec2 ndc = clip.xy / clip.w;
    if (any(greaterThan(abs(ndc), vec2(1.0)))) {
        return -1.0;
    }
    onScreen = true;
    ivec2 pixel = clamp(ivec2((ndc * 0.5 + 0.5) * vec2(screen)), ivec2(0), screen - 1);
    float depth = water_post_scene_depth(DepthSampler, pixel);
    if (depth <= 0.0 || water_post_is_water_depth(depth) || water_post_is_hand_depth(depth) || camera_is_data_pixel(pixel)) {
        return -1.0;
    }
    vec4 row = vec4(camera.inverseProjection[0][3], camera.inverseProjection[1][3], camera.inverseProjection[2][3], camera.inverseProjection[3][3]);
    float sceneW = 1.0 / dot(row, vec4(ndc, depth, 1.0));
    return clip.w - sceneW;
}

float occlusionRing(Camera camera, mat4 viewProjection, vec3 center, vec3 normal, ivec2 screen, float noise, int samples, float radius) {
    vec3 tangent = normalize(abs(normal.y) < 0.9 ? cross(normal, vec3(0.0, 1.0, 0.0)) : cross(normal, vec3(1.0, 0.0, 0.0)));
    vec3 bitangent = cross(normal, tangent);
    float hits = 0.0;
    for (int i = 0; i < 16; i++) {
        if (i >= samples) {
            break;
        }
        float f = (float(i) + noise) / float(samples);
        float angle = float(i) * 2.3999632 + noise * 6.2831853;
        float spread = sqrt(f);
        vec3 offset = (tangent * cos(angle) * spread + bitangent * sin(angle) * spread + normal * sqrt(max(1.0 - f, 0.05))) * radius * mix(0.3, 1.0, f);
        bool onScreen;
        float gap = behind(camera, viewProjection, center + normal * 0.02 + offset, screen, onScreen);
        if (gap > 0.03 && gap < radius * 2.0) {
            hits += 1.0;
        }
    }
    return hits / float(max(samples, 1));
}

float cheapDistance(Camera camera, ivec2 pixel, ivec2 screen) {
    pixel = clamp(pixel, ivec2(0), screen - 1);
    float depth = water_post_scene_depth(DepthSampler, pixel);
    if (depth <= 0.0 || water_post_is_water_depth(depth) || water_post_is_hand_depth(depth)) {
        return 1e4;
    }
    return length(camera_relative(camera, (vec2(pixel) + 0.5) / vec2(screen), depth));
}

float cheapPair(Camera camera, ivec2 pixel, ivec2 step, ivec2 screen, float distance) {
    float a = cheapDistance(camera, pixel + step, screen);
    float b = cheapDistance(camera, pixel - step, screen);
    float bulge = distance - 0.5 * (a + b);
    float radius = Occlusion.y;
    return smoothstep(0.02 + distance * 0.004, radius, bulge) * (1.0 - smoothstep(radius * 2.0, radius * 4.0, bulge));
}

float cheapOcclusion(Camera camera, ivec2 pixel, ivec2 screen, float distance) {
    float pixels = clamp(Occlusion.y * camera.projection[1][1] * 0.5 * float(screen.y) / max(distance, 0.1), 2.0, 48.0);
    int r = int(pixels);
    int d = int(pixels * 0.7071);
    float occ = cheapPair(camera, pixel, ivec2(r, 0), screen, distance)
        + cheapPair(camera, pixel, ivec2(0, r), screen, distance)
        + cheapPair(camera, pixel, ivec2(d, d), screen, distance)
        + cheapPair(camera, pixel, ivec2(d, -d), screen, distance);
    return occ * 0.25;
}

void main() {
    ivec2 pixel = ivec2(texCoord * vec2(textureSize(DepthSampler, 0)));
    fragColor = vec4(0.0);
    if (Occlusion.x < -0.5) {
        cameraScreenSize = textureSize(InSampler, 0);
        float cheapDepth = water_post_scene_depth(DepthSampler, pixel);
        if (camera_is_data_pixel(pixel) || cheapDepth <= 0.0 || water_post_is_water_depth(cheapDepth) || water_post_is_underside_depth(cheapDepth) || water_post_is_hand_depth(cheapDepth)) {
            return;
        }
        Camera cheapCamera = camera_load(InSampler);
        if (!cheapCamera.valid || cheapCamera.underwater) {
            return;
        }
        ivec2 cheapScreen = textureSize(DepthSampler, 0);
        float cheapCenter = length(camera_relative(cheapCamera, texCoord, cheapDepth));
        if (cheapCenter < 0.3 || cheapCenter > Occlusion.w) {
            return;
        }
        float fade = 1.0 - smoothstep(Occlusion.w * 0.6, Occlusion.w, cheapCenter);
        fragColor = vec4(0.0, cheapOcclusion(cheapCamera, pixel, cheapScreen, cheapCenter) * Occlusion.z * fade, 0.0, 1.0);
        return;
    }
    int samples = int(Occlusion.x);
#if EXPERIMENTAL_SHADOWS_BROKEN_DO_NOT_ENABLE == 1
    int steps = int(SunShadow.x);
#else
    int steps = 0;
#endif
    if (samples <= 0 && steps <= 0) {
        return;
    }
    cameraScreenSize = textureSize(InSampler, 0);
    if (camera_is_data_pixel(pixel)) {
        return;
    }
    float depth = water_post_scene_depth(DepthSampler, pixel);
    if (depth <= 0.0 || water_post_is_water_depth(depth) || water_post_is_underside_depth(depth) || water_post_is_hand_depth(depth)) {
        return;
    }
    Camera camera = camera_load(InSampler);
    if (!camera.valid || camera.underwater) {
        return;
    }
    ivec2 screen = textureSize(DepthSampler, 0);
    vec3 center = camera_relative(camera, texCoord, depth);
    float distance = length(center);
    float reach = max(Occlusion.w, Extra.x);
    if (distance < 0.3 || distance > reach) {
        return;
    }
    vec3 normal = surfaceNormal(camera, pixel, screen, center);
    mat4 viewProjection = camera.projection * camera.view;
    const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
    bool reduced = gl_FragCoord.x / max(texCoord.x, 1e-4) < float(screen.x) * 0.75;
    ivec2 cell = ivec2(gl_FragCoord.xy) & 3;
    float noise = reduced ? (BAYER[cell.y * 4 + cell.x] + 0.5) / 16.0 : fract(52.9829189 * fract(dot(gl_FragCoord.xy, vec2(0.06711056, 0.00583715))));
    float aoFade = 1.0 - smoothstep(Occlusion.w * 0.6, Occlusion.w, distance);
    float shadowFade = 1.0 - smoothstep(Extra.x * 0.6, Extra.x, distance);

    float occlusion = 0.0;
    if (samples > 0 && aoFade > 0.0) {
        occlusion = occlusionRing(camera, viewProjection, center, normal, screen, noise, samples, Occlusion.y) * Occlusion.z;
        occlusion = max(occlusion, occlusionRing(camera, viewProjection, center, normal, screen, fract(noise + 0.5), max(samples / 2, 4), Extra.y) * Extra.z);
        occlusion *= aoFade;
    }

    float shadow = 0.0;
    float terrainHit = 0.0;
    if (steps > 0 && camera.skyValid && shadowFade > 0.0) {
        LightState state = light_state(camera.daytime / 24000.0, clamp(camera.weather, 0.0, 1.0));
        vec3 lightDirection = state.sun.y >= 0.0 ? state.sun : -state.sun;
        float facing = dot(normal, lightDirection);
        float strength = max(state.sunVisibility, state.moonVisibility * 0.5) * (1.0 - state.rain);
        if (facing > 0.02 && strength > 0.01) {
            float bias = 0.03 + distance * 0.004;
            float travelled = 0.06 + bias + noise * 0.1;
            float stepLength = 0.1;
            float tolerance = SunShadow.w + distance * 0.004;
            for (int i = 0; i < 40; i++) {
                if (i >= steps || travelled > SunShadow.y) {
                    break;
                }
                bool onScreen;
                float gap = behind(camera, viewProjection, center + normal * bias + lightDirection * travelled, screen, onScreen);
                if (!onScreen) {
                    break;
                }
                if (gap > 0.04 + distance * 0.003 && gap < tolerance + travelled * 0.1) {
                    shadow = 1.0;
                    break;
                }
                travelled += stepLength;
                stepLength *= 1.22;
            }
            if (shadow < 0.5 && Terrain.z > 0.0 && EXPERIMENTAL_SHADOWS_BROKEN_DO_NOT_ENABLE == 1) {
                shadow = terrainShadow(center + camera_world_origin(), normal, lightDirection, noise);
                terrainHit = shadow > 0.5 ? 1.0 : 0.0;
            }
            shadow *= smoothstep(0.02, 0.25, facing) * strength * shadowFade;
        }
    }

    fragColor = vec4(shadow, occlusion, terrainHit, 1.0);
}
