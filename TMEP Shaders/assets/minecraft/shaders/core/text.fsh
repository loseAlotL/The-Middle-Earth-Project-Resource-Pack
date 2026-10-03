#version 330
#extension GL_ARB_separate_shader_objects : require

#if !defined(IS_GUI) && !defined(IS_SEE_THROUGH)
#define TMEP_WORLD_TEXT
#include <minecraft:fog.glsl>
#include <minecraft:globals.glsl>
#endif

#include <minecraft:dynamictransforms.glsl>
#include <minecraft:oit.glsl>

uniform sampler2D Sampler0;

#ifdef TMEP_WORLD_TEXT
layout(location = 0) in float sphericalVertexDistance;
layout(location = 1) in float cylindricalVertexDistance;
#endif

layout(location = 2) in vec4 vertexColor;
layout(location = 3) in vec2 texCoord0;

#ifdef TMEP_WORLD_TEXT
layout(location = 4) in vec3 mistData;
#endif

#ifndef OIT_ALPHA_ONLY
layout(location = 0) out vec4 fragColor;
#endif

vec4 calculateFinalColor(vec4 color) {
    #ifdef OIT_ACCUMULATE
    color = sampleColorForAccumulation(color);
    #endif

    #ifdef TMEP_WORLD_TEXT

    #ifdef OIT_ACCUMULATE
    vec4 fogColor = vec4(FogColor.rgb * color.a, FogColor.a);
    #else
    vec4 fogColor = FogColor;
    #endif

    color = apply_fog(color, sphericalVertexDistance, cylindricalVertexDistance, FogEnvironmentalStart, FogEnvironmentalEnd, FogRenderDistanceStart, FogRenderDistanceEnd, fogColor);
    #endif

    return color;
}

void main() {
    vec4 color;

    #ifdef TMEP_WORLD_TEXT
    if (mistData.z > 0.5) {
        color = mist_blob_color(mistData.xy, sphericalVertexDistance, GameTime);
        if (color.a < 0.004) {
            discard;
        }
    } else
    #endif
    {
        #ifdef IS_GRAYSCALE
        vec4 texColor = texture(Sampler0, texCoord0).rrrr;
        #else
        vec4 texColor = texture(Sampler0, texCoord0);
        #endif

        color = texColor * vertexColor * ColorModulator;

        if (color.a < 0.1) {
            discard;
        }
    }

    #ifdef OIT_ALPHA_ONLY
    executeAlphaOnlyPhase(gl_FragCoord.z, color.a);
    #else
    fragColor = calculateFinalColor(color);
    #endif
}
