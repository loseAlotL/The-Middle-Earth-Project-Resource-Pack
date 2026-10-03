#version 330
#extension GL_ARB_separate_shader_objects : require

#include <tmep:lighting.glsl>
#include <tmep:world.glsl>
#include <tmep:precision.glsl>

uniform sampler2D InSampler;
uniform sampler2D PreviousSampler;
uniform sampler2D CameraSampler;
uniform sampler2D WeatherSampler;

layout(location = 0) in vec2 texCoord;

layout(std140) uniform ExposureConfig {
    vec4 Exposure;
};

layout(location = 0) out vec4 fragColor;

void main() {
    vec4 previous = texelFetch(PreviousSampler, ivec2(0), 0);
    float current = previous.a > 0.5 ? precise_decode(previous) * 2.0 : 1.0;
    float total = 0.0;
    for (int y = 0; y < 32; y++) {
        for (int x = 0; x < 64; x++) {
            total += texelFetch(InSampler, ivec2(x, y), 0).r * 5.0 - 4.7;
        }
    }
    float average = exp(total / 2048.0) - 0.01;
    float target = clamp(pow(Exposure.y / max(average, 0.01), 0.45), Exposure.z, Exposure.w);
    Camera camera = camera_load_lite(CameraSampler);
    if (camera.valid) {
        if (camera.underwater) {
            target = 1.0;
        } else if (camera.skyValid) {
            LightState state = light_state(camera.daytime / 24000.0, clamp(camera.weather, 0.0, 1.0));
            target = mix(target, min(target, 1.2), state.moonVisibility);
        }
    }
    if (Exposure.x <= 0.0) {
        target = 1.0;
    }
    vec4 hold = textureSize(WeatherSampler, 0).x > 1 ? texelFetch(WeatherSampler, ivec2(1, 0), 0) : vec4(0.0);
    if (hold.a > 0.5 && hold.b > 0.001) {
        fragColor = precise_encode(current * 0.5);
        return;
    }
    current += (target - current) * (target < current ? 0.006 : 0.025);
    fragColor = precise_encode(current * 0.5);
}
