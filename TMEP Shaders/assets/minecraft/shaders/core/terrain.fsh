#version 330
#extension GL_ARB_separate_shader_objects : require

#include <minecraft:fog.glsl>
#include <minecraft:globals.glsl>
#include <minecraft:texture_sampling.glsl>
#include <minecraft:oit.glsl>
#include <minecraft:terrainglobals.glsl>
#ifndef MULTIDRAW_TERRAIN
    #include <minecraft:chunksection.glsl>
#endif
#include <tmep:water_surface.glsl>
#include <tmep:water_depth.glsl>
#include <tmep:lighting.glsl>

layout(location = 0) in vec4 v_Color;
layout(location = 1) in vec2 v_TexCoord;
layout(location = 2) in float sphericalVertexDistance;
layout(location = 3) in float cylindricalVertexDistance;
layout(location = 4) in vec3 v_RegionPos;
layout(location = 5) in vec3 v_ViewPos;
layout(location = 6) flat in vec4 v_TimeDay;
layout(location = 7) in vec2 v_Light;
layout(location = 8) flat in vec2 v_SpriteMin;
layout(location = 9) in float v_WaveWeight;
layout(location = 10) in float v_Lift;
layout(location = 11) in vec4 v_Vert;
layout(location = 12) flat in vec4 v_Sun;
layout(location = 13) flat in vec4 v_SunColor;
layout(location = 14) flat in vec4 v_Vis;
layout(location = 15) in float chunkVisibility;

#include <tmep:terrain_state.glsl>

uniform sampler2D Sampler0;
#ifndef OIT_ALPHA_ONLY
uniform sampler2D Sampler2;
#endif

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
    if (v_TimeDay.z >= 0.0) {
        fogColor.rgb = light_dusk_fog(vertexLightState(), fogColor.rgb, normalize(v_ViewPos));
    }
    return apply_fog(color, sphericalVertexDistance, cylindricalVertexDistance, FogEnvironmentalStart, FogEnvironmentalEnd, FogRenderDistanceStart, FogRenderDistanceEnd, fogColor);
}

#define TERRAIN_BLOCK_TEX Sampler0
#define TERRAIN_SPRITE_MIN (floor(v_TexCoord * vec2(TextureSize) / WATER_SPRITE_PIXELS_VERTEX) * WATER_SPRITE_PIXELS_VERTEX / vec2(TextureSize))
#define TERRAIN_LIGHT_TEX Sampler2
#define TERRAIN_TEXEL_SIZE (1.0 / vec2(TextureSize))
#define TERRAIN_FOG_COLOR FogColor
#define TERRAIN_MODEL_VIEW ModelViewMat
#define TERRAIN_UNDERWATER (abs(FogEnvironmentalStart - WATER_UNDERWATER_FOG_START) < 0.5 && FogEnvironmentalEnd < 96.5)
#define TERRAIN_SAMPLE_TEXEL (UseRgss == 1 ? sampleRGSS(Sampler0, v_TexCoord, 1.0 / vec2(TextureSize)) : sampleNearest(Sampler0, v_TexCoord, 1.0 / vec2(TextureSize)))
#ifndef OIT_ALPHA_ONLY
#define TERRAIN_COLOR_HOOK(color) color = mix(FogColor * vec4(1.0, 1.0, 1.0, color.a), color, chunkVisibility)
#endif

#include <tmep:terrain_fragment.glsl>

void main() {
    terrain_main();
}
