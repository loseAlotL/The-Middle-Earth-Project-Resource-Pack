#version 330
#extension GL_ARB_separate_shader_objects : require

#include <tmep:lighting.glsl>

#include <minecraft:globals.glsl>
#include <minecraft:fog.glsl>
#include <minecraft:dynamictransforms.glsl>
#include <minecraft:oit.glsl>
#include <minecraft:projection.glsl>
#include <tmep:camera_data.glsl>

uniform sampler2D Sampler0;

#ifdef GLINT
uniform sampler2D GlintSampler;
#endif

#ifndef OIT_ALPHA_ONLY
layout(location = 0) in float sphericalVertexDistance;
layout(location = 1) in float cylindricalVertexDistance;
#endif
layout(location = 2) in vec4 vertexColor;
#ifndef OIT_ALPHA_ONLY
layout(location = 3) in vec4 lightMapColor;
layout(location = 4) in vec4 overlayColor;
#endif
layout(location = 5) in vec2 texCoord0;
#ifdef GLINT
layout(location = 6) in vec2 texCoordGlint;
#endif
layout(location = 7) flat in float cameraData;
layout(location = 8) flat in float cameraDaytime;
layout(location = 9) in float cameraStripU;
layout(location = 10) flat in float cameraWeather;
layout(location = 11) flat in float cameraMarkerDistance;
layout(location = 12) flat in float cameraSky;
layout(location = 13) flat in float heatTint;

#ifndef OIT_ALPHA_ONLY
layout(location = 0) out vec4 fragColor;
#endif

#ifndef OIT_ALPHA_ONLY
vec4 calculateFinalColor(vec4 color) {
    color.rgb = mix(overlayColor.rgb, color.rgb, overlayColor.a);
    color *= lightMapColor;

    #ifdef GLINT
    vec4 glintColor = GlintAlpha * texture(GlintSampler, texCoordGlint);// Glint color modulator?
    // Matches BlendFuntion.GLINT
    color.rgb += glintColor.rgb * glintColor.rgb;
    #endif

    #ifdef OIT_ACCUMULATE
    color = sampleColorForAccumulation(color);
    vec4 fogColor = vec4(FogColor.rgb * color.a, FogColor.a);
    #else
    vec4 fogColor = FogColor;
    #endif

    return apply_fog(color, sphericalVertexDistance, cylindricalVertexDistance, FogEnvironmentalStart, FogEnvironmentalEnd, FogRenderDistanceStart, FogRenderDistanceEnd, fogColor);
}
#endif

void main() {
    if (cameraData > 1.5) {
        #ifdef OIT_ALPHA_ONLY
        discard;
        #else
        fragColor = vec4(camera_data_encode(cameraDaytime), 1.0);
        return;
        #endif
    }
    if (cameraData > 0.5) {
        #ifdef OIT_ALPHA_ONLY
        discard;
        #else
        int slot = clamp(int(cameraStripU * float(CAMERA_DATA_SLOTS)), 0, CAMERA_DATA_SLOTS - 1);
        if (slot >= CAMERA_DATA_PARAM_SLOT && slot < CAMERA_DATA_SKY_SLOT) {
            discard;
        }
        float value = CAMERA_DATA_MAGIC;
        if (slot == CAMERA_DATA_SKY_SLOT) {
            value = cameraSky;
        } else if (slot == CAMERA_DATA_DAYTIME_SLOT) {
            value = cameraDaytime;
        } else if (slot == CAMERA_DATA_FOG_START_SLOT) {
            value = FogEnvironmentalStart;
        } else if (slot == CAMERA_DATA_FOG_END_SLOT) {
            value = FogEnvironmentalEnd;
        } else if (slot == CAMERA_DATA_MARKER_DISTANCE_SLOT) {
            value = cameraMarkerDistance;
        } else if (slot == CAMERA_DATA_WEATHER_SLOT) {
            value = cameraWeather;
        } else if (slot >= CAMERA_DATA_FOG_COLOR_SLOT) {
            value = FogColor[slot - CAMERA_DATA_FOG_COLOR_SLOT];
        } else if (slot < 16) {
            value = ModelViewMat[slot / 4][slot % 4];
        } else if (slot < 32) {
            value = ProjMat[(slot - 16) / 4][(slot - 16) % 4];
        }
        fragColor = vec4(camera_data_encode(value), 1.0);
        return;
        #endif
    }

    if (camera_data_in_strip(ivec2(gl_FragCoord.xy), ivec2(ScreenSize))) {
        discard;
    }

    vec4 color = texture(Sampler0, texCoord0);
    #ifdef ALPHA_CUTOUT
    if (color.a < ALPHA_CUTOUT) {
        discard;
    }
    #endif

    color *= vertexColor * ColorModulator;

    #ifdef GLINT
    color.a = max(color.a, GlintAlpha);
    #endif

    #ifdef OIT_ALPHA_ONLY
    executeAlphaOnlyPhase(gl_FragCoord.z, color.a);
    #else
    fragColor = calculateFinalColor(color);
    #ifndef OIT
    ivec2 markerTexel = ivec2(texCoord0 * vec2(textureSize(Sampler0, 0)));
    if (fragColor.a > 0.99 && heatTint > 0.5) {
        fragColor = vec4(light_heat_stamp(fragColor.rgb), LIGHT_HEAT_ALPHA);
    } else if (fragColor.a > 0.99 && light_marker(texelFetch(Sampler0, markerTexel, 0).rgb, texelFetch(Sampler0, markerTexel ^ ivec2(1, 0), 0).rgb, markerTexel) == 3) {
        fragColor = vec4(light_heat_stamp(fragColor.rgb), LIGHT_HEAT_ALPHA);
    }
    #endif
    #endif
}
