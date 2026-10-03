#ifndef TMEP_SHADER_PARAMS_GLSL
#define TMEP_SHADER_PARAMS_GLSL

#include <tmep:precision.glsl>

const int PARAM_HEAT = 0;
const int PARAM_FOG_COLOR = 1;
const int PARAM_FOG_DENSITY = 2;
const int PARAM_GRADE_STYLE = 3;
const int PARAM_GRADE_AMOUNT = 4;
const int PARAM_WRAITH = 5;
const int PARAM_GLOOM = 6;
const int PARAM_FLAGS = 7;
const int PARAM_EMITTER_X = 8;
const int PARAM_EMITTER_Y = 9;
const int PARAM_EMITTER_Z = 10;
const int PARAM_EMITTER_POWER = 11;

const int SMOOTH_HEAT = 0;
const int SMOOTH_FOG_R = 1;
const int SMOOTH_FOG_G = 2;
const int SMOOTH_FOG_B = 3;
const int SMOOTH_FOG_DENSITY = 4;
const int SMOOTH_GRADE_STYLE = 5;
const int SMOOTH_GRADE_AMOUNT = 6;
const int SMOOTH_WRAITH = 7;
const int SMOOTH_GLOOM = 8;
const int SMOOTH_ASH = 9;
const int SMOOTH_AURORA = 10;
const int SMOOTH_EERIE = 11;
const int SMOOTH_EMITTER_STRENGTH = 12;
const int SMOOTH_EMITTER_RADIUS = 13;
const int SMOOTH_SURFACED = 14;
const int SMOOTH_RAIN_SCREEN = 15;
const int SMOOTH_TRANSPARENCY = 16;
const int SMOOTH_COUNT = 17;

const int GRADE_NONE = 0;
const int GRADE_MORDOR = 1;
const int GRADE_BARROW = 2;
const int GRADE_LORIEN = 3;
const int GRADE_SHIRE = 4;
const int GRADE_MORIA = 5;
const int GRADE_ANGMAR = 6;

float params_get(sampler2D params, int index) {
    vec4 texel = texelFetch(params, ivec2(index, 0), 0);
    return texel.a > 0.5 ? precise_decode(texel) : 0.0;
}

float params_transparency_off_seconds(sampler2D params) {
    vec4 texel = texelFetch(params, ivec2(SMOOTH_TRANSPARENCY, 0), 0);
    if (texel.b < 0.5) {
        return -1.0;
    }
    return fract(GameTime - precise_decode(texel) + 1.0) * 1200.0;
}

float params_surfaced_seconds(sampler2D params) {
    vec4 texel = texelFetch(params, ivec2(SMOOTH_SURFACED, 0), 0);
    if (texel.b < 0.5) {
        return 1e4;
    }
    return fract(GameTime - precise_decode(texel) + 1.0) * 1200.0;
}

vec3 params_fog_color(sampler2D params) {
    return vec3(params_get(params, SMOOTH_FOG_R), params_get(params, SMOOTH_FOG_G), params_get(params, SMOOTH_FOG_B));
}

int params_grade_style(sampler2D params) {
    return int(round(params_get(params, SMOOTH_GRADE_STYLE) * 15.0));
}

vec3 params_emitter_offset(float x, float y, float z) {
    return (vec3(x, y, z) * 2.0 - 1.0) * 64.0;
}

#endif
