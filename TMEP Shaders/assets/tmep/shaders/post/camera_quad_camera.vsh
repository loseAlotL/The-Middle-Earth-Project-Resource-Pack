#version 330
#extension GL_ARB_separate_shader_objects : require

uniform sampler2D CameraSampler;

#include <tmep:camera_quad_write.glsl>

void main() {
    camera_quad_main(CameraSampler);
}
