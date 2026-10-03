#version 330
#extension GL_ARB_separate_shader_objects : require

#include <sodium:globals.glsl>
#include <sodium:fog.glsl>
#include <sodium:chunk_vertex.glsl>
#include <tmep:water.glsl>
#include <tmep:lighting.glsl>
#include <tmep:foliage.glsl>

layout(location = 0) out vec4 v_Color;
layout(location = 1) out vec2 v_TexCoord;

#ifdef USE_FOG
layout(location = 2) out vec2 v_FragDistance;
layout(location = 3) out float fadeFactor;
#endif

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

uniform isamplerBuffer u_SectionTimeInfo;
uniform sampler2D u_BlockTex;

#ifdef VULKAN
layout(push_constant) uniform PC {
    vec3 u_RegionOffset;
    int u_CurrentTime;
    uint u_RegionID;
};
#else
uniform vec3 u_RegionOffset;
uniform int u_CurrentTime;
uniform uint u_RegionID;
#endif

#ifndef OIT_ALPHA_ONLY
uniform sampler2D u_LightTex;
#endif

uvec3 _get_relative_chunk_coord(uint pos) {
    return uvec3(pos) >> uvec3(5u, 0u, 2u) & uvec3(7u, 3u, 7u);
}

vec3 _get_draw_translation(uint pos) {
    return _get_relative_chunk_coord(pos) * vec3(16.0);
}

void main() {
    _vert_init();

    vec3 drawTranslation = _get_draw_translation(_draw_id);
    vec3 regionPos = _vert_position + drawTranslation;
    float regionTime = water_time(u_CurrentTime);
#ifndef OIT_ALPHA_ONLY
    float time = sun_clock_seconds(u_LightTex);
#else
    float time = regionTime;
#endif

    vec2 probe = _vert_tex_diffuse_coord - _vert_tex_diffuse_coord_bias * u_TexelSize * 0.5;
    vec4 probeTexel = textureLod(u_BlockTex, probe, 0.0);
    float waterKind = water_kind(probeTexel.a);
    int foliageKind = 0;
    if (FOLIAGE_SWAY_ENABLED == 1 && waterKind < 0.5 && ((_material_params >> 1u) & 3u) != 0u) {
        ivec2 corner = ivec2(floor(probe / u_TexelSize));
        ivec2 origin = corner - ivec2(step(vec2(0.0), _vert_tex_diffuse_coord_bias)) * 15;
        foliageKind = foliage_kind(u_BlockTex, origin);
    }
    float waveWeight = water_wave_weight(waterKind, regionPos.y);
    float lift = 0.0;
    if (waveWeight > 0.0) {
        vec2 edge = min(regionPos.xz, WATER_REGION - regionPos.xz);
        float taper = smoothstep(0.0, 6.0, min(edge.x, edge.y));
        lift = water_vertex_lift(regionPos, WATER_DEBUG == 5 ? 0.0 : regionTime) * waveWeight * taper;
        regionPos.y += lift;
    }
    v_Lift = lift;
    v_WaveWeight = waveWeight;

    if (foliageKind > 0) {
        float windWeather = 1.0;
#ifndef OIT_ALPHA_ONLY
        if (sun_clock_phase(u_LightTex) >= 0.0) {
            windWeather = sun_clock_weather(u_LightTex);
        }
#endif
        vec3 offset = foliage_offset(foliageKind, _vert_tex_diffuse_coord_bias.y < 0.0, regionPos, regionTime) * mix(FOLIAGE_RAIN_BOOST, 1.0, smoothstep(0.69, 1.0, windWeather));
        regionPos += offset;
    }
    vec3 position = u_RegionOffset + regionPos;

#ifdef USE_FOG
    v_FragDistance = getFragDistance(position);

    int chunkId = int(_draw_id);
    int chunkFade = texelFetch(u_SectionTimeInfo, int((u_RegionID * 256u) + uint(chunkId))).r;
    float fade = clamp(float(u_CurrentTime - chunkFade) * u_FadePeriodInv, 0.0, 1.0);
    fadeFactor = (chunkFade < 0) ? 1.0 : fade;
#endif

    gl_Position = u_ProjectionMatrix * u_ModelViewMatrix * vec4(position, 1.0);

#ifndef OIT_ALPHA_ONLY
    v_Color = _vert_color * texture(u_LightTex, _vert_tex_light_coord);
    vec3 daylight = texture(u_LightTex, vec2(0.5 / 16.0, 15.5 / 16.0)).rgb;
    float day = dot(daylight, vec3(0.2126, 0.7152, 0.0722));
    float phase = sun_clock_phase(u_LightTex);
    if (phase >= 0.0) {
        vec3 sun = sun_clock_direction(phase);
        float weather = sun_clock_weather(u_LightTex);
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
    v_Color = _vert_color;
    v_Sun = vec4(0.0, 1.0, 0.0, -1.0);
    v_SunColor = vec4(0.0);
    v_Vis = vec4(0.0);
    float phase = -1.0;
    float day = 1.0;
#endif
    v_Vert = _vert_color;

    v_TexCoord = (_vert_tex_diffuse_coord_bias * u_TexCoordShrink) + _vert_tex_diffuse_coord;
    v_RegionPos = regionPos;
    v_ViewPos = position;
    v_TimeDay = vec4(time, day, phase, 0.0);
    v_Light = _vert_tex_light_coord;
    vec2 spriteSize = WATER_SPRITE_PIXELS_VERTEX * u_TexelSize;
    v_SpriteMin = _vert_tex_diffuse_coord - step(vec2(0.0), _vert_tex_diffuse_coord_bias) * spriteSize;
}
