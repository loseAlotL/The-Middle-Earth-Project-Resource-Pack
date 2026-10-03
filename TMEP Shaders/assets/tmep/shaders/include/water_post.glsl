#ifndef TMEP_WATER_POST_GLSL
#define TMEP_WATER_POST_GLSL

#include <tmep:world.glsl>
#include <tmep:water.glsl>
#include <tmep:water_depth.glsl>

const mat2 WATER_POST_RIPPLE_MATRIX = mat2(7.0, -4.0, 4.0, 7.0);

bool water_post_has_flag(float depth, float flag) {
    return depth > 0.0 && depth < 0.5 && abs(fract(depth * WATER_DEPTH_FLAG_SCALE) - flag) < 1e-5;
}

bool water_post_is_rain_depth(float depth) {
    return water_post_has_flag(depth, 0.125);
}

ivec2 water_post_scene_pixel(sampler2D depthSampler, ivec2 pixel) {
    if (!water_post_is_rain_depth(texelFetch(depthSampler, pixel, 0).r)) {
        return pixel;
    }
    ivec2 limit = textureSize(depthSampler, 0) - 1;
    for (int r = 1; r <= 20; r++) {
        int reach = r <= 4 ? r : 4 + (r - 4) * 2;
        ivec2 left = clamp(pixel - ivec2(reach, 0), ivec2(0), limit);
        if (!water_post_is_rain_depth(texelFetch(depthSampler, left, 0).r)) {
            return left;
        }
        ivec2 right = clamp(pixel + ivec2(reach, 0), ivec2(0), limit);
        if (!water_post_is_rain_depth(texelFetch(depthSampler, right, 0).r)) {
            return right;
        }
    }
    return pixel;
}

float water_post_scene_depth(sampler2D depthSampler, ivec2 pixel) {
    return texelFetch(depthSampler, water_post_scene_pixel(depthSampler, pixel), 0).r;
}

bool water_post_is_hand_depth(float depth) {
    return depth > 0.0 && abs(fract(depth * WATER_DEPTH_FLAG_SCALE) - 0.25) < 1e-5;
}

bool water_post_is_water_depth(float depth) {
    return water_post_has_flag(depth, 0.5);
}

bool water_post_is_underside_depth(float depth) {
    return water_post_has_flag(depth, 0.75);
}

bool water_post_flag_region(sampler2D depthSampler, ivec2 pixel, float flag) {
    if (!water_post_has_flag(texelFetch(depthSampler, pixel, 0).r, flag)) {
        return false;
    }
    bool horizontal = water_post_has_flag(texelFetch(depthSampler, pixel + ivec2(-1, 0), 0).r, flag)
        || water_post_has_flag(texelFetch(depthSampler, pixel + ivec2(1, 0), 0).r, flag);
    bool vertical = water_post_has_flag(texelFetch(depthSampler, pixel + ivec2(0, -1), 0).r, flag)
        || water_post_has_flag(texelFetch(depthSampler, pixel + ivec2(0, 1), 0).r, flag);
    return horizontal && vertical;
}

bool water_post_is_water_pixel(sampler2D depthSampler, ivec2 pixel) {
    return water_post_flag_region(depthSampler, pixel, 0.5);
}

bool water_post_is_underside_pixel(sampler2D depthSampler, ivec2 pixel) {
    return water_post_flag_region(depthSampler, pixel, 0.75);
}

vec4 water_post_ripple_frame(sampler2D ripples, vec2 uv, int frame) {
    ivec2 origin = ivec2(frame % WATER_FRAME_GRID, frame / WATER_FRAME_GRID) * WATER_FRAME_PIXELS;
    vec2 t = fract(uv) * float(WATER_FRAME_PIXELS) - 0.5;
    ivec2 base = ivec2(floor(t));
    vec2 f = t - vec2(base);
    ivec2 mask = ivec2(WATER_FRAME_PIXELS - 1);
    vec4 a = texelFetch(ripples, origin + (base & mask), 0);
    vec4 b = texelFetch(ripples, origin + ((base + ivec2(1, 0)) & mask), 0);
    vec4 c = texelFetch(ripples, origin + ((base + ivec2(0, 1)) & mask), 0);
    vec4 d = texelFetch(ripples, origin + ((base + ivec2(1, 1)) & mask), 0);
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec2 water_post_ripple_gradient(sampler2D ripples, vec2 world, float time) {
    vec2 uv = WATER_POST_RIPPLE_MATRIX * (world / WATER_REGION);
    float phase = fract(time * WATER_RIPPLE_TIME_SCALE / WATER_FRAME_LOOP) * float(WATER_FRAME_COUNT);
    int frame = int(floor(phase)) % WATER_FRAME_COUNT;
    vec4 texel = mix(water_post_ripple_frame(ripples, uv, frame), water_post_ripple_frame(ripples, uv, (frame + 1) % WATER_FRAME_COUNT), fract(phase));
    vec2 slope = (texel.gb * 2.0 - 1.0) * WATER_TEXTURE_SLOPE;
    return transpose(WATER_POST_RIPPLE_MATRIX) * slope / length(vec2(WATER_POST_RIPPLE_MATRIX[0][0], WATER_POST_RIPPLE_MATRIX[1][0]));
}

vec2 water_post_project(mat4 viewProjection, vec3 relative, out bool visible) {
    vec4 clip = viewProjection * vec4(relative, 1.0);
    visible = clip.w > 1e-4;
    vec2 uv = clip.xy / max(clip.w, 1e-4) * 0.5 + 0.5;
    visible = visible && all(greaterThanEqual(uv, vec2(0.0))) && all(lessThanEqual(uv, vec2(1.0)));
    return uv;
}

vec2 water_post_probe_uv(vec3 direction) {
    float azimuth = atan(direction.z, direction.x);
    float elevation = asin(clamp(direction.y, 0.0, 1.0));
    return vec2(azimuth / 6.2831853 + 0.5, elevation / 1.5707963);
}

vec3 water_post_probe_direction(vec2 uv) {
    float azimuth = (uv.x - 0.5) * 6.2831853;
    float elevation = uv.y * 1.5707963;
    return vec3(cos(elevation) * cos(azimuth), sin(elevation), cos(elevation) * sin(azimuth));
}

float water_post_grazing(vec3 viewDirection) {
    return 1.0 - smoothstep(0.04, 0.35, -viewDirection.y);
}

#endif
