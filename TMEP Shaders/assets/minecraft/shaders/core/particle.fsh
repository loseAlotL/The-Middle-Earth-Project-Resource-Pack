#version 330
#extension GL_ARB_separate_shader_objects : require

#include <minecraft:fog.glsl>
#include <minecraft:dynamictransforms.glsl>
#include <minecraft:oit.glsl>

uniform sampler2D Sampler0;

layout(location = 0) in float sphericalVertexDistance;
layout(location = 1) in float cylindricalVertexDistance;
layout(location = 2) in vec2 texCoord0;
layout(location = 3) in vec4 vertexColor;

#ifndef OIT_ALPHA_ONLY
layout(location = 0) out vec4 fragColor;
#endif

const ivec3 RAIN_MARKER = ivec3(211, 221, 237);

vec4 calculateFinalColor(vec4 color) {
    #ifdef OIT_ACCUMULATE
    color = sampleColorForAccumulation(color);
    vec4 fogColor = vec4(FogColor.rgb * color.a, FogColor.a);
    #else
    vec4 fogColor = FogColor;
    #endif
    return apply_fog(color, sphericalVertexDistance, cylindricalVertexDistance, FogEnvironmentalStart, FogEnvironmentalEnd, FogRenderDistanceStart, FogRenderDistanceEnd, fogColor);
}

void main() {
    vec4 texel = texture(Sampler0, texCoord0);
    vec4 color = texel * vertexColor * ColorModulator;
    float cutoff = 0.1;
    bool rain = texel.a > 0.0 && all(equal(ivec3(round(texel.rgb * 255.0)), RAIN_MARKER));
    if (rain) {
        float light = max(max(vertexColor.r, vertexColor.g), vertexColor.b);
        vec3 tint = mix(FogColor.rgb, vec3(0.9, 0.93, 1.0), 0.4);
        color.rgb = tint * mix(0.3, 1.15, light);
        color.a = texel.a * vertexColor.a * 0.55 * smoothstep(1.2, 4.0, sphericalVertexDistance) * (1.0 - smoothstep(5.0, 12.0, sphericalVertexDistance) * 0.55);
        cutoff = 0.02;
    }
    if (color.a < cutoff) {
        discard;
    }
    #if defined(OIT_DEPTH_BOUNDS) && defined(TMEP_OIT_FLAGS)
    oitDepthBoundsRain = rain;
    #endif
    #ifdef OIT_ALPHA_ONLY
    executeAlphaOnlyPhase(gl_FragCoord.z, color.a);
    #else
    fragColor = calculateFinalColor(color);
    #endif
}
