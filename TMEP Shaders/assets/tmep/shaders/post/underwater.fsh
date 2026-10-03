#version 330
#extension GL_ARB_separate_shader_objects : require

#define CAMERA_FROM_QUAD

#include <tmep:water_post.glsl>

uniform sampler2D InSampler;
uniform sampler2D DepthSampler;
uniform sampler2D ProbeSampler;
uniform sampler2D RipplesSampler;

layout(location = 0) in vec2 texCoord;

layout(std140) uniform UnderwaterConfig {
    vec4 Rays;
    vec4 Murk;
    vec4 Warp;
};

layout(location = 0) out vec4 fragColor;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

vec3 hash33(vec3 p) {
    p = fract(p * vec3(0.1031, 0.1030, 0.0973));
    p += dot(p, p.yxz + 33.33);
    return fract((p.xxy + p.yxx) * p.zyx);
}

float noise2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

float shaftPattern(vec2 q, float time) {
    q *= Rays.w;
    float a = noise2(q * 0.3 + vec2(time * 0.11, time * 0.07));
    float b = noise2(q * 0.75 + vec2(-time * 0.09, time * 0.13) + 17.0);
    return smoothstep(0.42, 0.9, a * 0.62 + b * 0.38);
}

vec3 sceneAt(vec2 uv, ivec2 screen, vec3 fallback) {
    ivec2 pixel = clamp(ivec2(uv * vec2(screen)), ivec2(0), screen - 1);
    if (camera_is_data_pixel(pixel)) {
        return fallback;
    }
    return texture(InSampler, uv).rgb;
}

vec3 snellWindow(Camera camera, vec3 color, vec3 direction, float depth, ivec2 screen, float time, vec3 lightColor) {
    vec3 surfacePoint = camera_relative(camera, texCoord, depth);
    vec3 world = surfacePoint + camera_world_origin();
    vec2 gradient = water_post_ripple_gradient(RipplesSampler, world.xz, time) * Warp.z;
    float span = max(camera.fogEnd - camera.fogStart, 1.0);
    float fog = clamp((length(surfacePoint) - camera.fogStart) / span, 0.0, 1.0);
    vec2 bend = gradient * vec2(float(screen.y) / float(screen.x), 1.0) * 0.035 * (1.0 - fog);
    vec2 throughUv = clamp(texCoord + bend, vec2(0.0), vec2(1.0));
    ivec2 throughPixel = clamp(ivec2(throughUv * vec2(screen)), ivec2(0), screen - 1);
    vec3 seen = color;
    if (water_post_is_underside_depth(water_post_scene_depth(DepthSampler, throughPixel)) && !camera_is_data_pixel(throughPixel)) {
        seen = texture(InSampler, throughUv).rgb;
    }
    vec3 normal = normalize(vec3(-gradient.x, -1.0, -gradient.y));
    vec3 refracted = refract(direction, normal, 1.333);
    if (camera_has_daytime(camera) && dot(refracted, refracted) > 1e-4) {
        vec3 sun = camera_sun_direction(camera);
        float sunDot = max(dot(refracted, sun), 0.0);
        seen += lightColor * (pow(sunDot, 600.0) * 4.0 + pow(sunDot, 24.0) * 0.25) * smoothstep(-0.03, 0.08, sun.y) * (1.0 - fog);
    }
    return seen;
}

float godRays(vec3 origin, vec3 direction, float sceneDistance, vec3 light, float time) {
    int steps = int(Rays.y);
    vec3 travel = refract(-light, vec3(0.0, 1.0, 0.0), 1.0 / 1.333);
    if (steps <= 0 || travel.y > -0.05) {
        return 0.0;
    }
    vec2 slant = travel.xz / travel.y;
    float reach = min(sceneDistance, Rays.z);
    float stepLength = reach / float(steps);
    float jitter = fract(52.9829189 * fract(dot(gl_FragCoord.xy, vec2(0.06711056, 0.00583715))));
    float fade = 3.0 / Rays.z;
    float total = 0.0;
    for (int i = 0; i < steps; i++) {
        float t = (float(i) + jitter) * stepLength;
        vec3 p = origin + direction * t;
        vec2 q = p.xz - slant * p.y;
        total += shaftPattern(q, time) * exp(-t * fade);
    }
    float phase = 0.45 + 1.4 * pow(max(dot(direction, light), 0.0), 3.0);
    return total * stepLength / Rays.z * phase * 3.0;
}

vec2 specks(vec3 origin, vec3 direction, float sceneDistance, float time) {
    int cells = int(Murk.y);
    const float CELL = 1.25;
    vec3 safeDirection = sign(direction) * max(abs(direction), vec3(1e-5));
    vec3 cell = floor(origin / CELL);
    vec3 stepDir = sign(safeDirection);
    vec3 tDelta = abs(CELL / safeDirection);
    vec3 tMax = ((cell + max(stepDir, 0.0)) * CELL - origin) / safeDirection;
    vec2 result = vec2(0.0);
    for (int i = 0; i < cells; i++) {
        vec3 h = hash33(mod(cell, 1024.0));
        if (h.x < 0.45) {
            vec3 wobble = vec3(sin(time * 0.35 + h.y * 6.2831), sin(time * 0.23 + h.z * 6.2831) * 0.6, cos(time * 0.29 + h.x * 13.0)) * 0.18;
            vec3 center = (cell + 0.25 + 0.5 * h.zyx + wobble) * CELL;
            float t = dot(center - origin, direction);
            if (t > 0.08 && t < sceneDistance) {
                float miss = length(origin + direction * t - center);
                float radius = max(0.006, t * 0.0012);
                float s = smoothstep(radius, radius * 0.25, miss) * (1.0 - smoothstep(6.0, 12.0, t));
                if (h.y < 0.3) {
                    result.y = max(result.y, s);
                } else {
                    result.x = max(result.x, s);
                }
            }
        }
        if (tMax.x < tMax.y && tMax.x < tMax.z) {
            cell.x += stepDir.x;
            tMax.x += tDelta.x;
        } else if (tMax.y < tMax.z) {
            cell.y += stepDir.y;
            tMax.y += tDelta.y;
        } else {
            cell.z += stepDir.z;
            tMax.z += tDelta.z;
        }
    }
    return result;
}

void main() {
    ivec2 pixel = ivec2(gl_FragCoord.xy);
    vec4 raw = texelFetch(InSampler, pixel, 0);
    fragColor = raw;
    if (!camera_quick_underwater(InSampler) || camera_is_data_pixel(pixel)) {
        return;
    }
    Camera camera = camera_load(InSampler);
    ivec2 screen = textureSize(DepthSampler, 0);
    float time = GameTime * 1200.0;
    float depth = water_post_scene_depth(DepthSampler, pixel);
    vec3 direction = camera_ray(camera, texCoord);
    float sceneDistance = depth > 0.0 ? length(camera_relative(camera, texCoord, depth)) : 1e4;
    vec3 origin = camera_world_origin();

    float pixelScale = float(screen.y) / 1080.0;
    vec2 wave = vec2(sin(texCoord.y * 23.0 + time * 1.7 * Warp.y) + 0.5 * sin(texCoord.x * 13.0 - time * 1.3 * Warp.y),
                     cos(texCoord.x * 19.0 + time * 1.5 * Warp.y) + 0.5 * cos(texCoord.y * 11.0 + time * 1.1 * Warp.y));
    vec2 warpUv = texCoord + wave * Warp.x * pixelScale * smoothstep(1.5, 8.0, sceneDistance) / vec2(screen);
    float warpDepth = water_post_scene_depth(DepthSampler, clamp(ivec2(warpUv * vec2(screen)), ivec2(0), screen - 1));
    bool warpNear = (warpDepth > 0.0 && length(camera_relative(camera, warpUv, warpDepth)) < 1.5) || water_post_is_hand_depth(warpDepth) || water_post_is_hand_depth(depth);
    vec3 color = warpNear ? raw.rgb : sceneAt(warpUv, screen, raw.rgb);

    float env = clamp(dot(camera.fogColor, LUMA) * 5.0, 0.0, 1.0);
    vec3 lightColor = vec3(1.0, 0.96, 0.88);
    float daylight = 0.0;
    vec3 light = vec3(0.0, 1.0, 0.0);
    if (camera_has_daytime(camera)) {
        vec3 sun = camera_sun_direction(camera);
        float sunUp = smoothstep(-0.05, 0.15, sun.y);
        light = sun.y > 0.0 ? sun : -sun;
        daylight = sun.y > 0.0 ? sunUp : 0.12 * smoothstep(0.0, 0.2, -sun.y);
        lightColor = sun.y > 0.0 ? lightColor : vec3(0.55, 0.62, 0.85);
    }

    if (water_post_is_underside_pixel(DepthSampler, pixel)) {
        color = snellWindow(camera, color, direction, depth, screen, time, lightColor);
    }

    float murk = Murk.x * (1.0 - exp(-min(sceneDistance, 96.0) / 16.0));
    vec3 murkColor = mix(camera.fogColor, vec3(dot(camera.fogColor, LUMA)) * vec3(0.62, 1.0, 0.78) * 1.4, Murk.w);
    color = mix(color, murkColor, murk);
    float gray = dot(color, LUMA);
    color = mix(color, vec3(gray) * vec3(0.8, 1.0, 0.86), Murk.w * 0.35);

    if (Rays.x > 0.0 && daylight > 0.0) {
        float rays = godRays(origin, direction, sceneDistance, light, time);
        color += lightColor * vec3(0.55, 0.85, 0.78) * rays * Rays.x * daylight * env;
    }

    if (Murk.y > 0.0) {
        vec2 speck = specks(origin, direction, sceneDistance, time);
        color = mix(color, lightColor * env * vec3(0.7, 0.78, 0.66) + murkColor * 0.4, speck.x * Murk.z);
        color = mix(color, murkColor * 0.35, speck.y * Murk.z);
    }

    fragColor = vec4(color, 1.0);
}
