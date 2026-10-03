#version 330
#extension GL_ARB_separate_shader_objects : require

#include <minecraft:fog.glsl>
#include <minecraft:dynamictransforms.glsl>
#include <minecraft:oit.glsl>
#include <tmep:water_depth.glsl>
#include <minecraft:globals.glsl>
#include <tmep:camera_data.glsl>

layout(location = 0) in float sphericalVertexDistance;
layout(location = 1) in float cylindricalVertexDistance;
layout(location = 2) in vec4 vertexColor;

#ifndef OIT_ALPHA_ONLY
layout(location = 0) out vec4 fragColor;
#endif

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
    if (camera_data_in_strip(ivec2(gl_FragCoord.xy), ivec2(ScreenSize))) {
        discard;
    }
    vec4 color = vertexColor * ColorModulator;
    gl_FragDepth = water_depth_mark_flag(gl_FragCoord.z, 0.25);
    #ifdef OIT_ALPHA_ONLY
    #if defined(OIT_DEPTH_BOUNDS) && defined(TMEP_OIT_FLAGS)
    oitDepthBoundsHand = true;
    #endif
    executeAlphaOnlyPhase(gl_FragCoord.z, color.a);
    #else
    fragColor = calculateFinalColor(color);
    #endif
}
