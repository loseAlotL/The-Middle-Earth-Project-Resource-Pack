#version 330
#extension GL_ARB_separate_shader_objects : require

#include <minecraft:globals.glsl>
#include <tmep:precision.glsl>

uniform sampler2D InSampler;
uniform sampler2D DepthSampler;
uniform sampler2D StateSampler;

layout(location = 0) in vec2 texCoord;

layout(std140) uniform WraithConfig {
    vec4 Warp;
    vec4 Look;
    vec4 Tint;
    vec4 Smoke;
};

layout(location = 0) out vec4 fragColor;

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float linearDistance(vec2 uv) {
    float depth = texture(DepthSampler, uv).r;
    return depth > 0.0 ? 0.05 / depth : 1e4;
}

float flow(vec2 p, float time) {
    float total = noise(p + vec2(0.0, time * 0.9)) * 0.55;
    total += noise(p * 2.3 - vec2(time * 0.35, time * 1.6)) * 0.3;
    total += noise(p * 5.1 + vec2(time * 0.8, time * 2.4)) * 0.15;
    return total;
}

vec2 rotate(vec2 v, float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

void main() {
    vec2 screen = vec2(textureSize(InSampler, 0));
    float aspect = screen.x / screen.y;
    vec3 original = texture(InSampler, texCoord).rgb;

    float start = precise_decode(texelFetch(StateSampler, ivec2(0), 0));
    float elapsed = fract(GameTime - start + 1.0) * 1200.0;
    float ramp = smoothstep(0.0, Look.w, elapsed);
    float burst = exp(-elapsed * 3.0) * smoothstep(0.0, 0.08, elapsed);
    float time = GameTime * 1200.0;
    float breath = 0.5 + 0.5 * sin(time * 1.3);

    vec2 offset = texCoord - 0.5;
    vec2 shaped = offset * vec2(aspect, 1.0);
    float radius = length(shaped);
    float edge = smoothstep(0.08, 0.75, radius);

    vec2 warpCoord = vec2(texCoord.x * aspect, texCoord.y) * 7.0;
    vec2 warp = vec2(flow(warpCoord, time), flow(warpCoord + 17.3, time)) - 0.45;
    warp *= Warp.x * (0.3 + edge * 1.4) * (0.8 + breath * 0.4) * ramp;
    warp.x += sin(texCoord.y * 38.0 + time * 2.7) * 0.0012 * ramp;

    float twist = (Warp.z * radius * radius * sin(time * 0.45) + burst * 1.2) * ramp;
    vec2 swirled = rotate(shaped, twist) / vec2(aspect, 1.0);
    vec2 center = vec2(0.5) + swirled + warp;

    float pull = Warp.y * (edge + 0.15) * ramp * (1.0 + burst * 3.0) * (0.85 + breath * 0.3);
    vec3 color = vec3(0.0);
    float weight = 0.0;
    for (int i = 0; i < 12; i++) {
        float s = float(i) / 11.0;
        float scale = 1.0 - pull * s;
        float w = 1.0 - s * 0.6;
        vec2 base = vec2(0.5) + (center - vec2(0.5)) * scale;
        vec2 fringe = (base - vec2(0.5)) * Look.z * edge;
        color.r += texture(InSampler, base + fringe).r * w;
        color.g += texture(InSampler, base).g * w;
        color.b += texture(InSampler, base - fringe).b * w;
        weight += w;
    }
    color /= weight;

    vec2 ghostCoord = vec2(0.5) + rotate(shaped * 1.035, sin(time * 0.3) * 0.02) / vec2(aspect, 1.0) + warp * 1.6 + vec2(sin(time * 0.7), cos(time * 0.5)) * 0.004;
    vec3 ghost = texture(InSampler, ghostCoord).rgb;
    color = mix(color, max(color, ghost), 0.35 * ramp);

    float mist = 1.0 - exp(-linearDistance(center) / 45.0);

    float smokeLuma = 0.0;
    float smokeWeight = 0.0;
    for (int i = 0; i < 10; i++) {
        float s = (float(i) + 1.0) / 10.0;
        vec2 curl = vec2(flow(vec2(center.x * aspect, center.y) * 3.0 + float(i) * 0.37, time * 0.6), flow(vec2(center.x * aspect, center.y) * 3.0 - float(i) * 0.41, time * 0.6)) - 0.45;
        vec2 source = center + curl * 0.05 * s - vec2(0.0, Smoke.y * s);
        float w = 1.0 - s * 0.6;
        smokeLuma += dot(texture(InSampler, source).rgb, vec3(0.2126, 0.7152, 0.0722)) * w;
        smokeWeight += w;
    }
    smokeLuma /= smokeWeight;
    float wisp = smoothstep(0.3, 0.75, flow(vec2(center.x * aspect * 5.0, center.y * 5.0 - time * 0.5), time * 0.7));
    float smoke = Smoke.x * smoothstep(0.08, 0.6, smokeLuma) * mix(0.35, 1.0, wisp);

    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    float tone = pow(max(luma, 0.0), Smoke.z);
    tone = mix(tone, smoothstep(0.04, 0.62, tone), Look.x);
    tone = mix(tone, 0.12 + tone * 0.2, mist * 0.45);
    tone = 1.0 - (1.0 - tone) * (1.0 - smoke);
    vec3 graded = mix(vec3(tone), color * tone / max(luma, 1e-4), 1.0 - Look.x) * Tint.rgb;

    float angle = atan(shaped.y, shaped.x);
    float streak = noise(vec2(angle * 18.0, radius * 3.0 - time * 1.8)) * noise(vec2(angle * 41.0, radius * 1.5 - time * 1.1));
    float vignette = smoothstep(Look.y + 0.55, Look.y * 0.35, radius);
    vignette = clamp(vignette - streak * edge * 0.35, 0.0, 1.0);
    graded *= mix(0.04, 1.0, vignette);
    graded += Tint.rgb * streak * edge * edge * 0.08;

    graded *= 0.94 + 0.06 * noise(vec2(time * 9.0, 0.0));
    graded *= Tint.w;
    graded = mix(graded, vec3(1.0), burst * 0.25);

    fragColor = vec4(clamp(mix(original, graded, ramp), 0.0, 1.0), 1.0);
}
