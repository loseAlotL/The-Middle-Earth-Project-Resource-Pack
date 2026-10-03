#version 460 core

#include <sodium:globals.glsl>
#include <sodium:fog.glsl>
#include <sodium:chunk_material.glsl>
#include <minecraft:oit.glsl>
#include <tmep:water_surface.glsl>
#include <tmep:water_depth.glsl>
#include <tmep:lighting.glsl>

layout(location = 0) in vec4 v_Color;
layout(location = 1) in vec2 v_TexCoord;
layout(location = 2) in vec2 v_FragDistance;
layout(location = 3) in float fadeFactor;
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

#include <tmep:terrain_state.glsl>


uniform sampler2D u_BlockTex;
#ifndef OIT_ALPHA_ONLY
uniform sampler2D u_LightTex;
#endif

#ifndef OIT_ALPHA_ONLY
layout(location = 0) out vec4 fragColor;
#endif

vec4 calculateFinalColor(vec4 color) {
    #ifdef OIT_ACCUMULATE
        color = sampleColorForAccumulation(color);
        vec4 fogColor = vec4(u_FogColor.rgb * color.a, u_FogColor.a);
    #else
        vec4 fogColor = u_FogColor;
    #endif
    if (v_TimeDay.z >= 0.0) {
        vec3 duskFog = light_dusk_fog(vertexLightState(), fogColor.rgb, normalize(v_ViewPos));
        fogColor.rgb = duskFog;
    }

    #ifdef OIT_ALPHA_ONLY
    float factor = 1.0;
    #else
    float factor = fadeFactor;
    #endif

    return _linearFog(color, v_FragDistance, fogColor, u_EnvironmentFog, u_RenderFog, factor);
}

vec4 sampleNearest(sampler2D source, vec2 uv, vec2 pixelSize, vec2 du, vec2 dv, vec2 texelScreenSize) {
    vec2 uvTexelCoords = uv / pixelSize;
    vec2 texelCenter = round(uvTexelCoords) - 0.5f;
    vec2 texelOffset = uvTexelCoords - texelCenter;

    texelOffset = (texelOffset - 0.5f) * pixelSize / texelScreenSize + 0.5f;
    texelOffset = clamp(texelOffset, 0.0f, 1.0f);

    uv = (texelCenter + texelOffset) * pixelSize;
    return textureGrad(source, uv, du, dv);
}

vec4 sampleNearest(sampler2D source, vec2 uv, vec2 pixelSize) {
    vec2 du = dFdx(uv);
    vec2 dv = dFdy(uv);
    vec2 texelScreenSize = sqrt(du * du + dv * dv);
    return sampleNearest(source, uv, pixelSize, du, dv, texelScreenSize);
}

vec4 sampleRGSS(sampler2D source, vec2 uv, vec2 pixelSize) {
    vec2 du = dFdx(uv);
    vec2 dv = dFdy(uv);

    vec2 texelScreenSize = sqrt(du * du + dv * dv);
    float maxTexelSize = max(texelScreenSize.x, texelScreenSize.y);

    float minPixelSize = min(pixelSize.x, pixelSize.y);

    float transitionStart = minPixelSize * 1.0;
    float transitionEnd = minPixelSize * 2.0;
    float blendFactor = smoothstep(transitionStart, transitionEnd, maxTexelSize);

    float duLength = length(du);
    float dvLength = length(dv);
    float minDerivative = min(duLength, dvLength);
    float maxDerivative = max(duLength, dvLength);

    float effectiveDerivative = sqrt(minDerivative * maxDerivative);

    float mipLevelExact = max(0.0, log2(effectiveDerivative / minPixelSize));

    const vec2 offsets[4] = vec2[](
    vec2(0.125, 0.375),
    vec2(-0.125, -0.375),
    vec2(0.375, -0.125),
    vec2(-0.375, 0.125)
    );

    vec4 rgssColor = vec4(0.0);
    for (int i = 0; i < 4; ++i) {
        vec2 sampleUV = uv + offsets[i] * pixelSize;
        rgssColor += textureLod(source, sampleUV, mipLevelExact);
    }
    rgssColor *= 0.25;

    vec4 nearestColor = sampleNearest(source, uv, pixelSize, du, dv, texelScreenSize);

    return mix(nearestColor, rgssColor, blendFactor);
}

#define TERRAIN_BLOCK_TEX u_BlockTex
#define TERRAIN_SPRITE_MIN v_SpriteMin
#define TERRAIN_LIGHT_TEX u_LightTex
#define TERRAIN_TEXEL_SIZE u_TexelSize
#define TERRAIN_FOG_COLOR u_FogColor
#define TERRAIN_MODEL_VIEW u_ModelViewMatrix
#define TERRAIN_UNDERWATER (abs(u_EnvironmentFog.x - WATER_UNDERWATER_FOG_START) < 0.5 && u_EnvironmentFog.y < 96.5)
#define TERRAIN_SAMPLE_TEXEL (u_UseRGSS ? sampleRGSS(u_BlockTex, v_TexCoord, u_TexelSize) : sampleNearest(u_BlockTex, v_TexCoord, u_TexelSize))

#include <tmep:terrain_fragment.glsl>

void main() {
    terrain_main();
}
