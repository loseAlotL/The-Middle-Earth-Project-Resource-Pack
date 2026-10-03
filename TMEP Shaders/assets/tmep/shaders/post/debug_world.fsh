#version 330
#extension GL_ARB_separate_shader_objects : require

#include <tmep:world.glsl>

uniform sampler2D InSampler;
uniform sampler2D DepthSampler;

layout(location = 0) in vec2 texCoord;

layout(location = 0) out vec4 fragColor;

float gridLine(float coordinate, float width) {
    float f = fract(coordinate);
    return 1.0 - smoothstep(0.0, width, min(f, 1.0 - f));
}

void main() {
    ivec2 pixel = ivec2(gl_FragCoord.xy);
    vec3 scene = camera_scene_color(InSampler, pixel);
    Camera camera = camera_load(InSampler);

    if (!camera.valid) {
        vec2 screen = vec2(textureSize(InSampler, 0));
        vec2 fromTop = vec2(gl_FragCoord.x, screen.y - gl_FragCoord.y);
        if (fromTop.y < 24.0 && fromTop.x < 24.0 * float(CAMERA_DATA_SLOTS)) {
            int slot = int(fromTop.x / 24.0);
            vec3 raw = texelFetch(InSampler, camera_data_slot_pixel(slot, textureSize(InSampler, 0)), 0).rgb;
            fragColor = vec4(fract(fromTop.x / 24.0) < 0.08 ? vec3(1.0) : raw, 1.0);
            return;
        }
        fragColor = vec4(mix(scene, vec3(1.0, 0.0, 0.0), 0.35), 1.0);
        return;
    }

    float depth = texelFetch(DepthSampler, pixel, 0).r;
    if (depth <= 0.0) {
        vec3 ray = camera_ray(camera, texCoord);
        fragColor = vec4(mix(scene, ray * 0.5 + 0.5, 0.25), 1.0);
        return;
    }

    vec3 world = camera_relative(camera, texCoord, depth) + camera_world_origin();
    float block = max(gridLine(world.x, 0.03), gridLine(world.z, 0.03));
    float chunk = max(gridLine(world.x / 16.0, 0.004), gridLine(world.z / 16.0, 0.004));
    float level = gridLine(world.y, 0.02);
    vec3 color = mix(scene, vec3(1.0, 0.25, 0.85), block * 0.75);
    color = mix(color, vec3(0.2, 1.0, 1.0), chunk);
    color = mix(color, vec3(1.0, 0.85, 0.2), level * 0.5);
    fragColor = vec4(color, 1.0);
}
