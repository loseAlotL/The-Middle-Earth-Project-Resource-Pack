#ifndef TMEP_WATER_SURFACE_GLSL
#define TMEP_WATER_SURFACE_GLSL

#include <tmep:water.glsl>


const mat2 WATER_RIPPLE_MATRIX[3] = mat2[](mat2(7.0, -4.0, 4.0, 7.0), mat2(4.0, 1.0, -1.0, 4.0), mat2(2.0, -1.0, 1.0, 2.0));
const float WATER_RIPPLE_WEIGHT[3] = float[](1.0, 0.55, 0.3);
const vec2 WATER_RIPPLE_DRIFT[3] = vec2[](vec2(0.0, 0.0), vec2(8.0, -3.0), vec2(-2.0, 5.0));

struct WaterSampler {
    vec2 spriteMin;
    vec3 lods;
    int maxLod;
};

vec4 water_sprite_texel(sampler2D atlas, ivec2 origin, ivec2 texel, int size, int lod) {
    return texelFetch(atlas, origin + (texel & ivec2(size - 1)), lod);
}

vec4 water_sprite_sample(sampler2D atlas, vec2 spriteMin, vec2 uv, int lod, int frame) {
    int size = WATER_FRAME_PIXELS >> lod;
    ivec2 cell = ivec2(frame % WATER_FRAME_GRID, frame / WATER_FRAME_GRID);
    ivec2 origin = ivec2(round(spriteMin * vec2(textureSize(atlas, lod)))) + cell * size;
    vec2 t = fract(uv) * float(size) - 0.5;
    ivec2 base = ivec2(floor(t));
    vec2 f = t - vec2(base);
    vec4 a = water_sprite_texel(atlas, origin, base, size, lod);
    vec4 b = water_sprite_texel(atlas, origin, base + ivec2(1, 0), size, lod);
    vec4 c = water_sprite_texel(atlas, origin, base + ivec2(0, 1), size, lod);
    vec4 d = water_sprite_texel(atlas, origin, base + ivec2(1, 1), size, lod);
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec4 water_sprite_sample_lod(sampler2D atlas, vec2 spriteMin, vec2 uv, float lod, int maxLod, int frame) {
    #if WATER_TRILINEAR == 0
    return water_sprite_sample(atlas, spriteMin, uv, min(int(lod + 0.5), maxLod), frame);
    #endif
    int low = min(int(floor(lod)), maxLod);
    int high = min(low + 1, maxLod);
    float blend = smoothstep(0.3, 0.7, fract(lod));
    if (high == low || blend <= 0.0) {
        return water_sprite_sample(atlas, spriteMin, uv, low, frame);
    }
    if (blend >= 1.0) {
        return water_sprite_sample(atlas, spriteMin, uv, high, frame);
    }
    return mix(water_sprite_sample(atlas, spriteMin, uv, low, frame), water_sprite_sample(atlas, spriteMin, uv, high, frame), blend);
}

float water_layer_lod(mat2 layer, vec2 dpdx, vec2 dpdy, int maxLod) {
    float texels = float(WATER_FRAME_PIXELS) / WATER_REGION;
    float footprint = max(length(layer * dpdx), length(layer * dpdy)) * texels;
    return clamp(log2(max(footprint, 1e-6)) + WATER_TEXTURE_LOD_BIAS, 0.0, float(maxLod));
}

WaterSampler water_sampler(sampler2D atlas, vec2 spriteMin, vec2 dpdx, vec2 dpdy) {
    WaterSampler s;
    s.spriteMin = spriteMin;
#if __VERSION__ >= 430
    s.maxLod = min(textureQueryLevels(atlas) - 1, WATER_FRAME_MAX_LOD);
#else
    s.maxLod = 0;
#endif
    s.lods = vec3(water_layer_lod(WATER_RIPPLE_MATRIX[0], dpdx, dpdy, s.maxLod),
                  water_layer_lod(WATER_RIPPLE_MATRIX[1], dpdx, dpdy, s.maxLod),
                  water_layer_lod(WATER_RIPPLE_MATRIX[2], dpdx, dpdy, s.maxLod));
    return s;
}

vec4 water_ripple_layer(sampler2D atlas, WaterSampler s, vec2 p, float t, int layer) {
    vec2 uv = WATER_RIPPLE_MATRIX[layer] * (p / WATER_REGION) + WATER_RIPPLE_DRIFT[layer] * t / WATER_TIME_WINDOW;
    float phase = fract(t * WATER_RIPPLE_TIME_SCALE / WATER_FRAME_LOOP) * float(WATER_FRAME_COUNT);
    int frame = int(floor(phase)) % WATER_FRAME_COUNT;
    int next = (frame + 1) % WATER_FRAME_COUNT;
    vec4 a = water_sprite_sample_lod(atlas, s.spriteMin, uv, s.lods[layer], s.maxLod, frame);
    vec4 b = water_sprite_sample_lod(atlas, s.spriteMin, uv, s.lods[layer], s.maxLod, next);
    return mix(a, b, fract(phase));
}

float water_ripple_height(sampler2D atlas, WaterSampler s, vec2 p, float t) {
    float height = 0.0;
    for (int i = 0; i < WATER_RIPPLE_LAYERS; i++) {
        height += (water_ripple_layer(atlas, s, p, t, i).r - 0.5) * WATER_RIPPLE_WEIGHT[i];
    }
    return height;
}

vec2 water_ripple_gradient(sampler2D atlas, WaterSampler s, vec2 p, float t, out float height) {
    vec2 gradient = vec2(0.0);
    height = 0.0;
    for (int i = 0; i < WATER_RIPPLE_LAYERS; i++) {
        vec4 texel = water_ripple_layer(atlas, s, p, t, i);
        mat2 m = WATER_RIPPLE_MATRIX[i];
        float scale = length(vec2(m[0][0], m[1][0]));
        vec2 slope = (texel.gb * 2.0 - 1.0) * WATER_TEXTURE_SLOPE;
        gradient += transpose(m) * slope / scale * WATER_RIPPLE_WEIGHT[i];
        height += (texel.r - 0.5) * WATER_RIPPLE_WEIGHT[i];
    }
    return gradient;
}

vec2 water_parallax(sampler2D atlas, WaterSampler s, vec2 p, float t, vec3 view) {
    #if WATER_PARALLAX_ENABLED == 0
    return p;
    #else
    return p - (water_ripple_layer(atlas, s, p, t, 0).r - 0.5) * WATER_RIPPLE_WEIGHT[0] * view.xz * WATER_PARALLAX;
    #endif
}

#endif
