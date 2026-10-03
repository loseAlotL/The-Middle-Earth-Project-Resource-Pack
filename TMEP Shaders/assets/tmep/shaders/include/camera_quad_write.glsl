#ifndef TMEP_CAMERA_QUAD_WRITE_GLSL
#define TMEP_CAMERA_QUAD_WRITE_GLSL

#include <tmep:world.glsl>

layout(location = 0) out vec2 texCoord;
layout(location = 1) flat out vec4 quadCamera[19];

void camera_quad_main(sampler2D scene) {
    vec2 uv = vec2((gl_VertexIndex << 1) & 2, gl_VertexIndex & 2);
    gl_Position = vec4(uv * 2.0 - 1.0, 0.0, 1.0);
    texCoord = uv;
    Camera camera = camera_load(scene);
    for (int i = 0; i < 4; i++) {
        quadCamera[i] = camera.view[i];
        quadCamera[4 + i] = camera.projection[i];
        quadCamera[8 + i] = camera.inverseView[i];
        quadCamera[12 + i] = camera.inverseProjection[i];
    }
    quadCamera[16] = vec4(camera.daytime, camera.fogStart, camera.fogEnd, camera.weather);
    quadCamera[17] = vec4(camera.fogColor, camera_slot(scene, CAMERA_DATA_MARKER_DISTANCE_SLOT));
    quadCamera[18] = vec4(camera.valid ? 1.0 : 0.0, vec2(textureSize(scene, 0)), 0.0);
}

#endif
