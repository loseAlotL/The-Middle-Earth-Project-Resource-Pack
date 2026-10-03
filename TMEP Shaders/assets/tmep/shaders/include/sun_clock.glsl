#ifndef TMEP_SUN_CLOCK_GLSL
#define TMEP_SUN_CLOCK_GLSL

const float SUN_CLOCK_MARKER = 10.0 / 255.0;
const float SUN_CLOCK_MARKER_B = 9.0 / 255.0;
const float SUN_CLOCK_RANGE = 10.0 / 255.0;
const float SUN_CLOCK_STEPS = 4095.0;
const vec2 SUN_CLOCK_TEXEL_LOW = vec2(15.5, 15.5) / 16.0;
const vec2 SUN_CLOCK_TEXEL_HIGH = vec2(14.5, 15.5) / 16.0;
const vec2 SUN_CLOCK_TEXEL_WEATHER = vec2(13.5, 15.5) / 16.0;

bool sun_clock_encoded(vec3 ambient) {
    return abs(ambient.g - SUN_CLOCK_MARKER) < 1e-4 && abs(ambient.b - SUN_CLOCK_MARKER_B) < 1e-4;
}

uint sun_clock_code(vec3 ambient) {
    return sun_clock_encoded(ambient) ? uint(clamp(ambient.r / SUN_CLOCK_RANGE, 0.0, 1.0) * (SUN_CLOCK_STEPS - 1.0) + 0.5) : uint(SUN_CLOCK_STEPS);
}

vec3 sun_clock_embed(vec3 color, uint bits) {
    uvec3 bytes = uvec3(clamp(color, 0.0, 1.0) * 255.0 + 0.5);
    bytes = (bytes & uvec3(252u)) | (uvec3(bits, bits >> 2u, bits >> 4u) & uvec3(3u));
    return vec3(bytes) / 255.0;
}

uint sun_clock_extract(vec3 color) {
    uvec3 bytes = uvec3(color * 255.0 + 0.5) & uvec3(3u);
    return bytes.r | (bytes.g << 2u) | (bytes.b << 4u);
}

float sun_clock_phase(sampler2D lightmap) {
    uint low = sun_clock_extract(texture(lightmap, SUN_CLOCK_TEXEL_LOW).rgb);
    uint high = sun_clock_extract(texture(lightmap, SUN_CLOCK_TEXEL_HIGH).rgb);
    uint code = low | (high << 6u);
    return code >= uint(SUN_CLOCK_STEPS) ? -1.0 : float(code) / (SUN_CLOCK_STEPS - 1.0);
}

float sun_clock_weather(sampler2D lightmap) {
    return float(sun_clock_extract(texture(lightmap, SUN_CLOCK_TEXEL_WEATHER).rgb)) / 62.0;
}

const vec2 SUN_CLOCK_TEXEL_TIME[3] = vec2[](vec2(12.5, 15.5) / 16.0, vec2(11.5, 15.5) / 16.0, vec2(10.5, 15.5) / 16.0);

float sun_clock_seconds(sampler2D lightmap) {
    uint eighths = sun_clock_extract(texture(lightmap, SUN_CLOCK_TEXEL_TIME[0]).rgb)
        | (sun_clock_extract(texture(lightmap, SUN_CLOCK_TEXEL_TIME[1]).rgb) << 6u)
        | (sun_clock_extract(texture(lightmap, SUN_CLOCK_TEXEL_TIME[2]).rgb) << 12u);
    return float(eighths) / 160.0;
}

vec3 sun_clock_direction(float phase) {
    float timeOfDay = fract(phase - 0.25);
    float smoothed = 0.5 - cos(timeOfDay * 3.14159265) * 0.5;
    float angle = (timeOfDay * 2.0 + smoothed) / 3.0 * 6.2831853;
    return normalize(vec3(-sin(angle), cos(angle), 0.0));
}

#endif
