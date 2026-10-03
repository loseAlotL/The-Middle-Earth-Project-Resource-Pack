#version 330
#extension GL_ARB_separate_shader_objects : require

#if !defined(IS_GUI) && !defined(IS_SEE_THROUGH)
#define TMEP_WORLD_TEXT
#include <minecraft:fog.glsl>
#include <minecraft:sample_lightmap.glsl>
#endif

#include <minecraft:dynamictransforms.glsl>
#include <minecraft:projection.glsl>

layout(location = 0) in vec3 Position;
layout(location = 1) in vec4 Color;
layout(location = 2) in vec2 UV0;
#ifdef TMEP_WORLD_TEXT
layout(location = 3) in ivec2 UV2;
#endif

#ifdef TMEP_WORLD_TEXT
uniform sampler2D Sampler2;
layout(location = 0) out float sphericalVertexDistance;
layout(location = 1) out float cylindricalVertexDistance;
#endif

layout(location = 2) out vec4 vertexColor;
layout(location = 3) out vec2 texCoord0;

#ifdef TMEP_WORLD_TEXT
layout(location = 4) out vec3 mistData;
#endif

void main() {
    vec3 position = Position;

#ifdef TMEP_WORLD_TEXT
    sphericalVertexDistance = fog_spherical_distance(Position);
    cylindricalVertexDistance = fog_cylindrical_distance(Position);
    vertexColor = Color * sample_lightmap(Sampler2, UV2);
    mistData = vec3(0.0);
    if (mist_is_blob(Color)) {
        position = mist_blob_push(Position, mist_blob_radius(Color));
        mistData = vec3(mist_blob_corner(gl_VertexIndex), 1.0);
    }
#else
    vertexColor = Color;
#endif

    gl_Position = ProjMat * ModelViewMat * vec4(position, 1.0);
    texCoord0 = UV0;
}
