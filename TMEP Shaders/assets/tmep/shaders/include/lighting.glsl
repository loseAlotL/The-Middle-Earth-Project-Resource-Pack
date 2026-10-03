#ifndef TMEP_LIGHTING_GLSL
#define TMEP_LIGHTING_GLSL

#include <tmep:sun_clock.glsl>

const float LIGHT_SUN_TILT = 0.6981317;
const float LIGHT_SUN_STRENGTH = 1.0;
const float LIGHT_AMBIENT_STRENGTH = 1.0;
const float LIGHT_TORCH_STRENGTH = 1.0;
const float LIGHT_EMISSIVE_STRENGTH = 1.6;
const float LIGHT_CAVE_EXPOSURE = 9.9;
const float LIGHT_MINIMUM = 0.0006;
const float LIGHT_BRIGHTNESS = 1.0;
const float LIGHT_SATURATION = 1.12;
const float LIGHT_DUSK_FOG = 0.75;
const vec3 LIGHT_DUSK_FILL = vec3(0.06, 0.065, 0.085);
const float LIGHT_MOON_BOOST = 5.5;
const float LIGHT_NIGHT_LEVEL = 0.4;
const float LIGHT_TRANSLUCENCY = 0.8;
const float SOFT_TOP = 1.0;
const float SOFT_SIDE_BRIGHT = 0.88;
const float SOFT_SIDE_DIM = 0.72;
const float SOFT_BOTTOM = 0.55;
const float SOFT_PLANT = 0.93;
const vec3 SOFT_COOL = vec3(0.9, 0.95, 1.05);
const vec3 SOFT_WARM = vec3(1.03, 1.015, 0.98);
const float SOFT_MIDTONE_LIFT = 0.35;
const float SOFT_VIBRANCE = 0.15;
const float SOFT_LEAF_GLOW = 0.3;
const float SOFT_BIO_GLOW = 0.45;
const float SOFT_BIO_REACT = 1.1;
const float SOFT_EMISSIVE = 0.5;
const vec3 LIGHT_SKY_COLOR = vec3(0.24, 1.2, 2.64);
const vec3 LIGHT_RAIN_SKY_SHIFT = vec3(0.115, -0.759, -2.07);
const vec3 LIGHT_MOON_COLOR = vec3(0.5, 0.9, 1.8) * 0.0035;
const vec3 LIGHT_TORCH_COLOR = vec3(1.3, 0.95, 0.62) * 0.65;

const vec3 LIGHT_SUN_TABLE[7] = vec3[](
    vec3(0.58597, 0.16, 0.005),
    vec3(0.58597, 0.31, 0.08),
    vec3(0.58597, 0.45, 0.16),
    vec3(0.58597, 0.5, 0.35),
    vec3(0.58597, 0.5, 0.36),
    vec3(0.58597, 0.5, 0.37),
    vec3(0.58597, 0.5, 0.38)
);

struct LightState {
    vec3 sun;
    vec3 sunColor;
    float sunVisibility;
    float moonVisibility;
    float twilight;
    float rain;
    float exposure;
};

vec3 light_to_linear(vec3 srgb) {
    return pow(max(srgb, vec3(0.0)), vec3(2.2));
}

vec3 light_hable(vec3 x) {
    const float A = 0.28;
    const float B = 0.29;
    const float C = 0.10;
    const float D = 0.2;
    const float E = 0.025;
    const float F = 0.35;
    return ((x * (A * x + C * B) + D * E) / (x * (A * x + B) + D * F)) - E / F;
}

vec3 light_tonemap(vec3 linear) {
    vec3 mapped = light_hable(max(linear, vec3(0.0)) * 4.7 * LIGHT_BRIGHTNESS) / light_hable(vec3(15.2));
    vec3 display = pow(clamp(mapped, 0.0, 1.0), vec3(1.0 / 2.2));
    float gray = dot(display, vec3(0.2126, 0.7152, 0.0722));
    return clamp(mix(vec3(gray), display, LIGHT_SATURATION), 0.0, 1.0);
}

vec3 light_tilted_sun(vec3 sun) {
    return vec3(sun.x, sun.y * cos(LIGHT_SUN_TILT), sun.y * sin(LIGHT_SUN_TILT));
}

vec3 light_sun_table(float ticks) {
    float hour = max(mod(ticks / 1000.0 + 2.0, 24.0) - 2.0, 0.0);
    int i = int(max(6.0 - abs(floor(hour) - 6.0), 0.0));
    int j = int(max(6.0 - abs(floor(hour) - 5.0), 0.0));
    return mix(LIGHT_SUN_TABLE[min(i, 6)], LIGHT_SUN_TABLE[min(j, 6)], fract(hour));
}

float light_clear_sky(float phase) {
    float t = phase * 24000.0;
    if (t < 730.0) {
        return mix(0.24, 1.0, clamp((t + 1140.0) / 1870.0, 0.0, 1.0));
    }
    if (t < 11270.0) {
        return 1.0;
    }
    if (t < 13140.0) {
        return mix(1.0, 0.24, (t - 11270.0) / 1870.0);
    }
    if (t < 22860.0) {
        return 0.24;
    }
    return mix(0.24, 1.0, (t - 22860.0) / 1870.0);
}

LightState light_state(float phase, float weather) {
    LightState state;
    float ticks = phase * 24000.0;
    state.sun = light_tilted_sun(sun_clock_direction(phase));
    state.sunColor = light_sun_table(ticks);
    float sunUp = state.sun.y;
    state.sunVisibility = pow(clamp(sunUp + 0.15, 0.0, 0.15) / 0.15, 4.0);
    state.moonVisibility = pow(clamp(-sunUp + 0.15, 0.0, 0.15) / 0.15, 4.0);
    float distanceToTwilight = min(min(abs(ticks - 23050.0), abs(ticks - 12700.0)), 750.0);
    state.twilight = max(distanceToTwilight / 375.0 - 1.0, 0.0);
    state.rain = clamp((1.0 - weather - 0.06) / 0.25, 0.0, 1.0);

    vec3 skyAverage = 0.3 * (vec3(0.25, 0.62, 1.32) - state.rain * vec3(0.11, 0.32, 1.07)) + state.sunColor * 1.2;
    vec3 moonAverage = vec3(0.0016, 0.00288, 0.00448) * 3.5;
    vec3 average = (skyAverage * state.sunVisibility + moonAverage * state.moonVisibility) * (0.05 + state.twilight * 0.15) * 4.7 + 0.0006;
    float luma = dot(average, vec3(0.299, 0.587, 0.114));
    state.exposure = 1.75 * pow(clamp(luma, 0.007, 80.0), -0.35);
    return state;
}

float light_torch(float block) {
    float t = 16.0 - min(15.0, (block - 0.03125) * 17.0666667);
    float falloff = clamp(1.0 - pow(t * 0.0625, 4.0), 0.0, 1.0);
    return falloff * falloff / (t * t + 1.0);
}

vec3 light_world(LightState state, vec3 normal, float sky, float block, bool foliage) {
    float skyL = max(sky - 0.125, 0.0) * 1.142857;
    float sky2 = skyL * skyL;
    float sky3 = sky2 * skyL;
    float skyCurve = 1.0 + (sky2 - 1.0) * skyL;
    float ndl = dot(normal, state.sun);
    float ndu = normal.y;

    vec4 b = vec4(ndl, ndl, ndl, ndu) * vec4(-0.14 * sky2, 0.33, 0.7, 0.1) + vec4(0.6, 0.66, 0.7, 0.25);
    b *= vec4(skyCurve, skyCurve, state.sunVisibility - state.twilight * state.sunVisibility, 0.8);
    float wet = 1.0 - state.rain * 0.99;
    vec3 skyAmbient = b.w * (LIGHT_SKY_COLOR + state.rain * LIGHT_RAIN_SKY_SHIFT) + 1.6 * wet * state.sunColor * (sqrt(b.w) * b.x * 2.4 + b.z);
    vec3 moonAmbient = (LIGHT_MOON_COLOR * 0.7 + LIGHT_MOON_COLOR * b.y) * 4.0 * LIGHT_MOON_BOOST;
    vec3 sunTerrain = vec3(state.sunColor.r, max(state.sunColor.g, state.sunColor.r * 0.58), max(state.sunColor.b, state.sunColor.r * 0.24));
    vec3 lightColor = (sunTerrain * (1.0 - state.moonVisibility) + LIGHT_MOON_COLOR * LIGHT_MOON_BOOST * state.moonVisibility) * wet;
    vec3 ambient = (skyAmbient * state.sunVisibility + moonAmbient * state.moonVisibility) * sky2 * (0.0195 + state.twilight * 0.1105) * LIGHT_AMBIENT_STRENGTH;
    ambient += LIGHT_DUSK_FILL * (1.0 - state.twilight) * max(state.sunVisibility, state.moonVisibility) * (0.7 + 0.3 * ndu) * sky2 * (1.0 - state.rain);

    vec3 torch = LIGHT_TORCH_COLOR * light_torch(block) * 0.66 * LIGHT_TORCH_STRENGTH;
    vec3 minimum = vec3(LIGHT_MINIMUM * min(skyL + 0.375, 0.5625));
    vec3 indirect = ambient + torch + minimum;

    float direct = foliage ? ndl * 0.35 + 0.65 : max(ndl, 0.0);
    direct *= 0.5 * LIGHT_SUN_STRENGTH;

    vec3 light = (direct * lightColor * sky3 * 2.15 + indirect / (sky3 * 0.5 + 0.5) * 1.4) * 0.63;
    float exposure = mix(LIGHT_CAVE_EXPOSURE, state.exposure, smoothstep(0.0, 0.5, skyL));
    return light * pow(exposure, 0.88);
}

vec3 light_translucency(LightState state, vec3 view, float sky) {
    float skyL = max(sky - 0.125, 0.0) * 1.142857;
    float forward = pow(max(dot(view, state.sun), 0.0), 4.0);
    float exposure = mix(LIGHT_CAVE_EXPOSURE, state.exposure, smoothstep(0.0, 0.5, skyL));
    vec3 color = vec3(state.sunColor.r, max(state.sunColor.g, state.sunColor.r * 0.58), max(state.sunColor.b, state.sunColor.r * 0.24));
    return color * forward * skyL * skyL * skyL * state.sunVisibility * (1.0 - state.rain) * LIGHT_TRANSLUCENCY * 0.68 * pow(exposure, 0.88);
}

float light_soft_face(vec3 normal) {
    vec3 axis = abs(normal);
    if (axis.y > 0.98) {
        return normal.y > 0.0 ? SOFT_TOP : SOFT_BOTTOM;
    }
    if (axis.z > 0.98) {
        return normal.z > 0.0 ? SOFT_SIDE_BRIGHT : SOFT_SIDE_DIM;
    }
    if (axis.x > 0.98) {
        return normal.x < 0.0 ? SOFT_SIDE_BRIGHT : SOFT_SIDE_DIM;
    }
    return SOFT_PLANT;
}

vec3 light_soft_grade(vec3 color) {
    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    color *= mix(1.0, 1.0 + SOFT_MIDTONE_LIFT, 1.0 - smoothstep(0.0, 0.65, abs(luma - 0.325)));
    luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    float saturation = max(max(color.r, color.g), color.b) - min(min(color.r, color.g), color.b);
    return mix(vec3(luma), color, 1.0 + (1.0 - saturation) * SOFT_VIBRANCE);
}

uint light_marker_code(vec3 color, ivec2 texel) {
    uvec3 bits = uvec3(color * 255.0 + 0.5) & uvec3(7u);
    uint x = uint(texel.x & 15);
    uint y = uint(texel.y & 15);
    return (bits.r | (bits.g << 3u) | (bits.b << 6u)) ^ ((x * 37u + y * 101u + x * y * 29u) & 511u);
}

int light_marker(vec3 texel, vec3 partner, ivec2 pixel) {
    uint a = light_marker_code(texel, pixel);
    uint b = light_marker_code(partner, pixel ^ ivec2(1, 0));
    if (a != b) {
        return 0;
    }
    return a == 342u ? 1 : (a == 343u ? 2 : (a == 344u ? 3 : 0));
}

const float LIGHT_HEAT_ALPHA = 0.62;

vec3 light_heat_stamp(vec3 color) {
    uvec3 bytes = uvec3(clamp(color, 0.0, 1.0) * 255.0 + 0.5);
    return vec3((bytes & uvec3(252u)) | uvec3(2u, 1u, 3u)) / 255.0;
}

bool light_heat_stamped(vec4 pixel) {
    return abs(pixel.a - LIGHT_HEAT_ALPHA) < 0.01 && all(equal(uvec3(pixel.rgb * 255.0 + 0.5) & uvec3(3u), uvec3(2u, 1u, 3u)));
}

bool light_is_emissive(vec3 texel, vec3 partner, ivec2 pixel) {
    return light_marker(texel, partner, pixel) == 1;
}

float light_bioluminescence(vec3 regionPos, vec3 viewPos, float time) {
    vec3 cell = floor(regionPos * 2.0);
    float seed = fract(sin(dot(cell, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
    float breathe = 0.75 + 0.25 * sin(time * 1.3 + seed * 6.2831853);
    float near = 1.0 - smoothstep(1.5, 7.0, length(viewPos));
    float flicker = 0.7 + 0.3 * sin(time * 6.0 + seed * 31.0);
    return breathe * SOFT_BIO_GLOW + near * flicker * SOFT_BIO_REACT;
}

vec3 light_dusk_fog(LightState state, vec3 fog, vec3 viewDirection) {
    float horizon = smoothstep(-0.15, 0.0, state.sun.y) * (1.0 - smoothstep(0.0, 0.35, state.sun.y));
    vec2 flatView = normalize(viewDirection.xz + vec2(1e-5));
    vec2 flatSun = normalize(state.sun.xz + vec2(1e-5));
    float facing = pow(max(dot(flatView, flatSun), 0.0), 3.0);
    vec3 glow = state.sunColor / 0.58597 * max(max(fog.r, fog.g), fog.b) * 1.25;
    return mix(fog, glow, horizon * facing * LIGHT_DUSK_FOG);
}

#endif
