#version 330

#extension GL_ARB_separate_shader_objects : require

#include <minecraft:globals.glsl>

uniform sampler2D InSampler;
uniform sampler2D StateSampler;
uniform sampler2D AfterimageSampler;

layout(std140) uniform FlashConfig {
    vec4 Timing;
    vec4 Daze;
};

layout(std140) uniform SamplerInfo {
    vec2 OutSize;
    vec2 InSize;
};

layout(location = 0) in vec2 texCoord;
layout(location = 0) out vec4 fragColor;

vec3 blurred(vec2 uv, float radius) {
    vec3 total = texture(InSampler, uv).rgb;
    if (radius < 0.0005) {
        return total;
    }
    float aspect = InSize.x / InSize.y;
    for (int i = 0; i < 12; i++) {
        float angle = float(i) * 2.39996;
        float reach = sqrt((float(i) + 0.5) / 12.0) * radius;
        total += texture(InSampler, clamp(uv + vec2(cos(angle) / aspect, sin(angle)) * reach, vec2(0.0), vec2(1.0))).rgb;
    }
    return total / 13.0;
}

void main() {
    vec4 state = texelFetch(StateSampler, ivec2(0), 0);
    float start = (state.r * 255.0 + state.g) / 255.0;
    float elapsed = state.a > 0.5 ? fract(GameTime - start + 1.0) * 1200.0 : 0.0;
    float recover = max(elapsed - Timing.x, 0.0);
    float clearing = smoothstep(0.0, Timing.y, recover);
    float settle = 1.0 - smoothstep(0.0, Timing.y * 1.4, recover);

    vec2 centered = texCoord - 0.5;
    float edge = length(centered * vec2(InSize.x / InSize.y, 1.0)) / 0.9;
    float white = 1.0 - smoothstep(edge * 0.5, edge * 0.5 + 0.45, clearing);
    white *= white;

    float seconds = GameTime * 1200.0;
    vec2 tremor = vec2(sin(seconds * 37.0) + sin(seconds * 23.0) * 0.6, cos(seconds * 29.0) + sin(seconds * 41.0) * 0.5) * Daze.z * settle * settle;
    vec2 uv = texCoord + tremor;
    float radius = Daze.x * settle;
    vec3 scene = blurred(uv, radius);
    vec3 doubled = blurred(uv + vec2(Daze.y * settle, -Daze.y * 0.3 * settle), radius);
    scene = mix(scene, doubled, 0.4 * settle);

    float luma = dot(scene, vec3(0.2126, 0.7152, 0.0722));
    vec3 dazed = mix(scene, vec3(luma), settle * 0.7);
    vec3 color = mix(dazed, vec3(1.0), white);

    vec3 ghost = texture(AfterimageSampler, texCoord).rgb;
    float ghostLuma = dot(ghost, vec3(0.2126, 0.7152, 0.0722));
    float lingering = exp(-recover / Timing.w) * (1.0 - white);
    float flip = smoothstep(Timing.y * 0.35, Timing.y * 0.75, recover);
    float positive = Timing.z * lingering * (1.0 - flip);
    float negative = Timing.z * Daze.w * lingering * flip;
    color = 1.0 - (1.0 - color) * (1.0 - vec3(1.0, 0.96, 0.88) * ghostLuma * positive);
    color *= 1.0 - clamp(ghost * ghost * 1.4, 0.0, 1.0) * negative;
    fragColor = vec4(color, 1.0);
}
