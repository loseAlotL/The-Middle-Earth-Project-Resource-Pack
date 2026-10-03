#version 330
#extension GL_ARB_separate_shader_objects : require

#include <minecraft:light.glsl>
#include <minecraft:fog.glsl>
#include <minecraft:dynamictransforms.glsl>
#include <minecraft:projection.glsl>
#include <minecraft:sample_lightmap.glsl>
#include <minecraft:globals.glsl>
#include <tmep:camera_data.glsl>
#include <tmep:sun_clock.glsl>

layout(location = 0) in vec3 Position;
layout(location = 1) in vec4 Color;
layout(location = 2) in vec2 UV0;
layout(location = 3) in ivec2 UV1;
layout(location = 4) in ivec2 UV2;
#ifdef GLINT_SPECIAL
layout(location = 5) in vec2 UV3;
#endif
layout(location = 6) in vec3 Normal;

uniform sampler2D Sampler0;

#ifndef OIT_ALPHA_ONLY
uniform sampler2D Sampler1;
uniform sampler2D Sampler2;

layout(location = 0) out float sphericalVertexDistance;
layout(location = 1) out float cylindricalVertexDistance;
#endif
layout(location = 2) out vec4 vertexColor;
#ifndef OIT_ALPHA_ONLY
layout(location = 3) out vec4 lightMapColor;
layout(location = 4) out vec4 overlayColor;
#endif

layout(location = 5) out vec2 texCoord0;
#ifdef GLINT
layout(location = 6) out vec2 texCoordGlint;
#endif
layout(location = 7) flat out float cameraData;
layout(location = 8) flat out float cameraDaytime;
layout(location = 9) out float cameraStripU;
layout(location = 10) flat out float cameraWeather;
layout(location = 11) flat out float cameraMarkerDistance;
layout(location = 12) flat out float cameraSky;
layout(location = 13) flat out float heatTint;

void main() {
    gl_Position = ProjMat * ModelViewMat * vec4(Position, 1.0);

    cameraData = 0.0;
    cameraDaytime = -1.0;
    cameraStripU = 0.0;
    cameraWeather = -1.0;
    cameraMarkerDistance = 0.0;
    cameraSky = clamp(float(UV2.y) / 240.0, 0.0, 1.0);
    vec2 paramTexel = 0.5 / vec2(textureSize(Sampler0, 0));
    bool paramSprite = false;
    for (int i = 0; i < 4; i++) {
        vec2 probe = UV0 + paramTexel * vec2((i & 1) == 0 ? -1.0 : 1.0, (i & 2) == 0 ? -1.0 : 1.0);
        paramSprite = paramSprite || all(equal(round(textureLod(Sampler0, probe, 0.0).rgb * 255.0), CAMERA_PARAM_SIGNATURE));
    }
    int paramIndex = paramSprite ? camera_param_index(Color) : -1;
    if (paramIndex >= 0) {
        const vec2 paramCorners[4] = vec2[](vec2(0.0, 0.0), vec2(1.0, 0.0), vec2(1.0, 1.0), vec2(0.0, 1.0));
        vec2 corner = paramCorners[gl_VertexIndex % 4];
        float slot = float(CAMERA_DATA_PARAM_SLOT + paramIndex);
        float u = mix(slot, slot + 1.0, corner.x) / float(CAMERA_DATA_SLOTS);
        gl_Position = vec4(vec2(u * CAMERA_STRIP_WIDTH, corner.y * CAMERA_STRIP_HEIGHT) * 2.0 - 1.0, 0.9999, 1.0);
        cameraData = 2.0;
        cameraDaytime = camera_param_value(Color);
    } else if (camera_data_is_marker(Color)) {
        cameraMarkerDistance = length((ModelViewMat * vec4(Position, 1.0)).xyz);
        #ifndef OIT_ALPHA_ONLY
        if (sun_clock_phase(Sampler2) >= 0.0) {
            cameraWeather = sun_clock_weather(Sampler2);
        }
        #endif
        const vec2 corners[4] = vec2[](vec2(0.0, 0.0), vec2(1.0, 0.0), vec2(1.0, 1.0), vec2(0.0, 1.0));
        vec2 corner = corners[gl_VertexIndex % 4];
        if (camera_data_reversed(Color)) {
            corner = corner.yx;
        }
        mat3 view = mat3(ModelViewMat);
        vec3 lengths = vec3(length(view[0]), length(view[1]), length(view[2]));
        bool upright = all(lessThan(abs(lengths - 1.0), vec3(0.02))) && abs(ModelViewMat[1][0]) < 0.5 && abs(determinant(view) - 1.0) < 0.05;
        gl_Position = upright ? vec4(corner * vec2(CAMERA_STRIP_WIDTH, CAMERA_STRIP_HEIGHT) * 2.0 - 1.0, 0.9999, 1.0) : vec4(0.0, 0.0, 2.0, 1.0);
        cameraStripU = corner.x;
        cameraData = 1.0;
        cameraDaytime = camera_data_daytime(Color);
    }

    #ifndef OIT_ALPHA_ONLY
    sphericalVertexDistance = fog_spherical_distance(Position);
    cylindricalVertexDistance = fog_cylindrical_distance(Position);
    #endif
    heatTint = all(equal(ivec3(Color.rgb * 255.0 + 0.5), ivec3(254, 253, 254))) ? 1.0 : 0.0;
    vertexColor = minecraft_mix_light(Light0_Direction, Light1_Direction, Normal, heatTint > 0.5 ? vec4(1.0, 1.0, 1.0, Color.a) : Color);
    #ifndef OIT_ALPHA_ONLY
    lightMapColor = sample_lightmap(Sampler2, UV2);
    overlayColor = texelFetch(Sampler1, UV1, 0);
    #endif

    texCoord0 = UV0;
    #ifdef GLINT
    #ifdef GLINT_SPECIAL
    texCoordGlint = (TextureMat * vec4(UV3, 0.0, 1.0)).xy;
    #else
    texCoordGlint = (TextureMat * vec4(UV0, 0.0, 1.0)).xy;
    #endif
    #endif
}
