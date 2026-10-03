#ifndef TMEP_WATER_GLSL
#define TMEP_WATER_GLSL

#include <tmep:settings.glsl>

const float WATER_SIGNATURE_STILL = 143.0;
const float WATER_SIGNATURE_FLOW = 151.0;

const float WATER_TIME_WINDOW = 3600.0;
const float WATER_REGION = 128.0;
const float WATER_TAU = 6.2831853;

const float WATER_WAVE_HEIGHT = 2.4;
const float WATER_WAVE_SPEED = 1.15;
const float WATER_NORMAL_STRENGTH = 0.1;
const float WATER_SWELL_NORMAL = 0.4;

#ifdef WATER_DEBUG_VIEW
const int WATER_DEBUG = WATER_DEBUG_VIEW;
#else
const int WATER_DEBUG = 0;
#endif
const float WATER_SPRITE_PIXELS_VERTEX = 1024.0;
const int WATER_FRAME_PIXELS = 128;
const int WATER_FRAME_MAX_LOD = 4;
const int WATER_FRAME_GRID = 8;
const int WATER_FRAME_COUNT = 64;
const float WATER_FRAME_LOOP = 9.6;
const float WATER_RIPPLE_TIME_SCALE = 0.6;
const float WATER_CORE_SUN_GLINT = 0.0;
const float WATER_TEXTURE_SLOPE = 0.2330;
const float WATER_TEXTURE_NORMAL = 0.75;
const float WATER_TEXTURE_LOD_BIAS = 0.5;
const float WATER_PARALLAX = 0.6;
const float WATER_F0 = 0.12;
const float WATER_SUN_ROUGHNESS = 0.000229;
const float WATER_SHEEN_ROUGHNESS = 0.02;
const float WATER_WAVE_SINK = 0.045;
const float WATER_CREST_MARGIN = 0.02;
const float WATER_DETAIL_FADE = 48.0;

const float WATER_MIN_ALPHA = 0.3;
const float WATER_BODY_BRIGHTNESS = 0.6;
const vec3 WATER_SCATTER_COLOR = vec3(0.14, 0.44, 0.56);
const float WATER_BIOME_TINT = 0.15;
const vec3 WATER_EXTINCTION = vec3(0.50, 0.26, 0.18);
const float WATER_PATH_SCALE = 1.7;
const float WATER_INSCATTER_SCALE = 0.16;
const float WATER_MAX_PATH = 24.0;
const float WATER_BED_CAUSTICS = 0.9;
const float WATER_SHORE_FOAM = 0.0;
const float WATER_SHORE_WIDTH = 0.4;
const vec3 WATER_DEEP_TINT = vec3(0.30, 0.52, 0.60);
const float WATER_TEXTURE_DETAIL = 0.25;

const float WATER_ASSUMED_DEPTH = 1.6;
const float WATER_BACKLIT_CRESTS = 0.35;
const vec3 WATER_UNDERWATER_TINT = vec3(0.22, 0.50, 0.72);
const float WATER_UNDERWATER_DEPTH_FADE = 0.13;

const float WATER_DAY_SIDE = -1.0;
const float WATER_SUN_TINT_THRESHOLD = 0.02;
const float WATER_SUN_GLINT = 0.05;
const float WATER_SUN_SHEEN = 0.05;
const float WATER_MOON_GLINT = 0.012;
const float WATER_SKY_ZENITH_DARKEN = 0.55;
const vec3 WATER_SKY_ZENITH_TINT = vec3(0.55, 0.72, 0.95);
const float WATER_HORIZON_GLOW = 0.25;
const float WATER_CLOUDS = 0.6;
const float WATER_CLOUD_SCALE = 0.25;

const float WATER_FOAM_FLOW = 0.6;
const float WATER_FALL_THICKNESS = 0.7;
const float WATER_FALL_SPEED = 150.0;
const float WATER_FALL_SLOW_SPEED = 100.0;
const float WATER_FALL_STREAKS = 0.35;
const float WATER_FOAM_CREST = 0.35;
const vec3 WATER_FOAM_COLOR = vec3(0.92, 0.97, 1.0);

const float WATER_CAUSTICS = 1.1;
const float WATER_UNDERWATER_FOG_START = -8.0;
const float WATER_CALM_RIPPLES = 0.25;
const float WATER_CAUSTIC_CONTRAST = 4.0;
const float WATER_CAUSTIC_SPEED = 5.0;
const float WATER_CAUSTIC_WARP = 1.4;
const float WATER_CAUSTIC_FADE_START = 16.0;
const float WATER_CAUSTIC_FADE_END = 56.0;

const int WATER_GEOMETRY_WAVES = 4;
const vec4 WATER_GEOMETRY[4] = vec4[](
    vec4(5.0, 2.0, 0.040, 0.3),
    vec4(-3.0, 6.0, 0.028, 1.7),
    vec4(7.0, -4.0, 0.022, 4.1),
    vec4(2.0, -9.0, 0.016, 2.6)
);

const int WATER_DETAIL_WAVES = 10;
const vec4 WATER_DETAIL[10] = vec4[](
    vec4(13.0, 5.0, 0.0105, 0.9),
    vec4(-11.0, 9.0, 0.0095, 3.3),
    vec4(17.0, -12.0, 0.0075, 5.2),
    vec4(6.0, 19.0, 0.0070, 1.1),
    vec4(-23.0, -7.0, 0.0055, 2.4),
    vec4(29.0, 16.0, 0.0042, 0.2),
    vec4(-31.0, 22.0, 0.0036, 4.7),
    vec4(41.0, -13.0, 0.0030, 3.9),
    vec4(-37.0, -35.0, 0.0024, 1.8),
    vec4(53.0, 24.0, 0.0019, 5.9)
);

float water_ggx(vec3 normal, vec3 toCamera, vec3 light, float f0, float alpha2) {
    vec3 halfway = normalize(light + toCamera);
    float nh = max(dot(normal, halfway), 0.0);
    float nl = max(dot(normal, light), 0.0);
    float lh = max(dot(light, halfway), 0.0);
    float denominator = nh * nh * (alpha2 - 1.0) + 1.0;
    float d = alpha2 / (3.14159265 * denominator * denominator);
    float f = f0 + (1.0 - f0) * exp2((-5.55473 * lh - 6.98316) * lh);
    float k2 = 0.25 * alpha2;
    return nl * d * f / (lh * lh * (1.0 - k2) + k2);
}

float water_time(int currentTime) {
    return float(uint(currentTime) % 3600000u) * 0.001;
}

float water_kind(float alpha) {
    float a = alpha * 255.0;
    if (abs(a - WATER_SIGNATURE_STILL) < 2.0) {
        return 1.0;
    }
    if (abs(a - WATER_SIGNATURE_FLOW) < 2.0) {
        return 2.0;
    }
    return 0.0;
}

vec2 water_wave_vector(vec4 wave) {
    return wave.xy * (WATER_TAU / WATER_REGION);
}

float water_wave_omega(vec2 k) {
    float omega = sqrt(9.81 * length(k)) * 0.55 * WATER_WAVE_SPEED;
    float step = WATER_TAU / WATER_TIME_WINDOW;
    return max(round(omega / step), 1.0) * step;
}

float water_height(vec2 p, float t) {
    float h = 0.0;
    for (int i = 0; i < WATER_GEOMETRY_WAVES; i++) {
        vec2 k = water_wave_vector(WATER_GEOMETRY[i]);
        h += WATER_GEOMETRY[i].z * sin(dot(k, p) - water_wave_omega(k) * t + WATER_GEOMETRY[i].w);
    }
    return h * WATER_WAVE_HEIGHT;
}

float water_wave_weight(float kind, float y) {
    if (kind < 0.5 || WATER_VERTEX_WAVES == 0) {
        return 0.0;
    }
    float fraction = fract(y);
    float sourceLevel = 1.0 - smoothstep(0.004, 0.03, abs(fraction - 0.8888889));
    float fullColumn = (fraction < 0.004 || fraction > 0.996) && kind < 1.5 ? 1.0 : 0.0;
    return max(sourceLevel, fullColumn);
}

float water_vertex_lift(vec3 p, float t) {
    float lift = water_height(mod(p.xz, WATER_REGION), t) - WATER_WAVE_SINK * WATER_WAVE_HEIGHT;
    float top = ceil(p.y - WATER_CREST_MARGIN);
    float headroom = max(top - WATER_CREST_MARGIN - p.y, 0.0);
    if (lift > 0.0) {
        lift = headroom * tanh(lift / max(headroom, 1e-3));
    }
    return lift;
}

vec3 water_surface(vec2 p, float t, float distance) {
    vec2 swell = vec2(0.0);
    float height = 0.0;
    for (int i = 0; i < WATER_GEOMETRY_WAVES; i++) {
        vec2 k = water_wave_vector(WATER_GEOMETRY[i]);
        float phase = dot(k, p) - water_wave_omega(k) * t + WATER_GEOMETRY[i].w;
        swell += WATER_GEOMETRY[i].z * cos(phase) * k;
        height += WATER_GEOMETRY[i].z * sin(phase);
    }
    vec2 ripple = vec2(0.0);
    float detail = exp(-distance / WATER_DETAIL_FADE);
    for (int i = 0; i < WATER_DETAIL_WAVES; i++) {
        vec2 k = water_wave_vector(WATER_DETAIL[i]);
        float phase = dot(k, p) - water_wave_omega(k) * t + WATER_DETAIL[i].w;
        ripple += WATER_DETAIL[i].z * cos(phase) * k * detail;
    }
    return vec3(swell * WATER_WAVE_HEIGHT * WATER_SWELL_NORMAL + ripple * WATER_NORMAL_STRENGTH, height * WATER_WAVE_HEIGHT);
}

float water_hash(vec2 cell) {
    return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}

float water_noise(vec2 p, vec2 period) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    float a = water_hash(mod(i, period));
    float b = water_hash(mod(i + vec2(1.0, 0.0), period));
    float c = water_hash(mod(i + vec2(0.0, 1.0), period));
    float d = water_hash(mod(i + vec2(1.0, 1.0), period));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float water_fbm(vec2 p, vec2 period) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 4; i++) {
        value += amplitude * water_noise(p, period);
        p *= 2.0;
        period *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

float water_sun_up(float day) {
    return smoothstep(0.14, 0.4, day);
}

float water_sun_side(float day, vec3 forward, vec3 fogColor) {
    float lookSide = forward.x >= 0.0 ? 1.0 : -1.0;
    bool tinted = fogColor.r > fogColor.b + WATER_SUN_TINT_THRESHOLD;
    bool lowSun = day < 0.5;
    return lowSun ? (tinted ? lookSide : -lookSide) : WATER_DAY_SIDE;
}

vec3 water_sun_direction(float day, float side) {
    float elevation = mix(0.06, 1.15, smoothstep(0.2, 1.0, day));
    return normalize(vec3(side * cos(elevation), sin(elevation), 0.0));
}

vec3 water_sun_color(float day) {
    vec3 low = vec3(1.0, 0.52, 0.22);
    vec3 high = vec3(1.0, 0.95, 0.86);
    return mix(low, high, smoothstep(0.3, 0.85, day)) * water_sun_up(day);
}

vec3 water_moon_direction(float side) {
    return normalize(vec3(-side * 0.5, 0.86, 0.0));
}

float water_clouds(vec3 direction, float t) {
    if (direction.y <= 0.02) {
        return 0.0;
    }
    vec2 p = direction.xz / direction.y * WATER_CLOUD_SCALE;
    vec2 drift = vec2(t * 256.0 * 4.0, t * 256.0 * 1.0) / WATER_TIME_WINDOW;
    float n = water_fbm(p * 4.0 + drift, vec2(256.0));
    float cover = smoothstep(0.4, 0.85, n);
    return cover * smoothstep(0.02, 0.25, direction.y);
}

vec3 water_sky(vec3 direction, vec3 fogColor, float skyVisibility, vec3 fallback, float day, float t) {
    float up = clamp(direction.y, 0.0, 1.0);
    vec3 zenith = fogColor * WATER_SKY_ZENITH_TINT * WATER_SKY_ZENITH_DARKEN;
    vec3 horizon = fogColor * (1.05 + WATER_HORIZON_GLOW * exp(-up * 12.0));
    vec3 sky = mix(horizon, zenith, pow(up, 0.45));
    vec3 cloudColor = mix(fogColor * 0.9, vec3(1.0, 0.98, 0.95) * max(day, 0.06), 0.55);
    cloudColor = mix(cloudColor, water_sun_color(day) * 1.1 + fogColor * 0.3, (1.0 - smoothstep(0.3, 0.8, day)) * water_sun_up(day) * 0.6);
    sky = mix(sky, cloudColor, water_clouds(direction, t) * WATER_CLOUDS);
    return mix(fallback, sky, skyVisibility);
}

float water_caustic_layer(vec2 q, mat2 rotation, vec2 drift) {
    vec2 c = rotation * q * 0.25 + drift;
    float n = water_noise(c, vec2(32.0)) * 0.65 + water_noise(c * 2.0 + vec2(17.0, 5.0), vec2(64.0)) * 0.35;
    float x = abs(n * 2.0 - 1.0);
    float y = abs(x * 2.0 - 1.0);
    return y * y;
}

float water_caustics(vec3 p, float t, float wallSlant, float distance) {
    vec2 q = p.xz + vec2(p.y * 2.0 * wallSlant, 0.0);
    float cycle = t / WATER_TIME_WINDOW * 32.0 * WATER_CAUSTIC_SPEED;
    vec2 warpCoord = q * 0.25;
    vec2 warp = vec2(water_noise(warpCoord + vec2(3.0, -2.0) * cycle, vec2(32.0)),
                     water_noise(warpCoord + vec2(-1.0, 4.0) * cycle + vec2(7.0, 13.0), vec2(32.0))) - 0.5;
    q += warp * WATER_CAUSTIC_WARP;
    float a = water_caustic_layer(q, mat2(2.0, -1.0, 1.0, 2.0), vec2(9.0, 4.0) * cycle);
    float b = water_caustic_layer(q, mat2(1.0, 2.0, -2.0, 1.0), vec2(-5.0, 7.0) * cycle);
    float c = water_caustic_layer(q, mat2(3.0, -1.0, 1.0, 3.0), vec2(6.0, -8.0) * cycle);
    float web = exp(WATER_CAUSTIC_CONTRAST * ((a + b + c) / 3.0 - 0.5));
    float fade = 1.0 - smoothstep(WATER_CAUSTIC_FADE_START, WATER_CAUSTIC_FADE_END, distance);
    return max(web - 1.0, 0.0) * 0.75 * fade;
}

#endif
