#version 330
#extension GL_ARB_separate_shader_objects : require

#include <minecraft:globals.glsl>
#include <tmep:precision.glsl>

uniform sampler2D InSampler;
uniform sampler2D DepthSampler;
uniform sampler2D StateSampler;

layout(location = 0) in vec2 texCoord;

layout(std140) uniform SonarConfig {
    vec4 Pulse;
    vec4 Tint;
};

layout(location = 0) out vec4 fragColor;

float rayScale;

float sceneDistance(ivec2 pixel) {
    float depth = texelFetch(DepthSampler, pixel, 0).r;
    return depth > 0.0 ? 0.05 / depth * rayScale : 1e4;
}

void main() {
    ivec2 pixel = ivec2(gl_FragCoord.xy);
    vec3 color = texelFetch(InSampler, pixel, 0).rgb;
    vec2 screen = vec2(textureSize(InSampler, 0));
    vec2 ndc = texCoord * 2.0 - 1.0;
    float tanY = 0.7;
    rayScale = length(vec3(ndc.x * tanY * screen.x / screen.y, ndc.y * tanY, 1.0));

    float start = precise_decode(texelFetch(StateSampler, ivec2(0), 0));
    float elapsed = fract(GameTime - start + 1.0) * 1200.0;
    float radius = elapsed * Pulse.x;
    float life = 1.0 - smoothstep(Pulse.z * 0.6, Pulse.z, elapsed);
    if (life <= 0.0) {
        fragColor = vec4(color, 1.0);
        return;
    }

    float distance = sceneDistance(pixel);
    float around = 0.0;
    around = max(around, abs(sceneDistance(pixel + ivec2(1, 0)) - distance));
    around = max(around, abs(sceneDistance(pixel - ivec2(1, 0)) - distance));
    around = max(around, abs(sceneDistance(pixel + ivec2(0, 1)) - distance));
    around = max(around, abs(sceneDistance(pixel - ivec2(0, 1)) - distance));
    float edge = smoothstep(0.02, 0.08, around / max(distance, 0.5));

    float front = exp(-pow((distance - radius) / Pulse.y, 2.0));
    float revealed = distance < radius ? exp(-(radius - distance) / (Pulse.x * 1.2)) : 0.0;
    float far = 1.0 - smoothstep(Pulse.w * 0.7, Pulse.w, distance);

    vec3 glow = Tint.rgb * (front * 0.45 + edge * (front * 1.6 + revealed * 0.9)) * far * life;
    color = color * mix(1.0, Tint.w, life * far) + glow;
    fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
