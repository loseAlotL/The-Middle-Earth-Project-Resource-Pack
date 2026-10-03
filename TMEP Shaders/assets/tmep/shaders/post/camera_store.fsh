#version 330
#extension GL_ARB_separate_shader_objects : require

#include <tmep:world.glsl>

uniform sampler2D InSampler;

layout(location = 0) in vec2 texCoord;

layout(location = 0) out vec4 fragColor;

void main() {
    int slot = int(gl_FragCoord.x);
    ivec2 size = textureSize(InSampler, 0);
    if (slot < CAMERA_DATA_SLOTS) {
        fragColor = texelFetch(InSampler, camera_data_slot_pixel(slot, size), 0);
    } else if (slot < CAMERA_DATA_SLOTS + 3) {
        vec3 origin = camera_world_origin();
        fragColor = vec4(camera_data_encode(origin[slot - CAMERA_DATA_SLOTS]), 1.0);
    } else {
        fragColor = vec4(0.0);
    }
}
