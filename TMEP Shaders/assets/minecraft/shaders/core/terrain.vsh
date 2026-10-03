#version 330
#extension GL_ARB_separate_shader_objects : require

#include <minecraft:fog.glsl>
#include <minecraft:globals.glsl>
#include <minecraft:projection.glsl>
#include <minecraft:sample_lightmap.glsl>
#include <minecraft:terrainglobals.glsl>
#ifndef MULTIDRAW_TERRAIN
    #include <minecraft:chunksection.glsl>
#endif
#include <tmep:water.glsl>
#include <tmep:lighting.glsl>
#include <tmep:foliage.glsl>

layout(location = 0) in vec3 Position;
layout(location = 1) in vec4 Color;
layout(location = 2) in vec2 UV0;
layout(location = 3) in ivec2 UV2;
#ifdef MULTIDRAW_TERRAIN
layout(location = 4) in ivec3 ChunkPosition;
layout(location = 5) in float ChunkVisibility;
#endif

uniform sampler2D Sampler0;
#ifndef OIT_ALPHA_ONLY
uniform sampler2D Sampler2;
#endif

layout(location = 0) out vec4 v_Color;
layout(location = 1) out vec2 v_TexCoord;
layout(location = 2) out float sphericalVertexDistance;
layout(location = 3) out float cylindricalVertexDistance;
layout(location = 4) out vec3 v_RegionPos;
layout(location = 5) out vec3 v_ViewPos;
layout(location = 6) flat out vec4 v_TimeDay;
layout(location = 7) out vec2 v_Light;
layout(location = 8) flat out vec2 v_SpriteMin;
layout(location = 9) out float v_WaveWeight;
layout(location = 10) out float v_Lift;
layout(location = 11) out vec4 v_Vert;
layout(location = 12) flat out vec4 v_Sun;
layout(location = 13) flat out vec4 v_SunColor;
layout(location = 14) flat out vec4 v_Vis;
layout(location = 15) out float chunkVisibility;

void main() {
    vec3 pos = Position + vec3(ChunkPosition - CameraBlockPos) + CameraOffset;
    ivec3 regionSize = ivec3(128, 64, 128);
    vec3 regionPos = vec3(((ChunkPosition % regionSize) + regionSize) % regionSize) + Position;
    float time = GameTime * 1200.0;
    vec2 atlasSize = vec2(TextureSize);
    vec2 texel = 1.0 / atlasSize;

    float waterKind = 0.0;
    vec2 waterProbe = UV0;
    for (int i = 0; i < 4 && WATER_VERTEX_WAVES == 1; i++) {
        vec2 probe = UV0 + texel * 0.5 * vec2((i & 1) == 0 ? -1.0 : 1.0, (i & 2) == 0 ? -1.0 : 1.0);
        float kind = water_kind(textureLod(Sampler0, probe, 0.0).a);
        if (kind > waterKind) {
            waterKind = kind;
            waterProbe = probe;
        }
    }

    int foliageKind = 0;
    bool foliageTop = false;
#ifdef ALPHA_CUTOUT
    if (FOLIAGE_SWAY_ENABLED == 1 && waterKind < 0.5) {
        vec2 corner = floor(UV0 * atlasSize / 16.0 + 0.5) * 16.0;
        for (int i = 0; i < 4 && foliageKind == 0; i++) {
            vec2 origin = corner - vec2((i & 1) == 0 ? 0.0 : 16.0, (i & 2) == 0 ? 0.0 : 16.0);
            foliageKind = foliage_kind(Sampler0, ivec2(origin));
            foliageTop = UV0.y * atlasSize.y - origin.y < 8.0;
        }
    }
#endif

    float waveWeight = water_wave_weight(waterKind, regionPos.y);
    float lift = 0.0;
    if (waveWeight > 0.0) {
        lift = water_vertex_lift(regionPos, WATER_DEBUG == 5 ? 0.0 : time) * waveWeight;
        pos.y += lift;
        regionPos.y += lift;
    }
    v_Lift = lift;
    v_WaveWeight = waveWeight;

    float phase = -1.0;
    float day = 1.0;
#ifndef OIT_ALPHA_ONLY
    phase = sun_clock_phase(Sampler2);
#endif
    if (foliageKind > 0) {
        float windWeather = 1.0;
#ifndef OIT_ALPHA_ONLY
        if (phase >= 0.0) {
            windWeather = sun_clock_weather(Sampler2);
        }
#endif
        vec3 offset = foliage_offset(foliageKind, foliageTop, regionPos, time) * mix(FOLIAGE_RAIN_BOOST, 1.0, smoothstep(0.69, 1.0, windWeather));
        pos += offset;
        regionPos += offset;
    }

    gl_Position = ProjMat * ModelViewMat * vec4(pos, 1.0);
    sphericalVertexDistance = fog_spherical_distance(pos);
    cylindricalVertexDistance = fog_cylindrical_distance(pos);

#ifndef OIT_ALPHA_ONLY
    v_Color = Color * sample_lightmap(Sampler2, UV2);
    vec3 daylight = texture(Sampler2, vec2(0.5 / 16.0, 15.5 / 16.0)).rgb;
    day = dot(daylight, vec3(0.2126, 0.7152, 0.0722));
    if (phase >= 0.0) {
        vec3 sun = sun_clock_direction(phase);
        float weather = sun_clock_weather(Sampler2);
        LightState state = light_state(phase, weather);
        v_Sun = vec4(state.sun, weather);
        v_SunColor = vec4(state.sunColor, state.exposure);
        v_Vis = vec4(state.sunVisibility, state.moonVisibility, state.twilight, state.rain);
        day = mix(0.15, 1.0, smoothstep(-0.05, 0.4, sun.y)) * mix(0.6, 1.0, weather);
    } else {
        v_Sun = vec4(0.0, 1.0, 0.0, -1.0);
        v_SunColor = vec4(0.0);
        v_Vis = vec4(0.0);
    }
#else
    v_Color = Color;
    v_Sun = vec4(0.0, 1.0, 0.0, -1.0);
    v_SunColor = vec4(0.0);
    v_Vis = vec4(0.0);
#endif
    v_Vert = Color;
    v_TexCoord = UV0;
    v_RegionPos = regionPos;
    v_ViewPos = pos;
    v_TimeDay = vec4(time, day, phase, 0.0);
    v_Light = (vec2(UV2) + 8.0) / 256.0;
    v_SpriteMin = floor(waterProbe * atlasSize / WATER_SPRITE_PIXELS_VERTEX) * WATER_SPRITE_PIXELS_VERTEX * texel;

    const float chunkFullyVisibleRange = 16.0;
    float dist = length(pos);
    chunkVisibility = mix(1.0, ChunkVisibility, clamp((dist - chunkFullyVisibleRange) / chunkFullyVisibleRange, 0.0, 1.0));
}
