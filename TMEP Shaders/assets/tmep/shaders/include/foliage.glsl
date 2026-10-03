#ifndef TMEP_FOLIAGE_GLSL
#define TMEP_FOLIAGE_GLSL

const int FOLIAGE_LEAVES = 1;
const int FOLIAGE_PLANT = 2;
const int FOLIAGE_DOUBLE_LOWER = 3;
const int FOLIAGE_DOUBLE_UPPER = 4;
const int FOLIAGE_VINE = 5;
const int FOLIAGE_GRASS = 6;

const float FOLIAGE_STRENGTH = 1.0;
const float FOLIAGE_SPEED = 1.0;
const float FOLIAGE_RAIN_BOOST = 1.5;

int foliage_code(sampler2D atlas, ivec2 texel) {
    vec4 color = texelFetch(atlas, texel, 0);
    if (color.a < 0.5) {
        return -2;
    }
    uvec3 bits = uvec3(color.rgb * 255.0 + 0.5) & uvec3(7u);
    uint x = uint(texel.x & 15);
    uint y = uint(texel.y & 15);
    uint code = (bits.r | (bits.g << 3u) | (bits.b << 6u)) ^ ((x * 37u + y * 101u + x * y * 29u + 173u) & 511u);
    return (code >> 3u) == 45u ? int(code & 7u) : -1;
}

int foliage_kind(sampler2D atlas, ivec2 origin) {
    int kind = -1;
    int votes = 0;
    for (int i = 0; i < 40; i++) {
        int p = (i * 167 + 13) & 255;
        int code = foliage_code(atlas, origin + ivec2(p & 15, p >> 4));
        if (code == -2) {
            continue;
        }
        if (code == -1 || (kind > 0 && code != kind)) {
            return 0;
        }
        kind = code;
        votes++;
        if (votes >= 3) {
            return kind;
        }
    }
    return votes >= 1 ? kind : 0;
}

vec3 foliage_wave(vec3 pos, float cycle, float fm, float f0, float f1, float f2, float f3, float f4, float f5) {
    const float HALF = 6.2831853 * 10.0 / 128.0;
    const float FULL = 6.2831853 * 20.0 / 128.0;
    const float HALF_Y = 6.2831853 * 5.0 / 64.0;
    const float FULL_Y = 6.2831853 * 10.0 / 64.0;
    float magnitude = sin(cycle * fm + pos.x * HALF + pos.z * HALF + pos.y * HALF_Y) * 0.014 + 0.034;
    float d0 = sin(cycle * f0);
    float d1 = sin(cycle * f1);
    float d2 = sin(cycle * f2);
    vec3 wave;
    wave.x = sin(cycle * f3 + d0 + d1 - pos.x * FULL + pos.z * FULL + pos.y * FULL_Y) * magnitude;
    wave.z = sin(cycle * f4 + d1 + d2 + pos.x * FULL - pos.z * FULL + pos.y * FULL_Y) * magnitude;
    wave.y = sin(cycle * f5 + d2 + d0 + pos.z * FULL) * magnitude;
    return wave;
}

vec3 foliage_move(vec3 pos, float cycle, float f0, float f1, float f2, float f3, float f4, float f5, vec3 amp1, vec3 amp2) {
    vec3 first = foliage_wave(pos, cycle, 0.0027, 0.0127, 0.0089, 0.0114, 0.0063, 0.0224, 0.0015) * amp1;
    vec3 second = foliage_wave(pos + first, cycle, 0.0348, f0, f1, f2, f3, f4, f5) * amp2;
    return first + second;
}

vec3 foliage_offset(int kind, bool top, vec3 pos, float seconds) {
    float cycle = 150.796447 * seconds * FOLIAGE_SPEED;
    vec3 offset = vec3(0.0);
    if (kind == FOLIAGE_LEAVES) {
        offset = foliage_move(pos, cycle, 0.0040, 0.0064, 0.0043, 0.0035, 0.0037, 0.0041, vec3(1.0, 0.2, 1.0), vec3(0.5, 0.1, 0.5));
    } else if (kind == FOLIAGE_VINE) {
        offset = foliage_move(pos, cycle, 0.0040, 0.0064, 0.0043, 0.0035, 0.0037, 0.0041, vec3(0.5, 1.0, 0.5), vec3(0.25, 0.5, 0.25));
    } else if (kind == FOLIAGE_GRASS && top) {
        offset = foliage_move(pos, cycle, 0.0041, 0.0070, 0.0044, 0.0038, 0.0063, 0.0, vec3(2.6, 1.4, 2.6), vec3(0.0));
    } else if ((kind == FOLIAGE_PLANT && top) || (kind == FOLIAGE_DOUBLE_LOWER && top) || kind == FOLIAGE_DOUBLE_UPPER) {
        offset = foliage_move(pos, cycle, 0.0041, 0.0070, 0.0044, 0.0038, 0.0240, 0.0, vec3(0.8, 0.0, 0.8), vec3(0.4, 0.0, 0.4));
    }
    return offset * FOLIAGE_STRENGTH;
}

#endif
