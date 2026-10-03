#ifndef TMEP_MIST_GLSL
#define TMEP_MIST_GLSL

const float MIST_GLOW_LUMINANCE = 0.42;

const vec3 MIST_BLOB_SIGNATURE = vec3(94.0, 138.0, 11.0);
const vec3 MIST_BLOB_COLOR = vec3(0.36, 0.56, 0.34);
const vec3 MIST_BLOB_GLOW_COLOR = vec3(0.62, 1.0, 0.52);
const float MIST_BLOB_DENSITY = 0.9;
const float MIST_BLOB_EDGE_WARP = 0.5;
const float MIST_BLOB_GLOW = 0.8;
const float MIST_BLOB_NEAR_FADE_START = 3.0;
const float MIST_BLOB_NEAR_FADE_END = 14.0;
const float MIST_BLOB_DRIFT_LOOPS = 30.0;

float mist_zone_weight(vec3 fogColor) {
    float g = max(fogColor.g, 1e-3);
    float greenness = (fogColor.g - max(fogColor.r, fogColor.b)) / g;
    float tint = abs(fogColor.r - fogColor.b) / g;
    return smoothstep(0.0, 0.25, greenness) * (1.0 - smoothstep(0.08, 0.2, tint));
}

float mist_fog_value(float distance, float fogEnd) {
    float x = distance / max(fogEnd, 1.0) * 1.9;
    float body = 1.0 - exp(-x * x);
    float haze = 0.12 * (1.0 - exp(-distance * 0.35));
    return clamp(max(body, haze), 0.0, 1.0);
}

float mist_glow_factor(vec3 uniformFogColor, float weight) {
    float luminance = dot(uniformFogColor, vec3(0.2126, 0.7152, 0.0722));
    float boost = max(1.0, MIST_GLOW_LUMINANCE / max(luminance, 1e-3));
    return mix(1.0, boost, weight);
}

bool mist_is_blob(vec4 vertexColor) {
    vec3 diff = abs(vertexColor.rga * 255.0 - MIST_BLOB_SIGNATURE);
    return all(lessThan(diff, vec3(0.5)));
}

float mist_blob_radius(vec4 vertexColor) {
    return vertexColor.b * 255.0;
}

vec2 mist_blob_corner(int vertexIndex) {
    const vec2 corners[4] = vec2[](vec2(-1.0, -1.0), vec2(1.0, -1.0), vec2(1.0, 1.0), vec2(-1.0, 1.0));
    return corners[vertexIndex % 4];
}

vec3 mist_blob_push(vec3 position, float radius) {
    float distance = max(length(position), 1e-4);
    return position * (max(distance - radius, 0.5) / distance);
}

float mist_hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float mist_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    float a = mist_hash(i);
    float b = mist_hash(i + vec2(1.0, 0.0));
    float c = mist_hash(i + vec2(0.0, 1.0));
    float d = mist_hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float mist_fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 4; i++) {
        value += amplitude * mist_noise(p);
        p = p * 2.03 + vec2(17.1, 9.4);
        amplitude *= 0.5;
    }
    return value;
}

vec4 mist_blob_color(vec2 q, float distance, float gameTime) {
    float angle = gameTime * 6.2831853 * MIST_BLOB_DRIFT_LOOPS;
    vec2 drift = vec2(cos(angle), sin(angle)) * 1.5;
    float n = mist_fbm(q * 2.2 + drift);
    float r = length(q) * (1.0 + n * MIST_BLOB_EDGE_WARP);
    if (r >= 1.0) {
        return vec4(0.0);
    }
    float thickness = pow(1.0 - r * r, 1.5);
    float wisps = smoothstep(0.25, 0.85, n);
    float alpha = 1.0 - exp(-MIST_BLOB_DENSITY * thickness * mix(0.4, 1.3, wisps));
    alpha *= smoothstep(MIST_BLOB_NEAR_FADE_START, MIST_BLOB_NEAR_FADE_END, distance);
    vec3 rgb = mix(MIST_BLOB_COLOR, MIST_BLOB_GLOW_COLOR, thickness * thickness * MIST_BLOB_GLOW);
    return vec4(rgb, alpha);
}

#endif
